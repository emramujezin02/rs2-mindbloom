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
  final bool isPublished;
  final int? articleCategoryId;
  final String articleCategoryName;

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
    required this.isPublished,
    required this.articleCategoryId,
    required this.articleCategoryName,
  });

  factory ArticleModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ArticleModel(
      id: _parseInt(json['id']),
      title: json['title']?.toString() ?? '',
      description:
          json['description']?.toString() ?? '',
      content:
          json['content']?.toString() ?? '',
      imageUrl:
          json['imageUrl']?.toString() ?? '',
      authorUserId:
          _parseInt(json['authorUserId']),
      therapistId:
          _parseNullableInt(
        json['therapistId'],
      ),
      authorName:
          json['authorName']?.toString() ?? '',
      publishedAtUtc:
          _parseDateTime(
        json['publishedAtUtc'],
      ),
      isPublished:
          json['isPublished'] == true,
      articleCategoryId:
          _parseNullableInt(
        json['articleCategoryId'],
      ),
      articleCategoryName:
          json['articleCategoryName']
                  ?.toString() ??
              '',
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static int? _parseNullableInt(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(
      value.toString(),
    );
  }

  static DateTime _parseDateTime(
    dynamic value,
  ) {
    final parsedDate =
        DateTime.tryParse(
      value?.toString() ?? '',
    );

    return parsedDate ??
        DateTime.fromMillisecondsSinceEpoch(
          0,
          isUtc: true,
        );
  }
}