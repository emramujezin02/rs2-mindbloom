class ArticleManagementModel {
  final int id;
  final String title;
  final String description;
  final String content;
  final String imageUrl;
  final int authorUserId;
  final int? therapistId;
  final String authorName;
  final DateTime publishedAtUtc;
  final bool isPublished;

  const ArticleManagementModel({
    required this.id,
    required this.title,
    required this.description,
    required this.content,
    required this.imageUrl,
    required this.authorUserId,
    required this.therapistId,
    required this.authorName,
    required this.publishedAtUtc,
    required this.isPublished,
  });

  factory ArticleManagementModel.fromJson(Map<String, dynamic> json) {
    return ArticleManagementModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      content: json['content'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      authorUserId: json['authorUserId'] ?? 0,
      therapistId: json['therapistId'],
      authorName: json['authorName'] ?? '',
      publishedAtUtc: DateTime.parse(json['publishedAtUtc']),
      isPublished: json['isPublished'] ?? false,
    );
  }
}
