import '../models/notification_page_response.dart';
import '../services/notification_api_service.dart';

class NotificationRepository {
  final NotificationApiService apiService;

  NotificationRepository({required this.apiService});

  Future<NotificationPageResponse> getNotifications({
    required int pageNumber,
    required int pageSize,
    bool? isRead,
  }) {
    return apiService.getNotifications(
      pageNumber: pageNumber,
      pageSize: pageSize,
      isRead: isRead,
    );
  }

  Future<int> getUnreadCount() {
    return apiService.getUnreadCount();
  }

  Future<void> markAsRead(int id) {
    return apiService.markAsRead(id);
  }

  Future<void> markAllAsRead() {
    return apiService.markAllAsRead();
  }
}
