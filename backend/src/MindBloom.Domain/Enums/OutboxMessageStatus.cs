namespace MindBloom.Domain.Enums;

public enum OutboxMessageStatus
{
    Pending = 1,

    Processing = 2,

    RetryPending = 3,

    Processed = 4,

    DeadLettered = 5
}