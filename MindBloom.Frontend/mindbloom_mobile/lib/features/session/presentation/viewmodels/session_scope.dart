import 'package:flutter/material.dart';

import 'session_viewmodel.dart';

class SessionScope extends InheritedNotifier<SessionViewModel> {
  const SessionScope({
    super.key,
    required SessionViewModel session,
    required super.child,
  }) : super(notifier: session);

  static SessionViewModel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();

    if (scope == null) {
      throw Exception('SessionScope not found.');
    }

    return scope.notifier!;
  }
}
