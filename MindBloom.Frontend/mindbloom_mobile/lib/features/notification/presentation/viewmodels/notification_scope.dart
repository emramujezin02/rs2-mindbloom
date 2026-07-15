import 'package:flutter/material.dart';

import 'notification_viewmodel.dart';

class NotificationScope extends InheritedNotifier<NotificationViewModel> {
  const NotificationScope({
    super.key,
    required NotificationViewModel notificationViewModel,
    required super.child,
  }) : super(notifier: notificationViewModel);

  static NotificationViewModel of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<NotificationScope>();

    if (scope == null) {
      throw StateError('NotificationScope not found.');
    }

    return scope.notifier!;
  }
}
