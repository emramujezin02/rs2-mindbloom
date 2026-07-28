import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mindbloom_mobile/features/therapist/data/models/create_unavailable_date_request.dart';
import '../../data/models/create_therapist_availability_request.dart';
import '../../data/models/therapist_profile_model.dart';
import '../../data/models/update_therapist_profile_request.dart';
import '../../data/repositories/therapist_repository.dart';
import '../../../appointment/data/models/unavailable_date_model.dart';

class TherapistProfileViewModel extends ChangeNotifier {
  final TherapistRepository repository;

  TherapistProfileViewModel({required this.repository});

  TherapistProfileModel? _profile;
  List<UnavailableDateModel> _unavailableDates = [];

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  bool _isManagingAvailability = false;
  String? _errorMessage;
  String? _successMessage;

  TherapistProfileModel? get profile => _profile;

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  bool get isUploadingImage => _isUploadingImage;
  bool get isManagingAvailability => _isManagingAvailability;
  String? get errorMessage => _errorMessage;

  String? get successMessage => _successMessage;

  bool get hasProfile => _profile != null;

  bool get isBusy =>
      _isLoading || _isSaving || _isUploadingImage || _isManagingAvailability;

  Future<void> loadProfile() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;

    notifyListeners();

    try {
      _profile = await repository.getTherapistProfile();

      final currentProfile = _profile;

      if (currentProfile != null) {
        _unavailableDates = await repository.getUnavailableDates(
          currentProfile.therapistId,
        );
      }
    } catch (error) {
      _errorMessage = _resolveErrorMessage(
        error,
        fallback: 'Therapist profile could not be loaded.',
      );
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  Future<void> refreshProfile() async {
    _errorMessage = null;
    _successMessage = null;

    notifyListeners();

    try {
      _profile = await repository.getTherapistProfile();
    } catch (error) {
      _errorMessage = _resolveErrorMessage(
        error,
        fallback: 'Therapist profile could not be refreshed.',
      );
    } finally {
      notifyListeners();
    }
  }

  Future<bool> saveProfile({
    required String biography,
    required String specialization,
    required String experienceYears,
    required String hourlyRate,
    required String location,
    required List<String> languages,
  }) async {
    if (_isSaving) {
      return false;
    }

    _errorMessage = null;
    _successMessage = null;

    final validationMessage = _validateProfileInput(
      biography: biography,
      specialization: specialization,
      experienceYears: experienceYears,
      hourlyRate: hourlyRate,
      location: location,
      languages: languages,
    );

    if (validationMessage != null) {
      _errorMessage = validationMessage;

      notifyListeners();

      return false;
    }

    final parsedExperienceYears = int.parse(experienceYears.trim());

    final parsedHourlyRate = double.parse(
      hourlyRate.trim().replaceAll(',', '.'),
    );

    final normalizedLanguages = _normalizeLanguages(languages);

    final request = UpdateTherapistProfileRequest(
      biography: biography.trim(),
      specialization: specialization.trim(),
      experienceYears: parsedExperienceYears,
      hourlyRate: parsedHourlyRate,
      location: location.trim(),
      languages: normalizedLanguages,
    );

    _isSaving = true;

    notifyListeners();

    try {
      await repository.updateTherapistProfile(request);

      if (_profile != null) {
        _profile = _profile!.copyWith(
          biography: request.biography,
          specialization: request.specialization,
          experienceYears: request.experienceYears,
          hourlyRate: request.hourlyRate,
          location: request.location,
          languages: request.languages,
        );
      } else {
        _profile = await repository.getTherapistProfile();
      }

      _successMessage = 'Profile updated successfully.';

      return true;
    } catch (error) {
      _errorMessage = _resolveErrorMessage(
        error,
        fallback: 'Therapist profile could not be updated.',
      );

      return false;
    } finally {
      _isSaving = false;

      notifyListeners();
    }
  }

  Future<bool> uploadProfileImage(File file) async {
    if (_isUploadingImage) {
      return false;
    }

    _errorMessage = null;
    _successMessage = null;

    final validationMessage = _validateImage(file);

    if (validationMessage != null) {
      _errorMessage = validationMessage;

      notifyListeners();

      return false;
    }

    _isUploadingImage = true;

    notifyListeners();

    try {
      final result = await repository.uploadTherapistProfileImage(file);

      if (result.profileImageUrl.trim().isEmpty) {
        throw const FormatException(
          'The server did not return the profile image URL.',
        );
      }

      if (_profile != null) {
        _profile = _profile!.copyWith(profileImageUrl: result.profileImageUrl);
      } else {
        _profile = await repository.getTherapistProfile();
      }

      _successMessage = 'Profile image updated successfully.';

      return true;
    } catch (error) {
      _errorMessage = _resolveErrorMessage(
        error,
        fallback: 'Profile image could not be uploaded.',
      );

      return false;
    } finally {
      _isUploadingImage = false;

      notifyListeners();
    }
  }

  Future<bool> addAvailability({
    required int dayOfWeek,
    required String startTime,
    required String endTime,
  }) async {
    if (_isManagingAvailability) {
      return false;
    }

    _errorMessage = null;
    _successMessage = null;

    final validationMessage = _validateAvailability(
      dayOfWeek: dayOfWeek,
      startTime: startTime,
      endTime: endTime,
    );

    if (validationMessage != null) {
      _errorMessage = validationMessage;
      notifyListeners();

      return false;
    }

    final currentProfile = _profile;

    if (currentProfile == null) {
      _errorMessage = 'Therapist profile is not loaded.';
      notifyListeners();

      return false;
    }

    final request = CreateTherapistAvailabilityRequest(
      dayOfWeek: dayOfWeek,
      startTime: startTime,
      endTime: endTime,
    );

    _isManagingAvailability = true;
    notifyListeners();

    try {
      await repository.addTherapistAvailability(request: request);

      _profile = await repository.getTherapistProfile();

      _successMessage = 'Availability added successfully.';

      return true;
    } catch (error) {
      _errorMessage = _resolveErrorMessage(
        error,
        fallback: 'Availability could not be added.',
      );

      return false;
    } finally {
      _isManagingAvailability = false;
      notifyListeners();
    }
  }

  Future<bool> addUnavailablePeriod({
    required DateTime start,
    required DateTime end,
    required String reason,
  }) async {
    if (_isManagingAvailability) {
      return false;
    }

    _errorMessage = null;
    _successMessage = null;

    final normalizedReason = reason.trim();

    if (normalizedReason.isEmpty) {
      _errorMessage = 'Unavailable period type is required.';
      notifyListeners();

      return false;
    }

    if (!start.isBefore(end)) {
      _errorMessage = 'The unavailable period must end after it starts.';
      notifyListeners();

      return false;
    }

    if (start.isBefore(DateTime.now())) {
      _errorMessage = 'The unavailable period cannot start in the past.';
      notifyListeners();

      return false;
    }

    final overlaps = _unavailableDates.any((item) {
      final existingStart = item.startUtc.toLocal();
      final existingEnd = item.endUtc.toLocal();

      return start.isBefore(existingEnd) && end.isAfter(existingStart);
    });

    if (overlaps) {
      _errorMessage = 'This unavailable period overlaps an existing period.';
      notifyListeners();

      return false;
    }

    _isManagingAvailability = true;
    notifyListeners();

    try {
      await repository.addUnavailableDate(
        CreateUnavailableDateRequest(
          startUtc: start.toUtc(),
          endUtc: end.toUtc(),
          reason: normalizedReason,
        ),
      );

      final currentProfile = _profile;

      if (currentProfile != null) {
        _unavailableDates = await repository.getUnavailableDates(
          currentProfile.therapistId,
        );
      }

      _successMessage = 'Unavailable period added successfully.';

      return true;
    } catch (error) {
      _errorMessage = _resolveErrorMessage(
        error,
        fallback: 'Unavailable period could not be added.',
      );

      return false;
    } finally {
      _isManagingAvailability = false;
      notifyListeners();
    }
  }

  Future<bool> deleteUnavailablePeriod(int unavailableDateId) async {
    if (_isManagingAvailability) {
      return false;
    }

    if (unavailableDateId <= 0) {
      _errorMessage = 'Invalid unavailable period identifier.';
      notifyListeners();

      return false;
    }

    _errorMessage = null;
    _successMessage = null;
    _isManagingAvailability = true;

    notifyListeners();

    try {
      await repository.deleteUnavailableDate(unavailableDateId);

      _unavailableDates = _unavailableDates
          .where((item) => item.id != unavailableDateId)
          .toList();

      _successMessage = 'Unavailable period deleted successfully.';

      return true;
    } catch (error) {
      _errorMessage = _resolveErrorMessage(
        error,
        fallback: 'Unavailable period could not be deleted.',
      );

      return false;
    } finally {
      _isManagingAvailability = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAvailability(int availabilityId) async {
    if (_isManagingAvailability) {
      return false;
    }

    if (availabilityId <= 0) {
      _errorMessage = 'Invalid availability identifier.';
      notifyListeners();

      return false;
    }

    _errorMessage = null;
    _successMessage = null;
    _isManagingAvailability = true;

    notifyListeners();

    try {
      await repository.deleteTherapistAvailability(availabilityId);

      if (_profile != null) {
        final updatedAvailabilities = _profile!.availabilities
            .where((availability) => availability.id != availabilityId)
            .toList();

        _profile = _profile!.copyWith(availabilities: updatedAvailabilities);
      }

      _successMessage = 'Availability deleted successfully.';

      return true;
    } catch (error) {
      _errorMessage = _resolveErrorMessage(
        error,
        fallback: 'Availability could not be deleted.',
      );

      return false;
    } finally {
      _isManagingAvailability = false;
      notifyListeners();
    }
  }

  void clearErrorMessage() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;

    notifyListeners();
  }

  void clearSuccessMessage() {
    if (_successMessage == null) {
      return;
    }

    _successMessage = null;

    notifyListeners();
  }

  void clearMessages() {
    final hadMessage = _errorMessage != null || _successMessage != null;

    _errorMessage = null;
    _successMessage = null;

    if (hadMessage) {
      notifyListeners();
    }
  }

  String? _validateProfileInput({
    required String biography,
    required String specialization,
    required String experienceYears,
    required String hourlyRate,
    required String location,
    required List<String> languages,
  }) {
    final normalizedBiography = biography.trim();

    final normalizedSpecialization = specialization.trim();

    final normalizedLocation = location.trim();

    if (normalizedBiography.isEmpty) {
      return 'Biography is required.';
    }

    if (normalizedBiography.length > 2000) {
      return 'Biography cannot contain more than 2000 characters.';
    }

    if (normalizedSpecialization.isEmpty) {
      return 'Specialization is required.';
    }

    if (normalizedSpecialization.length > 150) {
      return 'Specialization cannot contain more than 150 characters.';
    }

    final parsedExperienceYears = int.tryParse(experienceYears.trim());

    if (parsedExperienceYears == null) {
      return 'Enter a valid number of experience years.';
    }

    if (parsedExperienceYears < 0 || parsedExperienceYears > 70) {
      return 'Experience must be between 0 and 70 years.';
    }

    final normalizedHourlyRate = hourlyRate.trim().replaceAll(',', '.');

    final parsedHourlyRate = double.tryParse(normalizedHourlyRate);

    if (parsedHourlyRate == null) {
      return 'Enter a valid hourly rate.';
    }

    if (parsedHourlyRate <= 0 || parsedHourlyRate > 10000) {
      return 'Hourly rate must be greater than zero and cannot exceed 10000.';
    }

    if (normalizedLocation.isEmpty) {
      return 'Location is required.';
    }

    if (normalizedLocation.length > 200) {
      return 'Location cannot contain more than 200 characters.';
    }

    final normalizedLanguages = _normalizeLanguages(languages);

    if (normalizedLanguages.isEmpty) {
      return 'Add at least one language.';
    }

    if (normalizedLanguages.any((language) => language.length > 100)) {
      return 'A language cannot contain more than 100 characters.';
    }

    final serializedLanguages = normalizedLanguages.join(',');

    if (serializedLanguages.length > 1000) {
      return 'The complete language list is too long.';
    }

    return null;
  }

  String? _validateAvailability({
    required int dayOfWeek,
    required String startTime,
    required String endTime,
  }) {
    if (dayOfWeek < 0 || dayOfWeek > 6) {
      return 'Select a valid day.';
    }

    final normalizedStartTime = startTime.trim();

    final normalizedEndTime = endTime.trim();

    if (normalizedStartTime.isEmpty) {
      return 'Start time is required.';
    }

    if (normalizedEndTime.isEmpty) {
      return 'End time is required.';
    }

    final startMinutes = _timeToMinutes(normalizedStartTime);

    final endMinutes = _timeToMinutes(normalizedEndTime);

    if (startMinutes == null || endMinutes == null) {
      return 'Enter a valid time.';
    }

    if (startMinutes >= endMinutes) {
      return 'End time must be after start time.';
    }

    final overlaps =
        _profile?.availabilities.any((availability) {
          if (availability.dayOfWeek != dayOfWeek) {
            return false;
          }

          final existingStart = _timeToMinutes(availability.startTime);

          final existingEnd = _timeToMinutes(availability.endTime);

          if (existingStart == null || existingEnd == null) {
            return false;
          }

          return startMinutes < existingEnd && endMinutes > existingStart;
        }) ??
        false;

    if (overlaps) {
      return 'This period overlaps with an existing availability.';
    }

    return null;
  }

  int? _timeToMinutes(String value) {
    final parts = value.trim().split(':');

    if (parts.length < 2) {
      return null;
    }

    final hours = int.tryParse(parts[0]);

    final minutes = int.tryParse(parts[1]);

    if (hours == null || minutes == null) {
      return null;
    }

    if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) {
      return null;
    }

    return hours * 60 + minutes;
  }

  String? _validateImage(File file) {
    if (!file.existsSync()) {
      return 'Selected image does not exist.';
    }

    final fileLength = file.lengthSync();

    if (fileLength <= 0) {
      return 'Selected image is empty.';
    }

    const maximumFileSize = 5 * 1024 * 1024;

    if (fileLength > maximumFileSize) {
      return 'Profile image cannot be larger than 5 MB.';
    }

    final extension = _fileExtension(file.path);

    const allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

    if (!allowedExtensions.contains(extension)) {
      return 'Only JPG, PNG and WEBP images are allowed.';
    }

    return null;
  }

  List<String> _normalizeLanguages(List<String> languages) {
    final uniqueLanguages = <String, String>{};

    for (final language in languages) {
      final normalized = language.trim();

      if (normalized.isEmpty) {
        continue;
      }

      final key = normalized.toLowerCase();

      uniqueLanguages[key] = normalized;
    }

    return uniqueLanguages.values.toList();
  }

  String _fileExtension(String path) {
    final normalizedPath = path.trim().toLowerCase();

    final lastDotIndex = normalizedPath.lastIndexOf('.');

    if (lastDotIndex == -1 || lastDotIndex == normalizedPath.length - 1) {
      return '';
    }

    return normalizedPath.substring(lastDotIndex + 1);
  }

  String _resolveErrorMessage(Object error, {required String fallback}) {
    final message = error.toString().trim();

    if (message.isEmpty) {
      return fallback;
    }

    var cleanedMessage = message;

    const removablePrefixes = [
      'Exception: ',
      'FormatException: ',
      'StateError: ',
    ];

    for (final prefix in removablePrefixes) {
      if (cleanedMessage.startsWith(prefix)) {
        cleanedMessage = cleanedMessage.substring(prefix.length);
      }
    }

    if (cleanedMessage.trim().isEmpty) {
      return fallback;
    }

    return cleanedMessage.trim();
  }

  List<UnavailableDateModel> get unavailableDates {
    final result = [..._unavailableDates]
      ..sort((first, second) => first.startUtc.compareTo(second.startUtc));

    return result;
  }
}
