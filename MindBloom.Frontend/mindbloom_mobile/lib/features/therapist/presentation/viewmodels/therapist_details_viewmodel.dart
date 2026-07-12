import 'package:flutter/foundation.dart';

import '../../data/models/therapist_details_model.dart';
import '../../data/repositories/therapist_repository.dart';

class TherapistDetailsViewModel extends ChangeNotifier {
  final TherapistRepository repository;

  TherapistDetailsViewModel({required this.repository});

  bool isLoading = false;
  String? errorMessage;

  TherapistDetailsModel? therapist;

  Future<void> loadTherapist(int therapistId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      therapist = await repository.getTherapistById(therapistId);
    } catch (error) {
      errorMessage = error.toString();
    }

    isLoading = false;
    notifyListeners();
  }
}
