import 'package:flutter/foundation.dart';

import '../../data/models/therapist_client_details_model.dart';
import '../../data/models/therapist_mood_entry_model.dart';
import '../../data/models/therapist_mood_trend_model.dart';
import '../../data/repositories/therapist_repository.dart';

class TherapistClientDetailsViewModel extends ChangeNotifier {
  final TherapistRepository repository;

  TherapistClientDetailsViewModel({required this.repository});

  bool isLoading = false;

  String? errorMessage;

  TherapistClientDetailsModel? client;

  List<TherapistMoodEntryModel> moodHistory = [];

  TherapistMoodTrendModel? moodTrend;

  Future<void> loadClientDetails(int clientId) async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        repository.getTherapistClientDetails(clientId),
        repository.getClientMoodHistory(clientId),
        repository.getClientMoodTrend(clientId),
      ]);

      client = results[0] as TherapistClientDetailsModel;

      moodHistory = results[1] as List<TherapistMoodEntryModel>;

      moodTrend = results[2] as TherapistMoodTrendModel;
    } catch (error) {
      errorMessage = _cleanError(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    final currentClient = client;

    if (currentClient == null) {
      return;
    }

    await loadClientDetails(currentClient.clientId);
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('AppException: ', '')
        .trim();
  }
}
