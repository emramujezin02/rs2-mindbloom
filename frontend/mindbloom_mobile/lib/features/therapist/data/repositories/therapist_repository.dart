import 'dart:io';

import '../../../../core/models/paged_response.dart';
import 'package:mindbloom_mobile/features/therapist/data/models/create_unavailable_date_request.dart';

import '../models/create_therapist_availability_request.dart';
import '../models/therapist_client_details_model.dart';
import '../models/therapist_client_model.dart';
import '../models/therapist_dashboard_model.dart';
import '../models/therapist_details_model.dart';
import '../models/therapist_filter_request.dart';
import '../models/therapist_mood_entry_model.dart';
import '../models/therapist_mood_trend_model.dart';
import '../models/therapist_model.dart';
import '../models/therapist_profile_image_model.dart';
import '../models/therapist_profile_model.dart';
import '../models/therapist_search_page_model.dart';
import '../models/update_therapist_profile_request.dart';
import '../services/therapist_api_service.dart';
import '../models/therapist_availability_model.dart';
import '../../../appointment/data/models/unavailable_date_model.dart';

class TherapistRepository {
  final TherapistApiService therapistApiService;

  TherapistRepository({required this.therapistApiService});

  Future<List<TherapistModel>> getTherapists() {
    return therapistApiService.getTherapists();
  }

  Future<TherapistSearchPageModel> searchTherapists(
    TherapistFilterRequest request,
  ) {
    return therapistApiService.searchTherapists(request);
  }

  Future<TherapistDetailsModel> getTherapistById(int therapistId) {
    return therapistApiService.getTherapistById(therapistId);
  }

  Future<TherapistDashboardModel> getDashboard() {
    return therapistApiService.getDashboard();
  }

  Future<PagedResponse<TherapistClientModel>> getTherapistClients({
    String? search,
    required int pageNumber,
    required int pageSize,
  }) {
    return therapistApiService.getTherapistClients(
      search: search,
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
  }

  Future<TherapistClientDetailsModel> getTherapistClientDetails(int clientId) {
    return therapistApiService.getTherapistClientDetails(clientId);
  }

  Future<TherapistProfileModel> getTherapistProfile() {
    return therapistApiService.getTherapistProfile();
  }

  Future<void> updateTherapistProfile(UpdateTherapistProfileRequest request) {
    return therapistApiService.updateTherapistProfile(request);
  }

  Future<TherapistProfileImageModel> uploadTherapistProfileImage(File file) {
    return therapistApiService.uploadTherapistProfileImage(file);
  }

  Future<void> deleteTherapistProfileImage() {
    return therapistApiService.deleteTherapistProfileImage();
  }

  Future<void> addTherapistAvailability({
    required CreateTherapistAvailabilityRequest request,
  }) {
    return therapistApiService.addTherapistAvailability(request: request);
  }

  Future<void> deleteTherapistAvailability(int availabilityId) {
    return therapistApiService.deleteTherapistAvailability(availabilityId);
  }

  Future<List<TherapistMoodEntryModel>> getClientMoodHistory(int clientId) {
    return therapistApiService.getClientMoodHistory(clientId);
  }

  Future<TherapistMoodTrendModel> getClientMoodTrend(int clientId) {
    return therapistApiService.getClientMoodTrend(clientId);
  }

  Future<TherapistMoodTrendModel> getClientEmotionalAnalytics({
    required int clientId,
    required int days,
  }) {
    return therapistApiService.getClientEmotionalAnalytics(
      clientId: clientId,
      days: days,
    );
  }

  Future<List<TherapistAvailabilityModel>> getOwnAvailabilities(
    int therapistId,
  ) {
    return therapistApiService.getOwnAvailabilities(therapistId);
  }

  Future<PagedResponse<UnavailableDateModel>> getUnavailableDates({
    required int therapistId,
    required DateTime fromUtc,
    required DateTime toUtc,
  }) {
    return therapistApiService.getUnavailableDates(
      therapistId: therapistId,
      fromUtc: fromUtc,
      toUtc: toUtc,
    );
  }

  Future<void> addUnavailableDate(CreateUnavailableDateRequest request) {
    return therapistApiService.addUnavailableDate(request);
  }

  Future<void> deleteUnavailableDate(int unavailableDateId) {
    return therapistApiService.deleteUnavailableDate(unavailableDateId);
  }
}
