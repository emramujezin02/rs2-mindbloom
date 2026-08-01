class ArticleCategoryModel {
  final int id;

  final String name;

  const ArticleCategoryModel({required this.id, required this.name});

  factory ArticleCategoryModel.fromJson(Map<String, dynamic> json) {
    return ArticleCategoryModel(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}
