import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'app/app.dart';
import 'app/di/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const stripePublishableKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');

  if (stripePublishableKey.isEmpty) {
    throw StateError(
      'STRIPE_PUBLISHABLE_KEY is not configured. '
      'Start the application using '
      '--dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...',
    );
  }

  Stripe.publishableKey = stripePublishableKey;

  await Stripe.instance.applySettings();

  final session = AppInjection.createSessionViewModel();

  runApp(MindBloomMobileApp(session: session));

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(session.initialize());
  });
}
