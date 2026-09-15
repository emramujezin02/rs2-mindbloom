namespace MindBloom.Application.Common.Exceptions;

public sealed class ExternalProviderException
    : Exception
{
    public string Provider { get; }

    public ExternalProviderException(
        string provider,
        string message)
        : base(message)
    {
        Provider =
            provider;
    }

    public ExternalProviderException(
        string provider,
        string message,
        Exception innerException)
        : base(
            message,
            innerException)
    {
        Provider =
            provider;
    }
}