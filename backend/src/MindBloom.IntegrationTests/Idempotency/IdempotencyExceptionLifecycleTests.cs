using System.Collections.Concurrent;
using System.Net;
using System.Net.Http.Json;
using System.Reflection;
using System.Security.Claims;
using System.Text;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Abstractions;
using Microsoft.AspNetCore.Mvc.ApplicationParts;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Routing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using MindBloom.API.Configuration;
using MindBloom.API.Controllers;
using MindBloom.API.Filters;
using MindBloom.API.Idempotency;
using MindBloom.API.Middlewares;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Application.Features.Appointments.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.Idempotency;

// Standalone in-process MVC only: no Program, AddInfrastructure, SQL, hosted jobs or network integrations.
public sealed class IdempotencyExceptionLifecycleTests
{
    [Theory]
    [InlineData("Business",409)] [InlineData("Unexpected",500)]
    [InlineData("Argument",400)] [InlineData("Validation",400)]
    [InlineData("Unauthorized",401)] [InlineData("NotFound",404)]
    public async Task UnhandledMvcException_IsNotCompleted_AndSameKeyExecutesAgain(string mode,int expected)
    {
        using var host=new LifecycleHost(mode);
        var key=Guid.NewGuid().ToString("N");
        for(var attempt=1;attempt<=2;attempt++)
        {
            using var response=await host.Send(key);
            Assert.Equal(expected,(int)response.StatusCode);
            Assert.Contains("application/problem+json",response.Content.Headers.ContentType!.ToString());
            Assert.False(string.IsNullOrWhiteSpace(await response.Content.ReadAsStringAsync()));
            using var scope=host.Server.Services.CreateScope();
            var db=scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            Assert.Equal("Microsoft.EntityFrameworkCore.InMemory",db.Database.ProviderName);
            Assert.Empty(await db.ApiIdempotencyRecords.AsNoTracking().ToListAsync());
            Assert.Equal(attempt,host.State.BookingCalls);
            Assert.Equal(0,await db.Appointments.CountAsync());
            Assert.Equal(0,await db.Payments.CountAsync());
        }
        // One primary middleware report per attempt; no second propagation/handling path.
        Assert.Equal(2,host.Logs.Rows.Count(x=>x.Category==typeof(GlobalExceptionMiddleware).FullName));
    }

    [Theory] [InlineData(false)] [InlineData(true)]
    public async Task Success200And204_ArePersistedAndReplayed(bool noContent)
    {
        using var host=new LifecycleHost("Success");
        var key=Guid.NewGuid().ToString("N");
        var path=noContent?"/api/idempotency-probe/no-content":"/api/Appointments";
        using var first=await host.Send(key,path:path);
        using var replay=await host.Send(key,path:path);
        var expected=noContent?204:200;
        Assert.Equal(expected,(int)first.StatusCode);Assert.Equal(expected,(int)replay.StatusCode);
        Assert.Equal(await first.Content.ReadAsStringAsync(),await replay.Content.ReadAsStringAsync());
        Assert.Equal(1,noContent?host.State.NoContentCalls:host.State.BookingCalls);
        using var scope=host.Server.Services.CreateScope();
        var record=Assert.Single(await scope.ServiceProvider.GetRequiredService<ApplicationDbContext>().ApiIdempotencyRecords.AsNoTracking().ToListAsync());
        Assert.Equal("Completed",record.Status);Assert.Equal(expected,record.ResponseStatusCode);
        if(noContent)Assert.Null(record.ResponseBody);else Assert.NotNull(record.ResponseBody);
    }

    [Fact]
    public async Task CleanupFailure_PreservesOriginal409_LogsNoSensitiveException_AndLeavesProcessing()
    {
        using var host=new LifecycleHost("Business",true);
        var key=Guid.NewGuid().ToString("N");
        using var first=await host.Send(key);
        Assert.Equal(HttpStatusCode.Conflict,first.StatusCode);
        Assert.Contains("This therapist is not available for booking.",await first.Content.ReadAsStringAsync());
        Assert.Equal(1,host.State.CleanupAttempts);
        var cleanup=Assert.Single(host.Logs.Rows,x=>x.Category==typeof(IdempotencyActionFilter).FullName&&x.Level==LogLevel.Error);
        Assert.Null(cleanup.Exception);Assert.Contains("InvalidOperationException",cleanup.Text);
        Assert.DoesNotContain(LifecycleState.PrivateMarker,cleanup.Text);Assert.DoesNotContain(key,cleanup.Text);
        Assert.Equal(1,host.Logs.Rows.Count(x=>x.Category==typeof(GlobalExceptionMiddleware).FullName));
        using var scope=host.Server.Services.CreateScope();
        var db=scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var record=Assert.Single(await db.ApiIdempotencyRecords.AsNoTracking().ToListAsync());
        Assert.Equal("Processing",record.Status);Assert.Null(record.ResponseStatusCode);Assert.Null(record.ResponseBody);
        using var retry=await host.Send(key);
        Assert.Equal(HttpStatusCode.Conflict,retry.StatusCode);
        Assert.Contains("being processed",await retry.Content.ReadAsStringAsync());
        Assert.Equal(1,host.State.BookingCalls);
        Assert.Equal(0,await db.Appointments.CountAsync());Assert.Equal(0,await db.Payments.CountAsync());
    }

