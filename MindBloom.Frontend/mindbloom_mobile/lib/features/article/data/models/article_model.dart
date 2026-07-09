class ArticleModel {
  final int id;
  final String title;
  final String description;
  final String imageUrl;
  final DateTime createdAtUtc;

  ArticleModel({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.createdAtUtc,
  });

  factory ArticleModel.fromJson(Map<String, dynamic> json) {
    return ArticleModel(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      createdAtUtc: DateTime.parse(json['createdAtUtc']),
    );
  }
}
