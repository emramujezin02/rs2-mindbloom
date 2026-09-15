import 'package:flutter/material.dart';

import '../../../../core/error/app_exception.dart';
import '../../data/models/profile_model.dart';
import '../../data/models/update_profile_request.dart';
import '../../data/repositories/profile_repository.dart';

class ProfileViewModel extends ChangeNotifier {
  final ProfileRepository repository;

  ProfileViewModel({required this.repository});

  bool isLoading = false;

  bool isUploadingImage = false;

  String? error;

  Map<String, List<String>> fieldErrors = {};

  ProfileModel? profile;

  String? fieldError(String fieldName) {
    final requestedField = _normalizeFieldName(fieldName);

    for (final entry in fieldErrors.entries) {
      final backendField = _normalizeFieldName(entry.key);

      if (backendField == requestedField && entry.value.isNotEmpty) {
        return entry.value.first;
      }
    }

    return null;
  }

  Future<void> loadProfile() async {
    if (isLoading) {
      return;
    }

    isLoading = true;

    _clearErrors();

    notifyListeners();

    try {
      profile = await repository.getProfile();
    } catch (exception) {
      _setError(exception, fallback: 'Profil nije moguće učitati.');
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required DateTime dateOfBirth,
    required String location,
    required String preferredTherapistGender,
    required String preferredSessionType,
    required double? minimumPricePerSession,
    required double? maximumPricePerSession,
    required List<String> preferredLanguages,
  }) async {
    if (isLoading) {
      return false;
    }

    isLoading = true;

    _clearErrors();

    notifyListeners();

    try {
      profile = await repository.updateProfile(
        UpdateProfileRequest(
          firstName: firstName.trim(),
          lastName: lastName.trim(),
          phoneNumber: phoneNumber.trim(),
          dateOfBirth: dateOfBirth,
          location: location.trim(),
          preferredTherapistGender: preferredTherapistGender,
          preferredSessionType: preferredSessionType,
          minimumPricePerSession: minimumPricePerSession,
          maximumPricePerSession: maximumPricePerSession,
          preferredLanguages: preferredLanguages,
        ),
      );

      return true;
    } catch (exception) {
      _setError(exception, fallback: 'Promjene profila nije moguće sačuvati.');

      return false;
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  Future<bool> uploadProfileImage(String filePath) async {
    if (isUploadingImage) {
      return false;
    }

    isUploadingImage = true;

    _clearErrors();

    notifyListeners();

    try {
      profile = await repository.uploadProfileImage(filePath);

      return true;
    } catch (exception) {
      _setError(exception, fallback: 'Profilnu sliku nije moguće učitati.');

      return false;
    } finally {
      isUploadingImage = false;

      notifyListeners();
    }
  }

  void _clearErrors() {
    error = null;
    fieldErrors = {};
  }

  void _setError(Object exception, {required String fallback}) {
    if (exception is AppException) {
      error = exception.message.trim().isEmpty
          ? fallback
          : exception.message.trim();

      fieldErrors = Map<String, List<String>>.from(exception.fieldErrors);

      return;
    }

    final normalizedMessage = exception
        .toString()
        .replaceFirst('Exception: ', '')
        .trim();

    error = normalizedMessage.isEmpty ? fallback : normalizedMessage;
  }

  String _normalizeFieldName(String value) {
    var normalized = value
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toLowerCase();

    const prefixes = ['request', 'model', 'dto'];

    for (final prefix in prefixes) {
      if (normalized.startsWith(prefix)) {
        normalized = normalized.substring(prefix.length);
      }
    }

    return normalized;
  }
}
