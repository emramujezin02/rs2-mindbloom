import 'package:flutter/foundation.dart';

import '../../data/models/therapist_mood_trend_model.dart';
import '../../data/repositories/therapist_repository.dart';

class TherapistEmotionalAnalyticsViewModel extends ChangeNotifier {
  final TherapistRepository repository;

  TherapistEmotionalAnalyticsViewModel({required this.repository});

  static const List<int> availablePeriods = [7, 14, 30, 90, 180, 365];

  bool isLoading = false;

  String? errorMessage;

  int selectedPeriod = 30;

  int? clientId;

  TherapistMoodTrendModel? analytics;

  bool get hasData => analytics?.hasData ?? false;

  Future<void> loadAnalytics({required int clientId, int? days}) async {
    if (isLoading) {
      return;
    }

    this.clientId = clientId;

    if (days != null) {
      selectedPeriod = _normalizePeriod(days);
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      analytics = await repository.getClientEmotionalAnalytics(
        clientId: clientId,
        days: selectedPeriod,
      );
    } catch (error) {
      errorMessage = _cleanError(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> changePeriod(int days) async {
    final currentClientId = clientId;

    if (currentClientId == null) {
      return;
    }

    final normalizedDays = _normalizePeriod(days);

    if (normalizedDays == selectedPeriod && analytics != null) {
      return;
    }

    selectedPeriod = normalizedDays;

    notifyListeners();

    await loadAnalytics(clientId: currentClientId, days: normalizedDays);
  }

  Future<void> refresh() async {
    final currentClientId = clientId;

    if (currentClientId == null) {
      return;
    }

    await loadAnalytics(clientId: currentClientId, days: selectedPeriod);
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  int _normalizePeriod(int value) {
    if (availablePeriods.contains(value)) {
      return value;
    }

    return 30;
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('AppException: ', '')
        .replaceFirst('FormatException: ', '')
        .trim();
  }
}
