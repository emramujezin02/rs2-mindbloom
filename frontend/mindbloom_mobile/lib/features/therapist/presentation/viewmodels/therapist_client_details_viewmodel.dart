import 'package:flutter/foundation.dart';

import '../../../../core/widgets/app_error_message.dart';
import '../../data/models/therapist_client_details_model.dart';
import '../../data/models/therapist_mood_entry_model.dart';
import '../../data/models/therapist_mood_trend_model.dart';
import '../../data/repositories/therapist_repository.dart';

class TherapistClientDetailsViewModel extends ChangeNotifier {
  bool _disposed = false;
  bool _basicOnly = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  final TherapistRepository repository;

  TherapistClientDetailsViewModel({required this.repository});

  bool isLoading = false;
  String? errorMessage;

  TherapistClientDetailsModel? client;
  List<TherapistMoodEntryModel> moodHistory = [];
  TherapistMoodTrendModel? moodTrend;

  Future<void> loadClientDetails(int clientId, {bool basicOnly = false}) async {
    if (isLoading) return;
    _basicOnly = basicOnly;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      if (basicOnly) {
        client = null;
        moodHistory = [];
        moodTrend = null;
        client = await repository.getTherapistClientProfile(clientId);
        return;
      }
      final results = await Future.wait<Object>([
        repository.getTherapistClientDetails(clientId),
        repository.getClientMoodHistory(clientId),
        repository.getClientMoodTrend(clientId),
      ]);

      client = results[0] as TherapistClientDetailsModel;
      moodHistory = results[1] as List<TherapistMoodEntryModel>;
      moodTrend = results[2] as TherapistMoodTrendModel;
      errorMessage = null;
    } catch (error) {
      errorMessage = AppErrorMessage.from(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() {
    final currentClientId = client?.clientId;
    if (currentClientId == null) return Future.value();
    return loadClientDetails(currentClientId, basicOnly: _basicOnly);
  }

  void clearError() {
    if (errorMessage == null) return;
    errorMessage = null;
    notifyListeners();
  }
}
