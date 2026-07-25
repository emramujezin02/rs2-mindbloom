namespace MindBloom.Domain.Entities;

public class ArticleCategory : BaseEntity
{
    public string Name { get; set; } =
        string.Empty;

    public string? Description { get; set; }

    public bool IsActive { get; set; } = true;

    public ICollection<Article> Articles { get; set; } =
        new List<Article>();
}