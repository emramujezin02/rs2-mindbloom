import 'package:flutter/material.dart';

import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';

class NotificationViewModel extends ChangeNotifier {
  final NotificationRepository repository;

  NotificationViewModel({required this.repository});

  bool isLoading = false;

  List<NotificationModel> notifications = [];

  Future<void> loadNotifications() async {
    isLoading = true;

    notifyListeners();

    notifications = await repository.getNotifications();

    isLoading = false;

    notifyListeners();
  }

  Future<void> markAsRead(int id) async {
    await repository.markAsRead(id);

    await loadNotifications();
  }
}
