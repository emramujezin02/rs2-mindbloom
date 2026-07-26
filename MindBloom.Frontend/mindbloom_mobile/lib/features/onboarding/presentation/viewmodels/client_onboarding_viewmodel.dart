import 'package:flutter/foundation.dart';

import '../../../therapy_approach/data/models/therapy_approach_model.dart';
import '../../../therapy_approach/data/repositories/therapy_approach_repository.dart';
import '../../data/models/client_onboarding_model.dart';
import '../../data/models/save_client_onboarding_request.dart';
import '../../data/repositories/client_onboarding_repository.dart';

class ClientOnboardingViewModel extends ChangeNotifier {
  final ClientOnboardingRepository repository;

  final TherapyApproachRepository therapyApproachRepository;

  ClientOnboardingViewModel({
    required this.repository,
    required this.therapyApproachRepository,
  });

  bool isLoading = false;
  bool isSaving = false;

  String? error;

  ClientOnboardingModel? onboarding;

  List<TherapyApproachModel> therapyApproaches = [];

  Future<void> load() async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    error = null;

    notifyListeners();

    try {
      final results = await Future.wait([
        repository.getOnboarding(),
        therapyApproachRepository.getPublicTherapyApproaches(),
      ]);

      onboarding = results[0] as ClientOnboardingModel;

      therapyApproaches = results[1] as List<TherapyApproachModel>;
    } catch (exception) {
      error = _normalizeError(exception);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> save(SaveClientOnboardingRequest request) async {
    if (isSaving) {
      return false;
    }

    isSaving = true;
    error = null;

    notifyListeners();

    try {
      onboarding = await repository.saveOnboarding(request);

      return true;
    } catch (exception) {
      error = _normalizeError(exception);

      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  String _normalizeError(Object exception) {
    return exception.toString().replaceFirst('Exception: ', '');
  }
}
