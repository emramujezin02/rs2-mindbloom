import 'package:flutter/foundation.dart';

import '../../data/models/therapist_model.dart';
import '../../data/repositories/therapist_repository.dart';
import '../../data/models/therapist_filter_request.dart';

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

  Future<void> searchTherapists({
    String? name,
    String? specialization,
    double? minPrice,
    double? maxPrice,
    String? sortBy,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      therapists = await therapistRepository.searchTherapists(
        TherapistFilterRequest(
          name: name,
          specialization: specialization,
          minPrice: minPrice,
          maxPrice: maxPrice,
          sortBy: sortBy,
        ),
      );
    } catch (error) {
      errorMessage = error.toString();
    }

    isLoading = false;
    notifyListeners();
  }
}
