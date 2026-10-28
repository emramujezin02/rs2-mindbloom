using System.Text.Json;
using FluentValidation;
using FluentValidation.Results;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using MindBloom.API.Middlewares;
using MindBloom.Application.Common.Exceptions;
using Moq;

namespace MindBloom.UnitTests.Errors;

public sealed class GlobalExceptionMiddlewareTests
{
    private const string InternalDetail = "INTERNAL_TEST_SQL_DETAIL_SHOULD_NOT_LEAK";

    [Theory]
    [InlineData("Development", "invalid_operation")]
    [InlineData("Development", "db_update")]
    [InlineData("Development", "db_concurrency")]
    [InlineData("Development", "unexpected")]
    [InlineData("Production", "invalid_operation")]
    [InlineData("Production", "db_update")]
    [InlineData("Production", "db_concurrency")]
    [InlineData("Production", "unexpected")]
    public async Task TechnicalFailure_IsSafe500_AndLogsOriginalException(
        string environment, string failure)
    {
        var inner = new Exception("INNER_" + InternalDetail);
        Exception exception = failure switch
        {
            "invalid_operation" => new InvalidOperationException(InternalDetail, inner),
            "db_update" => new DbUpdateException(InternalDetail, inner),
            "db_concurrency" => new DbUpdateConcurrencyException(InternalDetail, inner),
            _ => new Exception(InternalDetail, inner)
        };
        var logger = new CapturingLogger();
        var (context, json) = await Invoke(exception, environment, logger);

        Assert.Equal(500, context.Response.StatusCode);
        using var body = JsonDocument.Parse(json);
        Assert.Equal("internal_server_error", body.RootElement.GetProperty("errorCode").GetString());
        Assert.Equal("An unexpected server error occurred.", body.RootElement.GetProperty("detail").GetString());
        Assert.Equal("test-trace", body.RootElement.GetProperty("traceId").GetString());
        Assert.DoesNotContain(InternalDetail, json);
        Assert.False(body.RootElement.TryGetProperty("exceptionType", out _));
        Assert.False(body.RootElement.TryGetProperty("stackTrace", out _));
        Assert.False(body.RootElement.TryGetProperty("innerException", out _));
        var entry = Assert.Single(logger.Entries);
        Assert.Equal(LogLevel.Error, entry.Level);
        Assert.Same(exception, entry.Exception);
        Assert.Contains(InternalDetail, entry.Exception!.ToString());
        Assert.NotNull(entry.Exception.StackTrace);
        Assert.Contains("test-trace", entry.Message);
        Assert.Contains("/api/test", entry.Message);
        Assert.DoesNotContain("TEST_AUTH_SECRET", entry.Message);
        Assert.DoesNotContain("TEST_BODY_SECRET", entry.Message);
        Assert.DoesNotContain("TEST_QUERY_SECRET", entry.Message);
    }

    [Theory]
    [InlineData("Development", "business", 409, "business_rule_violation", "This appointment time has already been booked.")]
    [InlineData("Production", "business", 409, "business_rule_violation", "This appointment time has already been booked.")]
    [InlineData("Development", "bad_request", 400, "bad_request", "Invalid request.")]
    [InlineData("Production", "bad_request", 400, "bad_request", "Invalid request.")]
    [InlineData("Development", "unauthorized", 401, "unauthorized", "Authentication is required.")]
    [InlineData("Production", "unauthorized", 401, "unauthorized", "Authentication is required.")]
    [InlineData("Development", "forbidden", 403, "forbidden", "You do not have permission to perform this action.")]
    [InlineData("Production", "forbidden", 403, "forbidden", "You do not have permission to perform this action.")]
    [InlineData("Development", "not_found", 404, "not_found", "Resource missing.")]
    [InlineData("Production", "not_found", 404, "not_found", "Resource missing.")]
    public async Task ExplicitApplicationErrors_PreserveStatusAndMessage(
        string environment, string failure, int status, string code, string detail)
    {
        Exception exception = failure switch
        {
            "business" => new BusinessException(detail, new InvalidOperationException(InternalDetail)),
            "bad_request" => new BadRequestException(detail),
            "unauthorized" => new UnauthorizedException(),
            "forbidden" => new ForbiddenException(),
            _ => new NotFoundException(detail)
        };
        var logger = new CapturingLogger();
        var (context, json) = await Invoke(exception, environment, logger);
        Assert.Equal(status, context.Response.StatusCode);
        Assert.Equal("application/problem+json", context.Response.ContentType);
        using var body = JsonDocument.Parse(json);
        Assert.Equal(detail, body.RootElement.GetProperty("detail").GetString());
        Assert.Equal(code, body.RootElement.GetProperty("errorCode").GetString());
        Assert.DoesNotContain(InternalDetail, json);
        Assert.DoesNotContain("stackTrace", json);
        Assert.DoesNotContain("exceptionType", json);
        Assert.Equal(status is 401 or 403 ? LogLevel.Warning : LogLevel.Information,
            Assert.Single(logger.Entries).Level);
    }

    [Fact]
    public async Task ValidationErrors_PreserveFieldMessages()
    {
        var (_, json) = await Invoke(new ValidationException(
            [new ValidationFailure("StartUtc", "Start time is required.")]), "Development", new CapturingLogger());
        using var body = JsonDocument.Parse(json);
        Assert.Equal(400, body.RootElement.GetProperty("statusCode").GetInt32());
        Assert.Equal("validation_error", body.RootElement.GetProperty("errorCode").GetString());
        Assert.Equal("Start time is required.", body.RootElement.GetProperty("validationErrors")
            .GetProperty("startUtc")[0].GetString());
    }

    private static async Task<(DefaultHttpContext Context, string Json)> Invoke(
        Exception exception, string environment, CapturingLogger logger)
    {
        var host = new Mock<IHostEnvironment>();
        host.SetupGet(x => x.EnvironmentName).Returns(environment);
        var context = new DefaultHttpContext { TraceIdentifier = "test-trace" };
        context.Request.Method = "POST";
        context.Request.Path = "/api/test";
        context.Request.QueryString = new QueryString("?secret=TEST_QUERY_SECRET");
        context.Request.Headers.Authorization = "Bearer TEST_AUTH_SECRET";
        context.Request.Body = new MemoryStream(System.Text.Encoding.UTF8.GetBytes("TEST_BODY_SECRET"));
        context.Response.Body = new MemoryStream();
        var middleware = new GlobalExceptionMiddleware(_ => throw exception, logger, host.Object);
        await middleware.InvokeAsync(context);
        context.Response.Body.Position = 0;
        return (context, await new StreamReader(context.Response.Body).ReadToEndAsync());
    }

    private sealed class CapturingLogger : ILogger<GlobalExceptionMiddleware>
    {
        public List<(LogLevel Level, Exception? Exception, string Message)> Entries { get; } = [];
        public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;
        public bool IsEnabled(LogLevel logLevel) => true;
        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state,
            Exception? exception, Func<TState, Exception?, string> formatter) =>
            Entries.Add((logLevel, exception, formatter(state, exception)));
    }
}
