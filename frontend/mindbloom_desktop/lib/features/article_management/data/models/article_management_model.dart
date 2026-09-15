class ArticleManagementModel {
  final int id;

  final String title;

  final String description;

  final String content;

  final String imageUrl;

  final int authorUserId;

  final int? therapistId;

  final String authorName;

  final int? articleCategoryId;

  final String articleCategoryName;

  final DateTime? publishedAtUtc;

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
    required this.articleCategoryId,
    required this.articleCategoryName,
    required this.publishedAtUtc,
    required this.isPublished,
  });

  factory ArticleManagementModel.fromJson(Map<String, dynamic> json) {
    return ArticleManagementModel(
      id: _toInt(json['id']),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      authorUserId: _toInt(json['authorUserId']),
      therapistId: _toNullableInt(json['therapistId']),
      authorName: json['authorName']?.toString() ?? '',
      articleCategoryId: _toNullableInt(json['articleCategoryId']),
      articleCategoryName: json['articleCategoryName']?.toString() ?? '',
      publishedAtUtc: json['publishedAtUtc'] == null
          ? null
          : DateTime.tryParse(json['publishedAtUtc'].toString())?.toUtc(),
      isPublished: json['isPublished'] == true,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _toNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }
}
