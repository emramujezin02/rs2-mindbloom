import 'package:flutter/foundation.dart';

import '../../data/models/therapist_verification_details_model.dart';
import '../../data/repositories/therapist_verification_repository.dart';
import '../../../../core/error/app_error_helper.dart';

class TherapistVerificationDetailsViewModel extends ChangeNotifier {
  final TherapistVerificationRepository repository;

  TherapistVerificationDetailsViewModel({required this.repository});

  bool isLoading = false;
  bool isSubmitting = false;

  String? errorMessage;

  TherapistVerificationDetailsModel? therapist;

  Future<void> load(int therapistId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      therapist = await repository.getDetails(therapistId);
    } catch (error) {
      errorMessage = AppErrorHelper.message(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> approve({required int therapistId, String? notes}) {
    return _update(therapistId: therapistId, status: 2, notes: notes);
  }

  Future<bool> reject({required int therapistId, required String reason}) {
    return _update(therapistId: therapistId, status: 3, notes: reason);
  }

  Future<bool> _update({
    required int therapistId,
    required int status,
    String? notes,
  }) async {
    if (isSubmitting) {
      return false;
    }

    isSubmitting = true;
    errorMessage = null;
    notifyListeners();

    try {
      await repository.updateVerification(
        therapistId: therapistId,
        status: status,
        notes: notes,
      );

      await load(therapistId);

      return true;
    } catch (error) {
      errorMessage = AppErrorHelper.message(error);

      return false;
    }
  }

  Future<bool> requestChanges({
    required int therapistId,
    required String reason,
  }) {
    return _update(therapistId: therapistId, status: 4, notes: reason);
  }
}
