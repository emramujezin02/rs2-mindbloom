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

    assert(scope != null, 'SessionScope was not found in the widget tree.');

    return scope!.notifier!;
  }
}
