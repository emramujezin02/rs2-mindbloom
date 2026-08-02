class ArticleCategoryReferenceModel {
  final int id;
  final String name;
  final String? description;
  final bool isActive;
  final int articleCount;
  final DateTime createdAtUtc;
  final DateTime? updatedAtUtc;

  const ArticleCategoryReferenceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
    required this.articleCount,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  factory ArticleCategoryReferenceModel.fromJson(Map<String, dynamic> json) {
    return ArticleCategoryReferenceModel(
      id: json['id'] as int? ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      isActive: json['isActive'] as bool? ?? false,
      articleCount: json['articleCount'] as int? ?? 0,
      createdAtUtc: DateTime.parse(json['createdAtUtc'].toString()),
      updatedAtUtc: json['updatedAtUtc'] == null
          ? null
          : DateTime.parse(json['updatedAtUtc'].toString()),
    );
  }
}
