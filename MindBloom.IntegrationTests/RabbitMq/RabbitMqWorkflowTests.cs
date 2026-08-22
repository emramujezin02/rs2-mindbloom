using System.Text;
using MindBloom.Messaging.Contracts.Notifications;
using MindBloom.IntegrationTests.RabbitMq.Infrastructure;

namespace MindBloom.IntegrationTests.RabbitMq;

public sealed class RabbitMqWorkflowTests
    : IClassFixture<RabbitMqWorkflowFixture>
{
    private readonly RabbitMqWorkflowFixture
        _fixture;

    public RabbitMqWorkflowTests(
        RabbitMqWorkflowFixture fixture)
    {
        _fixture =
            fixture;
    }

    [Fact]
    public async Task
        Publish_WritesMessageToRabbitMqQueue()
    {
        await _fixture.ResetAsync();

        var message =
            CreateMessage(
                subject:
                    "Publish workflow test");

        await _fixture
            .NotificationPublisher
            .PublishEmailAsync(
                message);

        await _fixture.WaitUntilAsync(
            async () =>
                await _fixture
                    .GetQueueMessageCountAsync(
                        _fixture.Options.EmailQueue) ==
                1,

            TimeSpan.FromSeconds(
                10),

            "Published email notification did not arrive in the RabbitMQ email queue.");

        var delivery =
            await _fixture.GetMessageAsync(
                _fixture.Options.EmailQueue);

        Assert.NotNull(
            delivery);

        Assert.Equal(
            message.MessageId
                .ToString(),
            delivery!
                .BasicProperties
                .MessageId);

        var body =
            Encoding.UTF8
                .GetString(
                    delivery.Body.Span);

        Assert.Contains(
            message.RecipientEmail,
            body,
            StringComparison.Ordinal);

        Assert.Contains(
            message.Subject,
            body,
            StringComparison.Ordinal);
    }

    [Fact]
    public async Task
        Consume_ProcessesMessageAndAcknowledgesIt()
    {
        await _fixture.ResetAsync();

        _fixture.EmailService
            .Succeed();

        var consumer =
            _fixture
                .CreateEmailConsumer();

        try
        {
            await _fixture
                .StartConsumerAsync(
                    consumer);

            var message =
                CreateMessage(
                    subject:
                        "Consume workflow test");

            await _fixture
                .NotificationPublisher
                .PublishEmailAsync(
                    message);

            await _fixture.WaitUntilAsync(
                () =>
                    Task.FromResult(
                        _fixture
                            .EmailService
                            .SuccessfulSendCount ==
                        1),

                TimeSpan.FromSeconds(
                    10),

                "RabbitMQ worker did not consume and send the email notification.");

            await _fixture.WaitUntilAsync(
                async () =>
                    await _fixture
                        .GetQueueMessageCountAsync(
                            _fixture.Options
                                .EmailQueue) ==
                    0,

                TimeSpan.FromSeconds(
                    10),

                "Consumed RabbitMQ message was not acknowledged.");

            Assert.Equal(
                1,
                _fixture
                    .EmailService
                    .AttemptCount);

            Assert.Equal(
                1,
                _fixture
                    .EmailService
                    .SuccessfulSendCount);

            var sentEmail =
                Assert.Single(
                    _fixture
                        .EmailService
                        .SentEmails);

            Assert.Equal(
                message.RecipientEmail,
                sentEmail.To);

            Assert.Equal(
                message.Subject,
                sentEmail.Subject);
        }
        finally
        {
            await RabbitMqWorkflowFixture
                .StopConsumerAsync(
                    consumer);
        }
    }

    [Fact]
    public async Task
        Retry_TransientFailureRetriesAndThenSucceeds()
    {
        await _fixture.ResetAsync();

        /*
         * Prvi pokušaj email servisa namjerno pada.
         *
         * Consumer treba:
         * 1. poslati poruku u retry exchange,
         * 2. sačekati TTL retry queuea,
         * 3. ponovo dobiti poruku,
         * 4. uspješno je obraditi.
         */
        _fixture.EmailService
            .FailNext(1);

        var consumer =
            _fixture
                .CreateEmailConsumer();

        try
        {
            await _fixture
                .StartConsumerAsync(
                    consumer);

            var message =
                CreateMessage(
                    subject:
                        "Retry workflow test");

            await _fixture
                .NotificationPublisher
                .PublishEmailAsync(
                    message);

            await _fixture.WaitUntilAsync(
                () =>
                    Task.FromResult(
                        _fixture
                            .EmailService
                            .SuccessfulSendCount ==
                        1),

                TimeSpan.FromSeconds(
                    15),

                "RabbitMQ message did not succeed after the configured retry.");

            Assert.Equal(
                2,
                _fixture
                    .EmailService
                    .AttemptCount);

            Assert.Equal(
                1,
                _fixture
                    .EmailService
                    .SuccessfulSendCount);

            await _fixture.WaitUntilAsync(
                async () =>
                    await _fixture
                        .GetQueueMessageCountAsync(
                            _fixture.Options
                                .EmailQueue) ==
                    0,

                TimeSpan.FromSeconds(
                    10),

                "RabbitMQ email queue was not empty after successful retry.");

            Assert.Equal(
                0u,
                await _fixture
                    .GetQueueMessageCountAsync(
                        _fixture.Options
                            .DeadLetterQueue));
        }
        finally
        {
            await RabbitMqWorkflowFixture
                .StopConsumerAsync(
                    consumer);
        }
    }

    [Fact]
    public async Task
        DeadLetter_ExhaustedRetriesMovesMessageToDlq()
    {
        await _fixture.ResetAsync();

        /*
         * Testni email servis uvijek pada.
         *
         * Fixture ima MaximumRetryCount = 2:
         *
         * pokušaj 1
         * retry #1
         *
         * pokušaj 2
         * retry #2
         *
         * pokušaj 3
         * DLQ
         */
        _fixture.EmailService
            .FailAlways();

        var consumer =
            _fixture
                .CreateEmailConsumer();

        try
        {
            await _fixture
                .StartConsumerAsync(
                    consumer);

            var message =
                CreateMessage(
                    subject:
                        "Dead letter workflow test");

            await _fixture
                .NotificationPublisher
                .PublishEmailAsync(
                    message);

            await _fixture.WaitUntilAsync(
                async () =>
                    await _fixture
                        .GetQueueMessageCountAsync(
                            _fixture.Options
                                .DeadLetterQueue) ==
                    1,

                TimeSpan.FromSeconds(
                    20),

                "RabbitMQ message was not moved to the dead-letter queue after retries were exhausted.");

            Assert.Equal(
                0,
                _fixture
                    .EmailService
                    .SuccessfulSendCount);

            Assert.Equal(
                3,
                _fixture
                    .EmailService
                    .AttemptCount);

            Assert.Equal(
                0u,
                await _fixture
                    .GetQueueMessageCountAsync(
                        _fixture.Options
                            .EmailQueue));

            var deadLetter =
                await _fixture
                    .GetMessageAsync(
                        _fixture.Options
                            .DeadLetterQueue);

            Assert.NotNull(
                deadLetter);

            Assert.Equal(
                message.MessageId
                    .ToString(),
                deadLetter!
                    .BasicProperties
                    .MessageId);

            Assert.NotNull(
                deadLetter
                    .BasicProperties
                    .Headers);

            Assert.True(
                deadLetter
                    .BasicProperties
                    .Headers!
                    .ContainsKey(
                        "x-retry-count"));
        }
        finally
        {
            await RabbitMqWorkflowFixture
                .StopConsumerAsync(
                    consumer);
        }
    }

    [Fact]
    public async Task
        DuplicateEvent_SameMessageIsProcessedOnlyOnce()
    {
        await _fixture.ResetAsync();

        _fixture.EmailService
            .Succeed();

        var consumer =
            _fixture
                .CreateEmailConsumer();

        try
        {
            await _fixture
                .StartConsumerAsync(
                    consumer);

            var message =
                CreateMessage(
                    subject:
                        "Duplicate workflow test");

            /*
             * Prva obrada mora uspjeti i upisati
             * ProcessedMessage zapis.
             */
            await _fixture
                .NotificationPublisher
                .PublishEmailAsync(
                    message);

            await _fixture.WaitUntilAsync(
                () =>
                    Task.FromResult(
                        _fixture
                            .EmailService
                            .SuccessfulSendCount ==
                        1),

                TimeSpan.FromSeconds(
                    10),

                "First RabbitMQ message was not processed.");

            /*
             * Objavljujemo potpuno isti event,
             * sa istim MessageId/EventId.
             *
             * Consumer ga treba prepoznati kao duplicate
             * i samo ACK-ovati bez ponovnog slanja emaila.
             */
            await _fixture
                .NotificationPublisher
                .PublishEmailAsync(
                    message);

            await _fixture.WaitUntilAsync(
                async () =>
                    await _fixture
                        .GetQueueMessageCountAsync(
                            _fixture.Options
                                .EmailQueue) ==
                    0,

                TimeSpan.FromSeconds(
                    10),

                "Duplicate RabbitMQ message was not consumed.");

            /*
             * Dajemo consumeru kratko vrijeme da završi
             * duplicate-processing granu prije assert-a.
             */
            await Task.Delay(
                500);

            Assert.Equal(
                1,
                _fixture
                    .EmailService
                    .AttemptCount);

            Assert.Equal(
                1,
                _fixture
                    .EmailService
                    .SuccessfulSendCount);

            Assert.Single(
                _fixture
                    .EmailService
                    .SentEmails);
        }
        finally
        {
            await RabbitMqWorkflowFixture
                .StopConsumerAsync(
                    consumer);
        }
    }

    [Fact]
    public async Task
        WorkerRestart_QueuedMessageIsProcessedAfterConsumerRestarts()
    {
        await _fixture.ResetAsync();

        _fixture.EmailService
            .Succeed();

        /*
         * Prvi worker pokrećemo pa ga uredno gasimo.
         */
        var firstConsumer =
            _fixture
                .CreateEmailConsumer();

        await _fixture
            .StartConsumerAsync(
                firstConsumer);

        await RabbitMqWorkflowFixture
            .StopConsumerAsync(
                firstConsumer);

        await _fixture.WaitUntilAsync(
            async () =>
                await _fixture
                    .GetQueueConsumerCountAsync(
                        _fixture.Options
                            .EmailQueue) ==
                0,

            TimeSpan.FromSeconds(
                10),

            "RabbitMQ worker did not stop.");

        /*
         * Poruka se objavljuje dok worker nije pokrenut.
         *
         * Durable RabbitMQ queue mora zadržati poruku.
         */
        var message =
            CreateMessage(
                subject:
                    "Worker restart workflow test");

        await _fixture
            .NotificationPublisher
            .PublishEmailAsync(
                message);

        await _fixture.WaitUntilAsync(
            async () =>
                await _fixture
                    .GetQueueMessageCountAsync(
                        _fixture.Options
                            .EmailQueue) ==
                1,

            TimeSpan.FromSeconds(
                10),

            "RabbitMQ did not retain the message while the worker was stopped.");

        Assert.Equal(
            0,
            _fixture
                .EmailService
                .SuccessfulSendCount);

        /*
         * Kreiramo novu instancu workera,
         * što simulira restart procesa.
         */
        var restartedConsumer =
            _fixture
                .CreateEmailConsumer();

        try
        {
            await _fixture
                .StartConsumerAsync(
                    restartedConsumer);

            await _fixture.WaitUntilAsync(
                () =>
                    Task.FromResult(
                        _fixture
                            .EmailService
                            .SuccessfulSendCount ==
                        1),

                TimeSpan.FromSeconds(
                    10),

                "RabbitMQ worker did not process the retained message after restart.");

            await _fixture.WaitUntilAsync(
                async () =>
                    await _fixture
                        .GetQueueMessageCountAsync(
                            _fixture.Options
                                .EmailQueue) ==
                    0,

                TimeSpan.FromSeconds(
                    10),

                "RabbitMQ queue was not drained after worker restart.");

            Assert.Equal(
                1,
                _fixture
                    .EmailService
                    .AttemptCount);

            Assert.Equal(
                message.RecipientEmail,
                Assert.Single(
                        _fixture
                            .EmailService
                            .SentEmails)
                    .To);
        }
        finally
        {
            await RabbitMqWorkflowFixture
                .StopConsumerAsync(
                    restartedConsumer);
        }
    }

    private static
        EmailNotificationMessage
        CreateMessage(
            string subject)
    {
        return new EmailNotificationMessage
        {
            MessageId =
                Guid.NewGuid(),

            CorrelationId =
                Guid.NewGuid(),

            EventType =
                NotificationEventType
                    .GenericEmail,

            RecipientEmail =
                "rabbitmq-workflow@mindbloom.test",

            RecipientName =
                "RabbitMQ Integration Test",

            Subject =
                subject,

            Body =
                "RabbitMQ integration workflow test body.",

            IsHtml =
                false,

            RetryCount =
                0,

            Source =
                "MindBloom.IntegrationTests"
        };
    }
}