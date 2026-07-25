class ArticleCategoryModel {
  final int id;
  final String name;

  const ArticleCategoryModel({
    required this.id,
    required this.name,
  });

  factory ArticleCategoryModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ArticleCategoryModel(
      id: _parseInt(json['id']),
      name: json['name']?.toString() ?? '',
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
}