import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'app/app.dart';
import 'app/di/injection.dart';
import 'features/notification/presentation/viewmodels/notification_viewmodel.dart';
import 'features/session/presentation/viewmodels/session_viewmodel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const stripePublishableKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');

  if (stripePublishableKey.trim().isEmpty) {
    throw StateError(
      'STRIPE_PUBLISHABLE_KEY is not configured. '
      'Start the application using '
      '--dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_your_publishable_key',
    );
  }

  if (!stripePublishableKey.startsWith('pk_test_')) {
    throw StateError(
      'MindBloom mobile payments must use a Stripe sandbox key. '
      'STRIPE_PUBLISHABLE_KEY must start with pk_test_.',
    );
  }

  Stripe.publishableKey = stripePublishableKey;

  await Stripe.instance.applySettings();

  final session = AppInjection.createSessionViewModel();

  final notificationViewModel = AppInjection.createNotificationViewModel();

  runApp(
    MindBloomMobileApp(
      session: session,
      notificationViewModel: notificationViewModel,
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initializeApplication(session, notificationViewModel));
  });
}

Future<void> _initializeApplication(
  SessionViewModel session,
  NotificationViewModel notificationViewModel,
) async {
  await session.initialize();

  if (session.isLoggedIn) {
    await notificationViewModel.initialize();
  }
}
