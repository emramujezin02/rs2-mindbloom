import 'dart:async';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/di/injection.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final session = AppInjection.createSessionViewModel();

  runApp(MindBloomDesktopApp(session: session));

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(session.initialize());
  });
}
