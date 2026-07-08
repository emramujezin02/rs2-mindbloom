import '../models/notification_model.dart';
import '../services/notification_api_service.dart';

class NotificationRepository {
  final NotificationApiService apiService;

  NotificationRepository({required this.apiService});

  Future<List<NotificationModel>> getNotifications() {
    return apiService.getNotifications();
  }

  Future<void> markAsRead(int id) {
    return apiService.markAsRead(id);
  }
}