    [Theory] [InlineData("User")] [InlineData("Operation")] [InlineData("Payload")]
    public async Task ExistingKeyIsolation_RemainsIntact(string mismatch)
    {
        using var host=new LifecycleHost("Success");var key=Guid.NewGuid().ToString("N");
        using var original=await host.Send(key);Assert.Equal(HttpStatusCode.OK,original.StatusCode);
        using var conflict=await host.Send(key,user:mismatch=="User"?900002:900001,
            therapist:mismatch=="Payload"?2:1,path:mismatch=="Operation"?"/api/idempotency-probe/no-content":"/api/Appointments");
        Assert.Equal(HttpStatusCode.Conflict,conflict.StatusCode);
        Assert.Equal(1,host.State.BookingCalls);Assert.Equal(0,host.State.NoContentCalls);
        using var scope=host.Server.Services.CreateScope();
        var record=Assert.Single(await scope.ServiceProvider.GetRequiredService<ApplicationDbContext>().ApiIdempotencyRecords.AsNoTracking().ToListAsync());
        Assert.Equal(900001,record.UserId);Assert.Equal("Appointments.Create",record.Operation);Assert.Equal(200,record.ResponseStatusCode);
    }

    [Theory] [InlineData(null,401)] [InlineData("Therapist",403)]
    public async Task FrameworkAuthFailure_DoesNotCreateRecord(string? role,int expected)
    {
        using var host=new LifecycleHost("Business");using var response=await host.Send(Guid.NewGuid().ToString("N"),role);
        Assert.Equal(expected,(int)response.StatusCode);Assert.Equal(0,host.State.BookingCalls);
        using var scope=host.Server.Services.CreateScope();
        Assert.Equal(0,await scope.ServiceProvider.GetRequiredService<ApplicationDbContext>().ApiIdempotencyRecords.CountAsync());
    }

    [Fact]
    public async Task InvalidModelBinding_DoesNotCreateRecord()
    {
        using var host=new LifecycleHost("Business");using var response=await host.Send(Guid.NewGuid().ToString("N"),raw:"{\"therapistId\":\"invalid\"}");
        Assert.Equal(HttpStatusCode.BadRequest,response.StatusCode);Assert.Equal(0,host.State.BookingCalls);
        using var scope=host.Server.Services.CreateScope();
        Assert.Equal(0,await scope.ServiceProvider.GetRequiredService<ApplicationDbContext>().ApiIdempotencyRecords.CountAsync());
    }

    [Theory] [InlineData(false)] [InlineData(true)]
    public async Task DirectThrownException_IsPreserved_WithOrWithoutCleanupFailure(bool cleanupFails)
    {
        using var host=new LifecycleHost("Business",cleanupFails);using var scope=host.Server.Services.CreateScope();
        var db=scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var filter=scope.ServiceProvider.GetRequiredService<IdempotencyActionFilter>();
        var http=new DefaultHttpContext();http.User=new ClaimsPrincipal(new ClaimsIdentity(new[]{new Claim(ClaimTypes.NameIdentifier,"900001")},"Synthetic"));
        http.Request.Headers["Idempotency-Key"]=Guid.NewGuid().ToString("N");
        var descriptor=new ActionDescriptor{RouteValues=new Dictionary<string,string?>{{"controller","Appointments"},{"action","Create"}}};
        var action=new ActionContext(http,new RouteData(),descriptor);
        var context=new ActionExecutingContext(action,[],new Dictionary<string,object?>(),new object());
        var primary=new BusinessException("Original direct failure");
        var actual=await Assert.ThrowsAsync<BusinessException>(()=>filter.OnActionExecutionAsync(context,()=>throw primary));
        Assert.Same(primary,actual);
        using var verify=host.Server.Services.CreateScope();
        var records=await verify.ServiceProvider.GetRequiredService<ApplicationDbContext>().ApiIdempotencyRecords.AsNoTracking().ToListAsync();
        if(cleanupFails)Assert.Equal("Processing",Assert.Single(records).Status);else Assert.Empty(records);
    }

