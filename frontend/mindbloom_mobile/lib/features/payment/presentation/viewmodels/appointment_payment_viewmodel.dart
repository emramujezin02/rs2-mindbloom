import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/widgets/app_error_message.dart';
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
    if (isCheckingPayment) {
      return;
    }

    isCheckingPayment = true;
    errorMessage = null;
    notifyListeners();

    try {
      final loadedPayment = await repository.getPaymentForAppointment(
        appointmentId,
      );

      payment = loadedPayment;
      errorMessage = null;
    } catch (error) {
      errorMessage = AppErrorMessage.from(error);
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
        throw const AppException(
          message: 'Stripe client secret was not returned by the server.',
        );
      }

      if (paymentIntent.paymentIntentId.trim().isEmpty) {
        throw const AppException(
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

      await repository.confirmPayment(paymentIntent.paymentIntentId);

      final confirmedPayment = await repository.getPaymentForAppointment(
        appointmentId,
      );

      payment = confirmedPayment;
      errorMessage = null;

      return isPaid;
    } on StripeException catch (error) {
      final stripeCode = error.error.code.toString().toLowerCase();

      wasPaymentCancelled = stripeCode.contains('cancel');

      final localizedMessage = error.error.localizedMessage?.trim();

      errorMessage = wasPaymentCancelled
          ? 'Payment was cancelled.'
          : localizedMessage == null || localizedMessage.isEmpty
          ? 'Stripe payment could not be completed.'
          : localizedMessage;

      return false;
    } catch (error) {
      errorMessage = AppErrorMessage.from(error);
      return false;
    } finally {
      isPaying = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (errorMessage == null && !wasPaymentCancelled) {
      return;
    }

    errorMessage = null;
    wasPaymentCancelled = false;
    notifyListeners();
  }
}
