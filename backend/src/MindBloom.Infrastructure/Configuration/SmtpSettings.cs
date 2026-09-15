namespace MindBloom.Infrastructure.Configuration;

public sealed class SmtpSettings
{
    public string Host
    {
        get;
        set;
    } = "smtp.gmail.com";

    public int Port
    {
        get;
        set;
    } = 587;

    public bool EnableSsl
    {
        get;
        set;
    } = true;

    public string Username
    {
        get;
        set;
    } = string.Empty;

    public string Password
    {
        get;
        set;
    } = string.Empty;
}