    [Fact]
    public async Task HandledExceptionContext_WithValidResult_RemainsCacheable()
    {
        using var host=new LifecycleHost("Business");using var scope=host.Server.Services.CreateScope();
        var filter=scope.ServiceProvider.GetRequiredService<IdempotencyActionFilter>();
        var http=new DefaultHttpContext();http.User=new ClaimsPrincipal(new ClaimsIdentity(new[]{new Claim(ClaimTypes.NameIdentifier,"900001")},"Synthetic"));
        http.Request.Headers["Idempotency-Key"]=Guid.NewGuid().ToString("N");
        var action=new ActionContext(http,new RouteData(),new ActionDescriptor{RouteValues=new Dictionary<string,string?>{{"controller","Probe"},{"action","Handled"}}});
        var context=new ActionExecutingContext(action,[],new Dictionary<string,object?>(),new object());
        var executed=new ActionExecutedContext(action,[],new object()){Exception=new BusinessException("Handled"),ExceptionHandled=true,Result=new NoContentResult()};
        await filter.OnActionExecutionAsync(context,()=>Task.FromResult(executed));
        var record=Assert.Single(await scope.ServiceProvider.GetRequiredService<ApplicationDbContext>().ApiIdempotencyRecords.AsNoTracking().ToListAsync());
        Assert.Equal(204,record.ResponseStatusCode);Assert.Equal("Completed",record.Status);
    }
}

