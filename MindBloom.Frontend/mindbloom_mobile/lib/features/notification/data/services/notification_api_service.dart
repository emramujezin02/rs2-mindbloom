import '../../../../core/network/api_client.dart';
import '../models/notification_page_response.dart';

class NotificationApiService {
  final ApiClient apiClient;

  NotificationApiService({required this.apiClient});

  Future<NotificationPageResponse> getNotifications({
    required int pageNumber,
    required int pageSize,
    bool? isRead,
  }) async {
    final isReadQuery = isRead == null ? '' : '&isRead=$isRead';

    final response = await apiClient.get(
      '/Notifications'
      '?pageNumber=$pageNumber'
      '&pageSize=$pageSize'
      '$isReadQuery',
    );

    return NotificationPageResponse.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<int> getUnreadCount() async {
    final response = await apiClient.get('/Notifications/unread-count');

    final map = Map<String, dynamic>.from(response as Map);

    final value = map['unreadCount'];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> markAsRead(int notificationId) async {
    await apiClient.put(
      '/Notifications/'
      '$notificationId/read',
    );
  }

  Future<void> markAllAsRead() async {
    await apiClient.put('/Notifications/read-all');
  }
}
