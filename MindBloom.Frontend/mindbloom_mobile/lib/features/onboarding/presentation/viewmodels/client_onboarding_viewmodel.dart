import 'package:flutter/foundation.dart';

import '../../../therapy_approach/data/models/therapy_approach_model.dart';
import '../../../therapy_approach/data/repositories/therapy_approach_repository.dart';
import '../../data/models/client_onboarding_model.dart';
import '../../data/models/save_client_onboarding_request.dart';
import '../../data/repositories/client_onboarding_repository.dart';
import '../../../../core/error/app_exception.dart';

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

  Map<String, List<String>> fieldErrors = {};

  String? fieldError(String fieldName) {
    final requested = _normalizeFieldName(fieldName);

    for (final entry in fieldErrors.entries) {
      if (_normalizeFieldName(entry.key) == requested &&
          entry.value.isNotEmpty) {
        return entry.value.first;
      }
    }

    return null;
  }

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
    fieldErrors = {};

    notifyListeners();

    try {
      onboarding = await repository.saveOnboarding(request);

      return true;
    } catch (exception) {
      _setError(exception, fallback: 'Preference nije moguće sačuvati.');

      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  String _normalizeError(Object exception) {
    if (exception is AppException) {
      return exception.message;
    }

    return exception.toString().replaceFirst('Exception: ', '').trim();
  }

  void _setError(Object exception, {required String fallback}) {
    if (exception is AppException) {
      error = exception.message.trim().isEmpty
          ? fallback
          : exception.message.trim();

      fieldErrors = Map<String, List<String>>.from(exception.fieldErrors);

      return;
    }

    final message = exception.toString().replaceFirst('Exception: ', '').trim();

    error = message.isEmpty ? fallback : message;
  }

  String _normalizeFieldName(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toLowerCase();
  }
}
