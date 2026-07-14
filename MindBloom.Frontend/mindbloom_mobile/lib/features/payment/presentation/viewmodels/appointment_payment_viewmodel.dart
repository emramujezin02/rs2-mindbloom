import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../data/repositories/payment_repository.dart';

class AppointmentPaymentViewModel extends ChangeNotifier {
  final PaymentRepository repository;

  AppointmentPaymentViewModel({required this.repository});

  bool isCheckingPayment = false;
  bool isPaying = false;
  bool isPaid = false;

  String? errorMessage;

  Future<void> loadPaymentStatus(int appointmentId) async {
    isCheckingPayment = true;
    errorMessage = null;

    notifyListeners();

    try {
      isPaid = await repository.isAppointmentPaid(appointmentId);
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isCheckingPayment = false;

      notifyListeners();
    }
  }

  Future<bool> payForAppointment(int appointmentId) async {
    if (isPaying || isPaid) {
      return false;
    }

    isPaying = true;
    errorMessage = null;

    notifyListeners();

    try {
      final paymentIntent = await repository.createPaymentIntent(appointmentId);

      if (paymentIntent.clientSecret.trim().isEmpty) {
        throw Exception('Stripe client secret was not returned by the server.');
      }

      if (paymentIntent.paymentIntentId.trim().isEmpty) {
        throw Exception(
          'Stripe PaymentIntent ID was not returned by the server.',
        );
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntent.clientSecret,
          merchantDisplayName: 'MindBloom',
          style: ThemeMode.system,
          primaryButtonLabel: 'Pay appointment',
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      await repository.confirmPayment(paymentIntent.paymentIntentId);

      isPaid = true;

      return true;
    } on StripeException catch (error) {
      errorMessage =
          error.error.localizedMessage ??
          'Stripe payment was cancelled or could not be completed.';

      return false;
    } catch (error) {
      errorMessage = _normalizeError(error);

      return false;
    } finally {
      isPaying = false;

      notifyListeners();
    }
  }

  String _normalizeError(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }

    return message;
  }
}