public sealed class LifecycleState
{
    public const string PrivateMarker="SYNTHETIC_PRIVATE_VALUE_DO_NOT_LOG";
    public int BookingCalls,NoContentCalls,CleanupAttempts;
}
public class BookingDependencyDouble:DispatchProxy
{
    public Func<Task<AppointmentResponseDto>> InvokeBooking=null!;
    protected override object? Invoke(MethodInfo? method,object?[]? args)=>method?.Name==nameof(IAppointmentService.CreateAsync)?InvokeBooking():throw new InvalidOperationException("Unexpected mock call");
}
public sealed class FailCleanupInterceptor(LifecycleState state,bool fail):SaveChangesInterceptor
{
    public override ValueTask<InterceptionResult<int>> SavingChangesAsync(DbContextEventData data,InterceptionResult<int> result,CancellationToken cancellationToken=default)
    {
        if(data.Context!.ChangeTracker.Entries<ApiIdempotencyRecord>().Any(x=>x.State==EntityState.Deleted))
        {
            state.CleanupAttempts++;
            if(fail)throw new InvalidOperationException(LifecycleState.PrivateMarker);
        }
        return ValueTask.FromResult(result);
    }
}
public sealed record LifecycleLog(string Category,LogLevel Level,string Text,Exception? Exception);
public sealed class LifecycleLogs:ILoggerProvider
{
    public ConcurrentQueue<LifecycleLog> Rows{get;}=new();
    public ILogger CreateLogger(string category)=>new Capture(category,Rows);
    public void Dispose(){}
    private sealed class Capture(string category,ConcurrentQueue<LifecycleLog> rows):ILogger
    {
        public IDisposable? BeginScope<TState>(TState state) where TState:notnull=>null;
        public bool IsEnabled(LogLevel level)=>true;
        public void Log<TState>(LogLevel level,EventId id,TState state,Exception? exception,Func<TState,Exception?,string> formatter)=>rows.Enqueue(new(category,level,formatter(state,exception),exception));
    }
}
public sealed class LifecycleHost:IDisposable
{
    public TestServer Server{get;}private readonly HttpClient client;
    public LifecycleState State{get;}=new();public LifecycleLogs Logs{get;}=new();
    public LifecycleHost(string mode,bool cleanupFails=false)
    {
        var database="Idempotency-Lifecycle-"+Guid.NewGuid().ToString("N");
        var dependency=DispatchProxy.Create<IAppointmentService,BookingDependencyDouble>();
        ((BookingDependencyDouble)(object)dependency).InvokeBooking=()=>{
            Interlocked.Increment(ref State.BookingCalls);
            if(mode=="Success")return Task.FromResult(new AppointmentResponseDto{Id=1,TherapistId=1,Price=50.25m,Status="Synthetic"});
            Exception error=mode switch{
                "Business"=>new BusinessException("This therapist is not available for booking."),
                "Argument"=>new ArgumentException("Synthetic invalid argument"),
                "Validation"=>new FluentValidation.ValidationException("Synthetic validation"),
                "Unauthorized"=>new UnauthorizedException("Synthetic action denial"),
                "NotFound"=>new NotFoundException("Synthetic missing item"),
                _=>new InvalidOperationException("Synthetic server failure")};
            return Task.FromException<AppointmentResponseDto>(error);
        };
        Server=new TestServer(new WebHostBuilder().UseEnvironment("Testing").ConfigureServices(services=>{
            services.AddLogging(b=>{b.ClearProviders();b.AddProvider(Logs);});
            services.AddDbContext<ApplicationDbContext>(o=>o.UseInMemoryDatabase(database).AddInterceptors(new FailCleanupInterceptor(State,cleanupFails)));
            services.AddSingleton(dependency);services.AddSingleton(State);
            services.Configure<IdempotencyOptions>(o=>{o.ProcessingWaitMilliseconds=10;o.ProcessingPollMilliseconds=1;});
            services.AddScoped<IdempotencyActionFilter>();services.AddScoped<FluentValidationFilter>();
            services.AddAuthentication("Synthetic").AddScheme<AuthenticationSchemeOptions,LifecycleAuthentication>("Synthetic",_=>{});
            services.AddAuthorization(o=>{
                o.AddPolicy(AuthorizationPolicyConstants.AuthenticatedUser,p=>p.RequireAuthenticatedUser());
                o.AddPolicy(AuthorizationPolicyConstants.ClientOnly,p=>p.RequireAuthenticatedUser().RequireRole(RoleConstants.Client));
            });
            services.AddControllers(o=>o.Filters.AddService<FluentValidationFilter>())
                .AddApplicationPart(typeof(AppointmentsController).Assembly).AddApplicationPart(typeof(IdempotencyProbeController).Assembly)
                .ConfigureApplicationPartManager(p=>p.FeatureProviders.Add(new LifecycleControllers()));
        }).Configure(app=>{
            app.UseMiddleware<GlobalExceptionMiddleware>();app.UseRouting();app.UseAuthentication();app.UseAuthorization();app.UseEndpoints(e=>e.MapControllers());
        }));client=Server.CreateClient();
    }
    public async Task<HttpResponseMessage> Send(string key,string? role="Client",int user=900001,int therapist=1,string path="/api/Appointments",string? raw=null)
    {
        using var request=new HttpRequestMessage(HttpMethod.Post,path);request.Headers.Add("Idempotency-Key",key);
        if(role is not null){request.Headers.Add("X-Probe-Role",role);request.Headers.Add("X-Probe-User",user.ToString());}
        request.Content=raw is null?JsonContent.Create(new CreateAppointmentDto{TherapistId=therapist,StartUtc=new DateTime(2030,1,1,9,0,0,DateTimeKind.Utc),EndUtc=new DateTime(2030,1,1,10,0,0,DateTimeKind.Utc),Notes=LifecycleState.PrivateMarker}):new StringContent(raw,Encoding.UTF8,"application/json");
        return await client.SendAsync(request);
    }
    public void Dispose(){client.Dispose();Server.Dispose();}
}
[ApiController,Route("api/idempotency-probe"),Authorize(Policy=AuthorizationPolicyConstants.ClientOnly)]
public sealed class IdempotencyProbeController(LifecycleState state):ControllerBase
{
    [HttpPost("no-content"),RequireIdempotency]
    public IActionResult NoContentProbe(){state.NoContentCalls++;return NoContent();}
}
public sealed class LifecycleControllers:IApplicationFeatureProvider<ControllerFeature>
{
    public void PopulateFeature(IEnumerable<ApplicationPart> parts,ControllerFeature feature)
    {foreach(var c in feature.Controllers.ToArray())if(c.AsType()!=typeof(AppointmentsController)&&c.AsType()!=typeof(IdempotencyProbeController))feature.Controllers.Remove(c);}
}
public sealed class LifecycleAuthentication(IOptionsMonitor<AuthenticationSchemeOptions> options,ILoggerFactory logger,UrlEncoder encoder):AuthenticationHandler<AuthenticationSchemeOptions>(options,logger,encoder)
{
    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var role=Request.Headers["X-Probe-Role"].ToString();if(string.IsNullOrEmpty(role))return Task.FromResult(AuthenticateResult.NoResult());
        var identity=new ClaimsIdentity(new[]{new Claim(ClaimTypes.NameIdentifier,Request.Headers["X-Probe-User"].ToString()),new Claim(ClaimTypes.Role,role)},Scheme.Name);
        return Task.FromResult(AuthenticateResult.Success(new AuthenticationTicket(new ClaimsPrincipal(identity),Scheme.Name)));
    }
}
