namespace MindBloom.API.Messaging.RabbitMq;

public sealed class RabbitMqPublisherWarmupHostedService
    : IHostedService
{
    private readonly RabbitMqConnectionManager
        _connectionManager;

    private readonly ILogger<
        RabbitMqPublisherWarmupHostedService>
        _logger;

    public RabbitMqPublisherWarmupHostedService(
        RabbitMqConnectionManager connectionManager,
        ILogger<RabbitMqPublisherWarmupHostedService>
            logger)
    {
        _connectionManager =
            connectionManager;

        _logger =
            logger;
    }

    public Task StartAsync(
        CancellationToken cancellationToken)
    {
        _ =
            WarmUpAsync(
                cancellationToken);

        return Task.CompletedTask;
    }

    private async Task WarmUpAsync(
        CancellationToken cancellationToken)
    {
        try
        {
            await _connectionManager
                .GetConnectionAsync(
                    cancellationToken);

            _logger.LogInformation(
                "RabbitMQ publisher connection warmed up successfully.");
        }
        catch (OperationCanceledException)
            when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            _logger.LogWarning(
                exception,
                "RabbitMQ publisher warm-up failed. "
                + "The application will continue starting "
                + "and RabbitMQ will retry when publishing.");
        }
    }

    public Task StopAsync(
        CancellationToken cancellationToken)
    {
        return Task.CompletedTask;
    }
}
