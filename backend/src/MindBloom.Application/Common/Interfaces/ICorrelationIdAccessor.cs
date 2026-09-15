namespace MindBloom.Application.Common.Interfaces;

public interface ICorrelationIdAccessor
{
    string? CorrelationId { get; }
}