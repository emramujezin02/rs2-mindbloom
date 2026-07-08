import 'package:flutter/material.dart';

import '../../data/models/appointment_model.dart';
import '../../data/repositories/appointment_repository.dart';

class MyAppointmentsViewModel extends ChangeNotifier {
  final AppointmentRepository repository;

  MyAppointmentsViewModel({required this.repository});

  bool isLoading = false;
  String? error;
  List<AppointmentModel> appointments = [];

  Future<void> loadAppointments() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      appointments = await repository.getMyAppointments();
    } catch (e) {
      error = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }
}
