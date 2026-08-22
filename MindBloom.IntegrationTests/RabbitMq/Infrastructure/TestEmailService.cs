using System.Collections.Concurrent;
using MindBloom.Application.Common.Interfaces;

namespace MindBloom.IntegrationTests.RabbitMq.Infrastructure;

public sealed class TestEmailService
    : IEmailService
{
    private readonly ConcurrentQueue<
        SentEmail>
        _sentEmails =
            new();

    private int _attemptCount;

    private int _successfulSendCount;

    private int _failuresRemaining;

    private int _alwaysFail;

    public int AttemptCount =>
        Volatile.Read(
            ref _attemptCount);

    public int SuccessfulSendCount =>
        Volatile.Read(
            ref _successfulSendCount);

    public IReadOnlyList<SentEmail>
        SentEmails =>
            _sentEmails.ToArray();

    public Task SendAsync(
        string to,
        string subject,
        string body)
    {
        Interlocked.Increment(
            ref _attemptCount);

        if (Volatile.Read(
                ref _alwaysFail) == 1)
        {
            throw new Exception(
                "RabbitMQ integration test transient email failure.");
        }

        while (true)
        {
            var failuresRemaining =
                Volatile.Read(
                    ref _failuresRemaining);

            if (failuresRemaining <= 0)
            {
                break;
            }

            if (Interlocked.CompareExchange(
                    ref _failuresRemaining,
                    failuresRemaining - 1,
                    failuresRemaining) ==
                failuresRemaining)
            {
                throw new Exception(
                    "RabbitMQ integration test transient email failure.");
            }
        }

        _sentEmails.Enqueue(
            new SentEmail(
                to,
                subject,
                body));

        Interlocked.Increment(
            ref _successfulSendCount);

        return Task.CompletedTask;
    }

    public void FailNext(
        int failureCount)
    {
        if (failureCount < 0)
        {
            throw new ArgumentOutOfRangeException(
                nameof(failureCount));
        }

        Interlocked.Exchange(
            ref _alwaysFail,
            0);

        Interlocked.Exchange(
            ref _failuresRemaining,
            failureCount);
    }

    public void FailAlways()
    {
        Interlocked.Exchange(
            ref _failuresRemaining,
            0);

        Interlocked.Exchange(
            ref _alwaysFail,
            1);
    }

    public void Succeed()
    {
        Interlocked.Exchange(
            ref _failuresRemaining,
            0);

        Interlocked.Exchange(
            ref _alwaysFail,
            0);
    }

    public void Reset()
    {
        while (_sentEmails.TryDequeue(
                   out _))
        {
        }

        Interlocked.Exchange(
            ref _attemptCount,
            0);

        Interlocked.Exchange(
            ref _successfulSendCount,
            0);

        Interlocked.Exchange(
            ref _failuresRemaining,
            0);

        Interlocked.Exchange(
            ref _alwaysFail,
            0);
    }

    public sealed record SentEmail(
        string To,
        string Subject,
        string Body);
}