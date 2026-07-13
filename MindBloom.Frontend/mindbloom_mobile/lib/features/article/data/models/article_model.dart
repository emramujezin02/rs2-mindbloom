class ArticleModel {
  final int id;
  final String title;
  final String description;
  final String content;
  final String imageUrl;
  final int authorUserId;
  final int? therapistId;
  final String authorName;
  final DateTime publishedAtUtc;

  ArticleModel({
    required this.id,
    required this.title,
    required this.description,
    required this.content,
    required this.imageUrl,
    required this.authorUserId,
    required this.therapistId,
    required this.authorName,
    required this.publishedAtUtc,
  });

  factory ArticleModel.fromJson(Map<String, dynamic> json) {
    return ArticleModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      content: json['content'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      authorUserId: json['authorUserId'] ?? 0,
      therapistId: json['therapistId'] as int?,
      authorName: json['authorName'] ?? '',
      publishedAtUtc: DateTime.parse(json['publishedAtUtc']),
    );
  }
}
