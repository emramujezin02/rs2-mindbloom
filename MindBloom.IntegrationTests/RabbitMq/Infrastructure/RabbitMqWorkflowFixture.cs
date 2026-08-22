using System.Reflection;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using MindBloom.API.Messaging.RabbitMq;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Infrastructure.Messaging.RabbitMq;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.NotificationsWorker.Messaging;
using MindBloom.NotificationsWorker.Monitoring;
using MindBloom.NotificationsWorker.Services;
using MindBloom.NotificationsWorker.Workers;
using MindBloom.Shared.Observability;
using RabbitMQ.Client;
using Testcontainers.RabbitMq;

namespace MindBloom.IntegrationTests.RabbitMq.Infrastructure;

public sealed class RabbitMqWorkflowFixture
    : IAsyncLifetime
{
    private const string RabbitMqUserName =
        "mindbloom-tests";

    private const string RabbitMqPassword =
        "MindBloomRabbitMqTests123!";

    private readonly string
        _databaseName =
            "MindBloomRabbitMqTests-"
            + Guid.NewGuid()
                .ToString("N");

    private readonly string
        _resourcePrefix =
            "mindbloom.tests."
            + Guid.NewGuid()
                .ToString("N");

    private readonly RabbitMqContainer
        _rabbitMqContainer;

    private ServiceProvider?
        _serviceProvider;

    private IConnection?
        _administrationConnection;

    private IChannel?
        _administrationChannel;

    public RabbitMqOptions Options
    {
        get;
        private set;
    } = null!;

    public RabbitMqTopology Topology
    {
        get;
        private set;
    } = null!;

    public TestEmailService EmailService
    {
        get;
        private set;
    } = null!;

    public RabbitMqMonitoringMetrics
        MonitoringMetrics
    {
        get;
        private set;
    } = null!;

    public ApplicationMetrics
        ApplicationMetrics
    {
        get;
        private set;
    } = null!;

    public INotificationPublisher
        NotificationPublisher
    {
        get;
        private set;
    } = null!;

    public RabbitMqWorkflowFixture()
    {
        _rabbitMqContainer =
            new RabbitMqBuilder()
                .WithImage(
                    "rabbitmq:3.13-management")
                .WithUsername(
                    RabbitMqUserName)
                .WithPassword(
                    RabbitMqPassword)
                .Build();
    }

    public async Task InitializeAsync()
    {
        await _rabbitMqContainer
            .StartAsync();

        Options =
            CreateOptions();

        var services =
            new ServiceCollection();

        services.AddLogging(
            builder =>
            {
                builder.SetMinimumLevel(
                    LogLevel.Warning);
            });

        services.AddSingleton(
            Microsoft.Extensions.Options
                .Options.Create(
                    Options));

        services.AddSingleton<
            RabbitMqConnectionFactory>();

        services.AddSingleton<
            RabbitMqTopology>();

        services.AddSingleton<
            RabbitMqWorkerConnectionProvider>();

        services.AddSingleton<
            RabbitMqConsumerOperations>();

        services.AddSingleton<
            EmailMessageBodyBuilder>();

        services.AddSingleton<
            RabbitMqMonitoringMetrics>();

        services.AddSingleton<
            ApplicationMetrics>();

        services.AddSingleton<
            TestEmailService>();

        services.AddSingleton<
            IEmailService>(
                provider =>
                    provider
                        .GetRequiredService<
                            TestEmailService>());

        services.AddDbContext<
            ApplicationDbContext>(
                dbContextOptions =>
                {
                    dbContextOptions
                        .UseInMemoryDatabase(
                            _databaseName);
                });

        services.AddScoped<
            ProcessedMessageService>();

        /*
         * Publisher zahtijeva ICorrelationIdAccessor.
         *
         * Za RabbitMQ integration test nije nam potreban
         * HTTP request niti stvarni correlation header,
         * zato koristimo DispatchProxy koji svim članovima
         * vraća default vrijednost.
         */
        services.AddSingleton<
            ICorrelationIdAccessor>(
                _ =>
                    DispatchProxy
                        .Create<
                            ICorrelationIdAccessor,
                            NullInterfaceProxy>());

        services.AddSingleton<
            RabbitMqConnectionManager>();

        services.AddSingleton<
            RabbitMqIntegrationEventPublisher>();

        services.AddSingleton<
            IIntegrationEventPublisher>(
                provider =>
                    provider
                        .GetRequiredService<
                            RabbitMqIntegrationEventPublisher>());

        services.AddSingleton<
            RabbitMqNotificationPublisher>();

        services.AddSingleton<
            INotificationPublisher>(
                provider =>
                    provider
                        .GetRequiredService<
                            RabbitMqNotificationPublisher>());

        _serviceProvider =
            services.BuildServiceProvider();

        await EnsureDatabaseCreatedAsync();

        Topology =
            _serviceProvider
                .GetRequiredService<
                    RabbitMqTopology>();

        EmailService =
            _serviceProvider
                .GetRequiredService<
                    TestEmailService>();

        MonitoringMetrics =
            _serviceProvider
                .GetRequiredService<
                    RabbitMqMonitoringMetrics>();

        ApplicationMetrics =
            _serviceProvider
                .GetRequiredService<
                    ApplicationMetrics>();

        NotificationPublisher =
            _serviceProvider
                .GetRequiredService<
                    INotificationPublisher>();

        await CreateAdministrationChannelAsync();

        await Topology.DeclareAsync(
            _administrationChannel!);

        await ResetAsync();
    }

    private RabbitMqOptions
        CreateOptions()
    {
        return new RabbitMqOptions
        {
            HostName =
                _rabbitMqContainer
                    .Hostname,

            Port =
                _rabbitMqContainer
                    .GetMappedPublicPort(
                        5672),

            UserName =
                RabbitMqUserName,

            Password =
                RabbitMqPassword,

            VirtualHost =
                "/",

            PublisherClientName =
                $"{_resourcePrefix}.publisher",

            ConsumerClientName =
                $"{_resourcePrefix}.worker",

            NotificationExchange =
                $"{_resourcePrefix}.notifications",

            EmailQueue =
                $"{_resourcePrefix}.email",

            EmailRoutingKey =
                "notification.email",

            IntegrationEventQueue =
                $"{_resourcePrefix}.integration-events",

            RetryExchange =
                $"{_resourcePrefix}.retry",

            DeadLetterExchange =
                $"{_resourcePrefix}.dead-letter",

            DeadLetterQueue =
                $"{_resourcePrefix}.email.dlq",

            DeadLetterRoutingKey =
                "notification.email.dead",

            IntegrationEventDeadLetterQueue =
                $"{_resourcePrefix}.integration-events.dlq",

            IntegrationEventDeadLetterRoutingKey =
                "integration-event.dead",

            PrefetchCount =
                1,

            /*
             * Production ima veći broj retry pokušaja.
             * Za integration test su dovoljna dva retry-a:
             *
             * pokušaj 1
             * → retry 1s
             * pokušaj 2
             * → retry 2s
             * pokušaj 3
             * → DLQ
             *
             * Time test ostaje brz, a cijeli workflow
             * se stvarno izvršava.
             */
            MaximumRetryCount =
                2,

            AutomaticRecoveryEnabled =
                true,

            NetworkRecoveryIntervalSeconds =
                1,

            RequestedHeartbeatSeconds =
                10,

            ConnectionRetryCount =
                5,

            ConnectionRetryDelaySeconds =
                1,

            DeadLetterMonitoringIntervalSeconds =
                60,

            DeadLetterWarningMessageCount =
                1,

            MonitoringIntervalSeconds =
                60
        };
    }

    private async Task
        EnsureDatabaseCreatedAsync()
    {
        using var scope =
            _serviceProvider!
                .CreateScope();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        await context.Database
            .EnsureCreatedAsync();
    }

    private async Task
        CreateAdministrationChannelAsync()
    {
        var factory =
            new ConnectionFactory
            {
                HostName =
                    Options.HostName,

                Port =
                    Options.Port,

                UserName =
                    Options.UserName,

                Password =
                    Options.Password,

                VirtualHost =
                    Options.VirtualHost,

                ClientProvidedName =
                    $"{_resourcePrefix}.test-admin",

                AutomaticRecoveryEnabled =
                    true,

                TopologyRecoveryEnabled =
                    true
            };

        _administrationConnection =
            await factory
                .CreateConnectionAsync(
                    $"{_resourcePrefix}.test-admin");

        _administrationChannel =
            await _administrationConnection
                .CreateChannelAsync();
    }

    public EmailNotificationConsumer
        CreateEmailConsumer()
    {
        EnsureInitialized();

        return new EmailNotificationConsumer(
            Microsoft.Extensions.Options
                .Options.Create(
                    Options),

            _serviceProvider!
                .GetRequiredService<
                    RabbitMqWorkerConnectionProvider>(),

            Topology,

            EmailService,

            _serviceProvider
                .GetRequiredService<
                    RabbitMqConsumerOperations>(),

            ApplicationMetrics,

            _serviceProvider
                .GetRequiredService<
                    EmailMessageBodyBuilder>(),

            _serviceProvider
                .GetRequiredService<
                    IServiceScopeFactory>(),

            MonitoringMetrics,

            _serviceProvider
                .GetRequiredService<
                    ILogger<
                        EmailNotificationConsumer>>());
    }

    public async Task ResetAsync()
    {
        EnsureInitialized();

        EmailService.Reset();

        await ClearProcessedMessagesAsync();

        await PurgeQueueAsync(
            Options.EmailQueue);

        await PurgeQueueAsync(
            Options.DeadLetterQueue);

        await PurgeQueueAsync(
            Options.IntegrationEventQueue);

        await PurgeQueueAsync(
            Options
                .IntegrationEventDeadLetterQueue);

        foreach (var retryDelay
                 in Topology.RetryDelays)
        {
            /*
             * Email retry queue:
             *
             * <email-queue>.retry.<delay>ms
             */
            await PurgeQueueAsync(
                Topology
                    .GetRetryQueueName(
                        Options.EmailQueue,
                        retryDelay));

            /*
             * Integration-event retry queueovi imaju
             * routing key kao dio naziva:
             *
             * <integration-queue>.<routing-key>.retry.<delay>ms
             */
            foreach (var routingKey
                     in Topology
                         .SupportedIntegrationEventRoutingKeys)
            {
                await PurgeQueueAsync(
                    Topology
                        .GetRetryQueueName(
                            Options.IntegrationEventQueue
                            + "."
                            + routingKey,
                            retryDelay));
            }
        }
    }

    private async Task
        ClearProcessedMessagesAsync()
    {
        using var scope =
            _serviceProvider!
                .CreateScope();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        context.ProcessedMessages
            .RemoveRange(
                context.ProcessedMessages);

        await context
            .SaveChangesAsync();
    }

    public async Task<int>
        GetProcessedMessageCountAsync(
            Guid messageId,
            string consumerName)
    {
        using var scope =
            _serviceProvider!
                .CreateScope();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        return await context
            .ProcessedMessages
            .CountAsync(
                item =>
                    item.MessageId ==
                        messageId &&
                    item.ConsumerName ==
                        consumerName);
    }

    public async Task<uint>
        GetQueueMessageCountAsync(
            string queueName)
    {
        EnsureInitialized();

        var queue =
            await _administrationChannel!
                .QueueDeclarePassiveAsync(
                    queueName);

        return queue.MessageCount;
    }

    public async Task<uint>
        GetQueueConsumerCountAsync(
            string queueName)
    {
        EnsureInitialized();

        var queue =
            await _administrationChannel!
                .QueueDeclarePassiveAsync(
                    queueName);

        return queue.ConsumerCount;
    }

    public async Task<
        BasicGetResult?>
        GetMessageAsync(
            string queueName,
            bool acknowledge =
                true)
    {
        EnsureInitialized();

        return await _administrationChannel!
            .BasicGetAsync(
                queue:
                    queueName,
                autoAck:
                    acknowledge);
    }

    public async Task PurgeQueueAsync(
        string queueName)
    {
        EnsureInitialized();

        await _administrationChannel!
            .QueuePurgeAsync(
                queueName);
    }

    public async Task WaitUntilAsync(
        Func<Task<bool>> condition,
        TimeSpan timeout,
        string failureMessage)
    {
        var startedAt =
            DateTime.UtcNow;

        while (DateTime.UtcNow -
               startedAt <
               timeout)
        {
            if (await condition())
            {
                return;
            }

            await Task.Delay(
                100);
        }

        throw new TimeoutException(
            failureMessage);
    }

    public async Task StartConsumerAsync(
        EmailNotificationConsumer consumer)
    {
        await consumer.StartAsync(
            CancellationToken.None);

        await WaitUntilAsync(
            async () =>
                await GetQueueConsumerCountAsync(
                    Options.EmailQueue) >
                0,

            TimeSpan.FromSeconds(
                10),

            "RabbitMQ email consumer did not start within the expected time.");
    }

    public static async Task
        StopConsumerAsync(
            EmailNotificationConsumer consumer)
    {
        using var timeout =
            new CancellationTokenSource(
                TimeSpan.FromSeconds(
                    10));

        await consumer.StopAsync(
            timeout.Token);

        await consumer.DisposeAsync();
    }

    private void EnsureInitialized()
    {
        if (_serviceProvider is null ||
            _administrationChannel is null)
        {
            throw new InvalidOperationException(
                "RabbitMQ workflow fixture has not been initialized.");
        }
    }

    public async Task DisposeAsync()
    {
        if (_serviceProvider is not null)
        {
            var publisher =
                _serviceProvider
                    .GetService<
                        RabbitMqIntegrationEventPublisher>();

            if (publisher is not null)
            {
                await publisher
                    .DisposeAsync();
            }

            var connectionManager =
                _serviceProvider
                    .GetService<
                        RabbitMqConnectionManager>();

            if (connectionManager is not null)
            {
                await connectionManager
                    .DisposeAsync();
            }
        }

        if (_administrationChannel
            is not null)
        {
            try
            {
                if (_administrationChannel
                    .IsOpen)
                {
                    await _administrationChannel
                        .CloseAsync();
                }
            }
            catch
            {
            }

            await _administrationChannel
                .DisposeAsync();

            _administrationChannel =
                null;
        }

        if (_administrationConnection
            is not null)
        {
            try
            {
                if (_administrationConnection
                    .IsOpen)
                {
                    await _administrationConnection
                        .CloseAsync();
                }
            }
            catch
            {
            }

            await _administrationConnection
                .DisposeAsync();

            _administrationConnection =
                null;
        }

        if (_serviceProvider is not null)
        {
            await _serviceProvider
                .DisposeAsync();

            _serviceProvider =
                null;
        }

        await _rabbitMqContainer
            .DisposeAsync();
    }

    private class
     NullInterfaceProxy
     : DispatchProxy
    {
        protected override object?
            Invoke(
                MethodInfo?
                    targetMethod,
                object?[]?
                    args)
        {
            if (targetMethod is null)
            {
                return null;
            }

            var returnType =
                targetMethod.ReturnType;

            if (returnType ==
                typeof(void))
            {
                return null;
            }

            if (!returnType
                    .IsValueType ||
                Nullable.GetUnderlyingType(
                    returnType) is not null)
            {
                return null;
            }

            return Activator
                .CreateInstance(
                    returnType);
        }
    }
}