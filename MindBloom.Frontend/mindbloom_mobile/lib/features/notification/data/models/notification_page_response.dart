import 'notification_model.dart';

class NotificationPageResponse {
  final List<NotificationModel> items;
  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final int unreadCount;

  const NotificationPageResponse({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
    required this.unreadCount,
  });

  bool get hasMorePages {
    return pageNumber < totalPages;
  }

  factory NotificationPageResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    return NotificationPageResponse(
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) => NotificationModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : [],
      pageNumber: _toInt(json['pageNumber'], fallback: 1),
      pageSize: _toInt(json['pageSize'], fallback: 20),
      totalCount: _toInt(json['totalCount']),
      totalPages: _toInt(json['totalPages']),
      unreadCount: _toInt(json['unreadCount']),
    );
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
