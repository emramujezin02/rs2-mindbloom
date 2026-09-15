class ArticleFormRequest {
  final String title;

  final String description;

  final String content;

  final String? imageUrl;

  final int articleCategoryId;

  final bool isPublished;

  const ArticleFormRequest({
    required this.title,
    required this.description,
    required this.content,
    required this.imageUrl,
    required this.articleCategoryId,
    required this.isPublished,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title.trim(),
      'description': description.trim(),
      'content': content.trim(),
      'imageUrl': imageUrl == null || imageUrl!.trim().isEmpty
          ? null
          : imageUrl!.trim(),
      'articleCategoryId': articleCategoryId,
      'isPublished': isPublished,
    };
  }
}
