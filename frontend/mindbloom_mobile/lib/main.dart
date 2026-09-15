import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'app/app.dart';
import 'app/di/injection.dart';
import 'core/debug/mindbloom_debug_log.dart';
import 'features/session/presentation/viewmodels/session_viewmodel.dart';

Future<void> main() async {
  final startupStopwatch = Stopwatch()..start();

  logStartup('main entered');

  WidgetsFlutterBinding.ensureInitialized();

  logStartup('Flutter binding initialized');

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    logStartup(
      'FlutterError ${details.exception.runtimeType}: ${details.exception}',
    );
    debugPrintStack(stackTrace: details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    logStartup('Uncaught async error ${error.runtimeType}: $error');
    debugPrintStack(stackTrace: stackTrace);

    return true;
  };

  const stripePublishableKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');

  if (stripePublishableKey.trim().isEmpty) {
    logStartup(
      'STRIPE_PUBLISHABLE_KEY is not configured; '
      'payment flows will stay unavailable in this run.',
    );
  } else if (!stripePublishableKey.startsWith('pk_test_')) {
    throw StateError(
      'MindBloom mobile payments must use a Stripe sandbox key. '
      'STRIPE_PUBLISHABLE_KEY must start with pk_test_.',
    );
  } else {
    Stripe.publishableKey = stripePublishableKey;

    logStartup('Stripe publishable key configured');
  }

  final session = AppInjection.createSessionViewModel();
  final notificationViewModel = AppInjection.createNotificationViewModel();

  logStartup('dependencies created');

  logStartup('BEFORE runApp');
  runApp(
    MindBloomMobileApp(
      session: session,
      notificationViewModel: notificationViewModel,
    ),
  );

  logStartup('AFTER runApp elapsedMs=${startupStopwatch.elapsedMilliseconds}');

  WidgetsBinding.instance.addPostFrameCallback((_) {
    logStartup('first frame rendered');
    unawaited(
      _initializeApplication(session).catchError((Object error, stackTrace) {
        logStartup(
          'application initialization failed '
          '${error.runtimeType}: $error',
        );
      }),
    );
  });
}

Future<void> _initializeApplication(SessionViewModel session) async {
  /*
   * Sesija mora biti inicijalizovana odmah.
   *
   * Login/Home ekran ne smije zavisiti od Stripe native
   * inicijalizacije.
  */
  final stopwatch = Stopwatch()..start();
  logStartup('session restore started');

  await session.initialize();

  logStartup(
    'session restore completed durationMs=${stopwatch.elapsedMilliseconds}',
  );
}
