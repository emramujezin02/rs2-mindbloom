import '../../../../core/network/api_client.dart';
import '../models/notification_model.dart';

class NotificationApiService {
  final ApiClient apiClient;

  NotificationApiService({required this.apiClient});

  Future<List<NotificationModel>> getNotifications() async {
    final response = await apiClient.get('/Notifications');

    return (response as List)
        .map((e) => NotificationModel.fromJson(e))
        .toList();
  }

  Future<void> markAsRead(int notificationId) async {
    await apiClient.put('/Notifications/$notificationId/read');
  }
}
