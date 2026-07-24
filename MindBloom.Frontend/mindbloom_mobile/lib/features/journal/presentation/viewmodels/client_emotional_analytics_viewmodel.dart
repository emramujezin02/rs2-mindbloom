import 'package:flutter/material.dart';

import '../../../therapist/data/models/therapist_mood_trend_model.dart';
import '../../data/repositories/journal_repository.dart';

enum AnalyticsPeriodType { week, month, custom }

class ClientEmotionalAnalyticsViewModel extends ChangeNotifier {
  final JournalRepository repository;

  ClientEmotionalAnalyticsViewModel({required this.repository});

  bool isLoading = false;

  String? error;

  TherapistMoodTrendModel? analytics;

  AnalyticsPeriodType selectedPeriod = AnalyticsPeriodType.month;

  DateTime? customFrom;

  DateTime? customTo;

  bool get hasData => analytics?.hasData ?? false;

  Future<void> loadInitial() async {
    await selectMonth();
  }

  Future<void> selectWeek() async {
    selectedPeriod = AnalyticsPeriodType.week;

    final now = DateTime.now();

    final from = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));

    final to = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    await _load(from: from, to: to);
  }

  Future<void> selectMonth() async {
    selectedPeriod = AnalyticsPeriodType.month;

    final now = DateTime.now();

    final from = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 29));

    final to = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    await _load(from: from, to: to);
  }

  Future<void> selectCustom({
    required DateTime from,
    required DateTime to,
  }) async {
    selectedPeriod = AnalyticsPeriodType.custom;

    customFrom = from;
    customTo = to;

    final normalizedFrom = DateTime(from.year, from.month, from.day);

    final normalizedTo = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);

    await _load(from: normalizedFrom, to: normalizedTo);
  }

  Future<void> refresh() async {
    switch (selectedPeriod) {
      case AnalyticsPeriodType.week:
        await selectWeek();
        break;

      case AnalyticsPeriodType.month:
        await selectMonth();
        break;

      case AnalyticsPeriodType.custom:
        final from = customFrom;
        final to = customTo;

        if (from != null && to != null) {
          await selectCustom(from: from, to: to);
        }
        break;
    }
  }

  Future<void> _load({required DateTime from, required DateTime to}) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      analytics = await repository.getMyEmotionalAnalytics(
        fromUtc: from.toUtc(),
        toUtc: to.toUtc(),
      );
    } catch (exception) {
      error = exception
          .toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('FormatException: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
