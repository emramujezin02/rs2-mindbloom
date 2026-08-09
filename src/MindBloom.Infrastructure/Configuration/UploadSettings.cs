namespace MindBloom.Infrastructure.Configuration;

public sealed class UploadSettings
{
    public int MaximumImageSizeMb
    {
        get;
        set;
    } = 5;

    public int MaximumDocumentSizeMb
    {
        get;
        set;
    } = 10;

    public string RootFolder
    {
        get;
        set;
    } = "uploads";

    public long MaximumImageSizeBytes =>
        MaximumImageSizeMb * 1024L * 1024L;

    public long MaximumDocumentSizeBytes =>
        MaximumDocumentSizeMb * 1024L * 1024L;
}