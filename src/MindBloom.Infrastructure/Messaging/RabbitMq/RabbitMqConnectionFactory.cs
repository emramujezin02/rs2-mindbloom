using Microsoft.Extensions.Options;
using RabbitMQ.Client;

namespace MindBloom.Infrastructure.Messaging.RabbitMq;

public sealed class RabbitMqConnectionFactory
{
    private readonly RabbitMqOptions _options;

    public RabbitMqConnectionFactory(
        IOptions<RabbitMqOptions> options)
    {
        _options =
            options.Value;
    }

    public ConnectionFactory Create(
        string clientProvidedName,
        ushort consumerDispatchConcurrency = 1)
    {
        if (string.IsNullOrWhiteSpace(
                clientProvidedName))
        {
            throw new ArgumentException(
                "RabbitMQ client name is required.",
                nameof(clientProvidedName));
        }

        return new ConnectionFactory
        {
            HostName =
                _options.HostName,

            Port =
                _options.Port,

            UserName =
                _options.UserName,

            Password =
                _options.Password,

            VirtualHost =
                _options.VirtualHost,

            ClientProvidedName =
                clientProvidedName,

            AutomaticRecoveryEnabled =
                _options.AutomaticRecoveryEnabled,

            TopologyRecoveryEnabled =
                true,

            NetworkRecoveryInterval =
                TimeSpan.FromSeconds(
                    _options
                        .NetworkRecoveryIntervalSeconds),

            RequestedHeartbeat =
                TimeSpan.FromSeconds(
                    _options
                        .RequestedHeartbeatSeconds),

            ConsumerDispatchConcurrency =
                consumerDispatchConcurrency
        };
    }
}