import 'package:flutter/foundation.dart';

import '../../data/models/therapist_model.dart';
import '../../data/repositories/therapist_repository.dart';

class TherapistListViewModel extends ChangeNotifier {
  final TherapistRepository therapistRepository;

  bool isLoading = false;
  String? errorMessage;
  List<TherapistModel> therapists = [];

  TherapistListViewModel({required this.therapistRepository});

  Future<void> loadTherapists() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      therapists = await therapistRepository.getTherapists();
    } catch (error) {
      errorMessage = error.toString();
    }

    isLoading = false;
    notifyListeners();
  }
}
