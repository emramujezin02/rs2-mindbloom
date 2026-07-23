import 'therapist_model.dart';

class TherapistSearchPageModel {
  final List<TherapistModel> items;
  final int pageNumber;
  final int pageSize;
  final int totalCount;

  const TherapistSearchPageModel({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
  });

  bool get hasMore {
    return pageNumber * pageSize < totalCount;
  }

  factory TherapistSearchPageModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawItems =
        json['items'] ??
        json['Items'] ??
        json['data'] ??
        json['Data'] ??
        <dynamic>[];

    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (item) => TherapistModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : <TherapistModel>[];

    final pageNumber = _readInt(
      json['pageNumber'] ?? json['PageNumber'],
      fallback: 1,
    );

    final pageSize = _readInt(
      json['pageSize'] ?? json['PageSize'],
      fallback: items.isEmpty ? 10 : items.length,
    );

    final totalCount = _readInt(
      json['totalCount'] ??
          json['TotalCount'] ??
          json['totalItems'] ??
          json['TotalItems'],
      fallback: items.length,
    );

    return TherapistSearchPageModel(
      items: items,
      pageNumber: pageNumber,
      pageSize: pageSize,
      totalCount: totalCount,
    );
  }

  static int _readInt(
    dynamic value, {
    required int fallback,
  }) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ??
        fallback;
  }
}
