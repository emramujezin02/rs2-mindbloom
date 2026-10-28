class TherapistLocationModel {
  final int id, therapistCount;
  final String name, country, region;
  final bool isActive;
  const TherapistLocationModel({
    required this.id,
    required this.name,
    required this.country,
    this.region = '',
    required this.isActive,
    this.therapistCount = 0,
  });
  factory TherapistLocationModel.fromJson(Map<String, dynamic> json) =>
      TherapistLocationModel(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        country: json['country'] as String,
        region: json['region'] as String? ?? '',
        isActive: json['isActive'] == true,
        therapistCount: (json['therapistCount'] as num?)?.toInt() ?? 0,
      );
}

class TherapistLocationPage {
  final List<TherapistLocationModel> items;
  final int pageNumber, pageSize, totalCount, totalPages;
  TherapistLocationPage.fromJson(Map<String, dynamic> json)
    : items = (json['items'] as List)
          .map(
            (x) => TherapistLocationModel.fromJson(
              Map<String, dynamic>.from(x as Map),
            ),
          )
          .toList(),
      pageNumber = (json['pageNumber'] as num).toInt(),
      pageSize = (json['pageSize'] as num).toInt(),
      totalCount = (json['totalCount'] as num).toInt(),
      totalPages = (json['totalPages'] as num).toInt();
}
