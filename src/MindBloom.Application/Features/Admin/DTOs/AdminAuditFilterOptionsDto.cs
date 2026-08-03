namespace MindBloom.Application.Features.Admin.DTOs;

public class AdminAuditFilterOptionsDto
{
    public IReadOnlyList<AdminAuditUserOptionDto>
        Users
    { get; set; } =
        Array.Empty<AdminAuditUserOptionDto>();

    public IReadOnlyList<string>
        Actions
    { get; set; } =
        Array.Empty<string>();

    public IReadOnlyList<string>
        EntityTypes
    { get; set; } =
        Array.Empty<string>();
}

public class AdminAuditUserOptionDto
{
    public int Id { get; set; }

    public string FullName { get; set; }
        = string.Empty;

    public string Email { get; set; }
        = string.Empty;
}