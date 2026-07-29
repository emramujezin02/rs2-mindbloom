import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mindbloom_mobile/features/therapist/data/models/create_unavailable_date_request.dart';
import '../../data/models/create_therapist_availability_request.dart';
import '../../data/models/therapist_profile_model.dart';
import '../../data/models/update_therapist_profile_request.dart';
import '../../data/repositories/therapist_repository.dart';
import '../../../appointment/data/models/unavailable_date_model.dart';
import '../../../therapy_approach/data/models/therapy_approach_model.dart';
import '../../../therapy_approach/data/repositories/therapy_approach_repository.dart';

class TherapistProfileViewModel extends ChangeNotifier {
  final TherapistRepository repository;
  final TherapyApproachRepository therapyApproachRepository;

  TherapistProfileViewModel({
    required this.repository,
    required this.therapyApproachRepository,
  });

  TherapistProfileModel? _profile;
  List<TherapyApproachModel> _availableTherapyApproaches = [];
  List<UnavailableDateModel> _unavailableDates = [];

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  bool _isDeletingImage = false;
  bool _isManagingAvailability = false;
  bool _isLoadingTherapyApproaches = false;
  String? _errorMessage;
  String? _successMessage;

  TherapistProfileModel? get profile => _profile;
  List<TherapyApproachModel> get availableTherapyApproaches =>
      List.unmodifiable(_availableTherapyApproaches);

  bool get isLoadingTherapyApproaches => _isLoadingTherapyApproaches;

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  bool get isUploadingImage => _isUploadingImage;
  bool get isDeletingImage => _isDeletingImage;

  bool get isManagingProfileImage => _isUploadingImage || _isDeletingImage;

  bool get isManagingAvailability => _isManagingAvailability;
  String? get errorMessage => _errorMessage;

  String? get successMessage => _successMessage;

  bool get hasProfile => _profile != null;

  bool get isBusy =>
      _isLoading ||
      _isSaving ||
      _isUploadingImage ||
      _isDeletingImage ||
      _isManagingAvailability;

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

  Future<void> loadTherapyApproaches() async {
    if (_isLoadingTherapyApproaches) {
      return;
    }

    _isLoadingTherapyApproaches = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final approaches = await therapyApproachRepository
          .getPublicTherapyApproaches();

      _availableTherapyApproaches =
          approaches
              .where(
                (approach) =>
                    approach.id > 0 &&
                    approach.name.trim().isNotEmpty &&
                    approach.isActive,
              )
              .toList()
            ..sort(
              (first, second) =>
                  first.name.toLowerCase().compareTo(second.name.toLowerCase()),
            );
    } catch (error) {
      _errorMessage = _resolveErrorMessage(
        error,
        fallback: 'Therapy approaches could not be loaded.',
      );
    } finally {
      _isLoadingTherapyApproaches = false;

      notifyListeners();
    }
  }

  Future<bool> saveProfile({
    required String biography,
    required String specialization,
    required String experienceYears,
    required String hourlyRate,
    required String location,
    required String country,
    required String city,
    required String address,
    required bool offersOnline,
    required bool offersInPerson,
    required List<String> languages,
    required List<int> therapyApproachIds,
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
      country: country,
      city: city,
      address: address,
      offersOnline: offersOnline,
      offersInPerson: offersInPerson,
      languages: languages,
      therapyApproachIds: therapyApproachIds,
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

    final normalizedTherapyApproachIds = therapyApproachIds
        .where((id) => id > 0)
        .toSet()
        .toList();

    final request = UpdateTherapistProfileRequest(
      biography: biography.trim(),
      specialization: specialization.trim(),
      experienceYears: parsedExperienceYears,
      hourlyRate: parsedHourlyRate,
      location: location.trim(),
      country: country.trim(),
      city: city.trim(),
      address: address.trim(),
      offersOnline: offersOnline,
      offersInPerson: offersInPerson,
      languages: normalizedLanguages,
      therapyApproachIds: normalizedTherapyApproachIds,
    );

    _isSaving = true;

    notifyListeners();

    try {
      await repository.updateTherapistProfile(request);

      /*
     * Ponovo učitavamo profil jer backend:
     * - ažurira koordinate
     * - vraća terapijske pravce sa nazivima
     * - normalizuje podatke
     */
      _profile = await repository.getTherapistProfile();

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

  Future<bool> deleteProfileImage() async {
    if (_isUploadingImage || _isDeletingImage) {
      return false;
    }

    _errorMessage = null;
    _successMessage = null;
    _isDeletingImage = true;

    notifyListeners();

    try {
      await repository.deleteTherapistProfileImage();

      /*
     * Profil se ponovo učitava jer obični copyWith
     * trenutno ne može postaviti nullable URL na null.
     */
      _profile = await repository.getTherapistProfile();

      _successMessage = 'Profile image deleted successfully.';

      return true;
    } catch (error) {
      _errorMessage = _resolveErrorMessage(
        error,
        fallback: 'Profile image could not be deleted.',
      );

      return false;
    } finally {
      _isDeletingImage = false;

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
    required String country,
    required String city,
    required String address,
    required bool offersOnline,
    required bool offersInPerson,
    required List<String> languages,
    required List<int> therapyApproachIds,
  }) {
    final normalizedBiography = biography.trim();

    final normalizedSpecialization = specialization.trim();

    final normalizedLocation = location.trim();

    final normalizedCountry = country.trim();

    final normalizedCity = city.trim();

    final normalizedAddress = address.trim();

    if (normalizedBiography.isEmpty) {
      return 'Biography is required.';
    }

    if (normalizedBiography.length > 2000) {
      return 'Biography cannot contain more than 2000 characters.';
    }

    if (normalizedSpecialization.isEmpty) {
      return 'Specialization is required.';
    }

    if (normalizedSpecialization.length > 200) {
      return 'Specialization cannot contain more than 200 characters.';
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

    if (normalizedCountry.isEmpty) {
      return 'Country is required.';
    }

    if (normalizedCountry.length > 100) {
      return 'Country cannot contain more than 100 characters.';
    }

    if (normalizedCity.isEmpty) {
      return 'City is required.';
    }

    if (normalizedCity.length > 100) {
      return 'City cannot contain more than 100 characters.';
    }

    if (normalizedAddress.length > 250) {
      return 'Address cannot contain more than 250 characters.';
    }

    if (offersInPerson && normalizedAddress.isEmpty) {
      return 'Address is required for in-person appointments.';
    }

    if (!offersOnline && !offersInPerson) {
      return 'Select at least one session mode.';
    }

    final normalizedLanguages = _normalizeLanguages(languages);

    if (normalizedLanguages.isEmpty) {
      return 'Add at least one language.';
    }

    if (normalizedLanguages.length > 20) {
      return 'You may add at most 20 languages.';
    }

    if (normalizedLanguages.any((language) => language.length > 100)) {
      return 'A language cannot contain more than 100 characters.';
    }

    final normalizedApproachIds = therapyApproachIds
        .where((id) => id > 0)
        .toSet()
        .toList();

    if (normalizedApproachIds.isEmpty) {
      return 'Select at least one therapy approach.';
    }

    if (normalizedApproachIds.length > 20) {
      return 'You may select at most 20 therapy approaches.';
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
