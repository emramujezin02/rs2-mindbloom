import 'package:flutter/material.dart';
import '../../screens/home_screen.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';

import '../../features/therapist/presentation/pages/therapist_list_page.dart';
import '../../features/therapist/presentation/pages/therapist_details_page.dart';
import '../../features/therapist/data/models/therapist_model.dart';

import '../../features/appointment/presentation/pages/appointment_create_page.dart';
import '../../features/appointment/presentation/pages/my_appointments_page.dart';
import '../../features/appointment/presentation/pages/appointment_details_page.dart';
import '../../features/appointment/data/models/appointment_model.dart';

import '../../features/payment/presentation/pages/payment_list_page.dart';

class AppRouter {
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String therapists = '/therapists';
  static const String therapistDetails = '/therapist-details';
  static const appointmentCreate = "/appointments/create";
  static const String myAppointments = '/appointments/mine';
  static const appointmentDetails = '/appointments/details';
  static const myPayments = '/payments';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());

      case register:
        return MaterialPageRoute(builder: (_) => const RegisterPage());

      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordPage());

      case resetPassword:
        final email = settings.arguments as String;

        return MaterialPageRoute(
          builder: (_) => ResetPasswordPage(email: email),
        );

      case therapists:
        return MaterialPageRoute(builder: (_) => const TherapistListPage());

      case therapistDetails:
        final therapist = settings.arguments as TherapistModel;

        return MaterialPageRoute(
          builder: (_) => TherapistDetailsPage(therapist: therapist),
        );

      case appointmentCreate:
        final therapist = settings.arguments as TherapistModel;

        return MaterialPageRoute(
          builder: (_) => AppointmentCreatePage(therapist: therapist),
        );

      case myAppointments:
        return MaterialPageRoute(builder: (_) => const MyAppointmentsPage());

      case appointmentDetails:
        final appointment = settings.arguments as AppointmentModel;

        return MaterialPageRoute(
          builder: (_) => AppointmentDetailsPage(appointment: appointment),
        );

      case myPayments:
        return MaterialPageRoute(builder: (_) => const PaymentListPage());

      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());

      default:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
    }
  }
}
