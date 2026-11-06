import 'package:flutter/foundation.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/widgets/app_error_message.dart';
import '../../data/models/therapist_client_details_model.dart';
import '../../data/models/therapist_mood_entry_model.dart';
import '../../data/models/therapist_mood_trend_model.dart';
import '../../data/repositories/therapist_repository.dart';

class TherapistClientDetailsViewModel extends ChangeNotifier {
  bool _disposed = false;
  bool _basicOnly = false;
  int _loadGeneration = 0;
  int? _clientId;
  bool _moodUnavailable = false;
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
  String? moodHistoryMessage;
  String? moodTrendMessage;
  bool isLoadingMood = false;

  static const moodUnavailableMessage = 'Mood data is not available.';

  bool _isCurrent(int generation) =>
      !_disposed && generation == _loadGeneration;

  Future<void> loadClientDetails(int clientId, {bool basicOnly = false}) async {
    if (_disposed) return;
    final generation = ++_loadGeneration;
    _clientId = clientId;
    _basicOnly = basicOnly;

    isLoading = true;
    errorMessage = null;
    client = null;
    moodHistory = [];
    moodTrend = null;
    moodHistoryMessage = null;
    moodTrendMessage = null;
    isLoadingMood = false;
    _moodUnavailable = false;
    notifyListeners();

    try {
      if (basicOnly) {
        final profile = await repository.getTherapistClientProfile(clientId);
        if (_isCurrent(generation)) client = profile;
        return;
      }
      final profile = await repository.getTherapistClientDetails(clientId);
      if (!_isCurrent(generation)) return;
      client = profile;
      isLoadingMood = true;
      notifyListeners();

      await Future.wait([
        _loadOptionalMood<List<TherapistMoodEntryModel>>(
          () => repository.getClientMoodHistory(clientId),
          (value) => moodHistory = value,
          (message) => moodHistoryMessage = message,
          generation,
        ),
        _loadOptionalMood<TherapistMoodTrendModel>(
          () => repository.getClientMoodTrend(clientId),
          (value) => moodTrend = value,
          (message) => moodTrendMessage = message,
          generation,
        ),
      ]);
    } catch (error) {
      if (_isCurrent(generation)) errorMessage = AppErrorMessage.from(error);
    } finally {
      if (_isCurrent(generation)) {
        isLoading = false;
        isLoadingMood = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadOptionalMood<T>(
    Future<T> Function() request,
    void Function(T) setData,
    void Function(String) setMessage,
    int generation,
  ) async {
    try {
      final value = await request();
      if (_isCurrent(generation) && !_moodUnavailable) setData(value);
    } catch (error) {
      if (!_isCurrent(generation)) return;
      if (error is AppException &&
          (error.statusCode == 403 || error.statusCode == 404)) {
        // Both endpoints share the same consent/relationship requirement.
        // A late successful response must not restore data after a denial.
        _moodUnavailable = true;
        moodHistory = [];
        moodTrend = null;
        moodHistoryMessage = moodUnavailableMessage;
        moodTrendMessage = moodUnavailableMessage;
      } else if (!_moodUnavailable) {
        setMessage(error is AppException && (error.statusCode ?? 0) >= 500
            ? AppErrorMessage.serverUnavailable
            : AppErrorMessage.from(error));
      }
    }
  }

  Future<void> refresh() {
    final currentClientId = _clientId;
    if (currentClientId == null) return Future.value();
    return loadClientDetails(currentClientId, basicOnly: _basicOnly);
  }

  void clearError() {
    if (errorMessage == null) return;
    errorMessage = null;
    notifyListeners();
  }
}
