import 'package:flutter/material.dart';

import '../../data/models/workshop_model.dart';
import '../../data/repositories/workshop_repository.dart';

class WorkshopViewModel extends ChangeNotifier {
  final WorkshopRepository repository;

  WorkshopViewModel({required this.repository});

  bool isLoading = false;
  String? error;

  List<WorkshopModel> workshops = [];

  Future<void> loadWorkshops() async {
    isLoading = true;
    error = null;

    notifyListeners();

    try {
      workshops = await repository.getWorkshops();
    } catch (e) {
      error = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> register(int id) async {
    await repository.register(id);
  }
}
