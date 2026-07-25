import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../../../core/error/app_exception.dart';
import '../../data/models/payment_model.dart';
import '../../data/repositories/payment_repository.dart';

class AppointmentPaymentViewModel extends ChangeNotifier {
  final PaymentRepository repository;

  AppointmentPaymentViewModel({required this.repository});

  bool isCheckingPayment = false;
  bool isPaying = false;
  bool wasPaymentCancelled = false;

  String? errorMessage;

  PaymentModel? payment;

  bool get isPaid => payment?.isPaid == true;

  bool get isRefundPending => payment?.isRefundPending == true;

  bool get isRefunded => payment?.isRefunded == true;

  bool get isRefundFailed => payment?.isRefundFailed == true;

  bool get hasRefundProcess => payment?.hasRefundProcess == true;

  int? get paymentId => payment?.id;

  Future<void> loadPaymentStatus(int appointmentId) async {
    isCheckingPayment = true;
    errorMessage = null;

    notifyListeners();

    try {
      payment = await repository.getPaymentForAppointment(appointmentId);
    } catch (error) {
      errorMessage = _normalizeError(error);
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
    wasPaymentCancelled = false;
    errorMessage = null;

    notifyListeners();

    try {
      final paymentIntent = await repository.createPaymentIntent(appointmentId);

      if (paymentIntent.clientSecret.trim().isEmpty) {
        throw AppException(
          message: 'Stripe client secret was not returned by the server.',
        );
      }

      if (paymentIntent.paymentIntentId.trim().isEmpty) {
        throw AppException(
          message: 'Stripe PaymentIntent ID was not returned by the server.',
        );
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntent.clientSecret,
          merchantDisplayName: 'MindBloom',
          style: ThemeMode.system,
          primaryButtonLabel:
              'Pay ${paymentIntent.amount.toStringAsFixed(2)} '
              '${paymentIntent.currency.toUpperCase()}',
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      // Lokalni Stripe callback nije dovoljan.
      // Backend ponovo provjerava Stripe status,
      // iznos, valutu i metadata.
      await repository.confirmPayment(paymentIntent.paymentIntentId);

      // Status se ponovo učitava sa backenda.
      await loadPaymentStatus(appointmentId);

      return isPaid;
    } on StripeException catch (error) {
      final stripeCode = error.error.code.toString().toLowerCase();

      wasPaymentCancelled = stripeCode.contains('cancel');

      errorMessage = wasPaymentCancelled
          ? 'Payment was cancelled.'
          : error.error.localizedMessage ??
                'Stripe payment could not be completed.';

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
    if (error is AppException) {
      return error.message;
    }

    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }

    return message;
  }
}
