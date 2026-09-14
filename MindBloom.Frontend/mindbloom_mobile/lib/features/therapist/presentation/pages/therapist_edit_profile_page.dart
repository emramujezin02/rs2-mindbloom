import 'dart:io';

import 'package:image_cropper/image_cropper.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/therapist_profile_availability_model.dart';
import '../../../../app/di/injection.dart';
import '../../../../core/constants/api_constants.dart';
import '../../data/models/therapist_profile_model.dart';
import '../viewmodels/therapist_profile_viewmodel.dart';

class TherapistEditProfilePage extends StatefulWidget {
  final TherapistProfileModel profile;

  const TherapistEditProfilePage({super.key, required this.profile});

  @override
  State<TherapistEditProfilePage> createState() =>
      _TherapistEditProfilePageState();
}

class _TherapistEditProfilePageState extends State<TherapistEditProfilePage> {
  final TherapistProfileViewModel _viewModel =
      AppInjection.createTherapistProfileViewModel();

  final ImagePicker _imagePicker = ImagePicker();
  final ImageCropper _imageCropper = ImageCropper();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  int _selectedDayOfWeek = 1;

  TimeOfDay _selectedStartTime = const TimeOfDay(hour: 9, minute: 0);

  TimeOfDay _selectedEndTime = const TimeOfDay(hour: 17, minute: 0);

  static const List<String> _dayNames = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  late final TextEditingController _biographyController;
  late final TextEditingController _specializationController;
  late final TextEditingController _experienceYearsController;
  late final TextEditingController _hourlyRateController;
  late final TextEditingController _locationController;
  late final TextEditingController _languageController;
  late final TextEditingController _countryController;
  late final TextEditingController _cityController;
  late final TextEditingController _addressController;

  final List<String> _languages = [];
  final Set<int> _selectedTherapyApproachIds = {};

  bool _offersOnline = false;
  bool _offersInPerson = false;

  File? _selectedImage;
  bool _profileImageDeleted = false;

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_refresh);

    _biographyController = TextEditingController(
      text: widget.profile.biography,
    );

    _specializationController = TextEditingController(
      text: widget.profile.specialization,
    );

    _experienceYearsController = TextEditingController(
      text: widget.profile.experienceYears.toString(),
    );

    _hourlyRateController = TextEditingController(
      text: widget.profile.hourlyRate.toStringAsFixed(2),
    );

    _locationController = TextEditingController(text: widget.profile.location);

    _countryController = TextEditingController(text: widget.profile.country);

    _cityController = TextEditingController(text: widget.profile.city);

    _addressController = TextEditingController(text: widget.profile.address);

    _offersOnline = widget.profile.offersOnline;
    _offersInPerson = widget.profile.offersInPerson;

    _selectedTherapyApproachIds.addAll(
      widget.profile.therapyApproaches
          .where((approach) => approach.id > 0)
          .map((approach) => approach.id),
    );

    _languageController = TextEditingController();

    _loadLanguages();

    _viewModel.loadTherapyApproaches();
  }

  void _loadLanguages() {
    _languages
      ..clear()
      ..addAll(
        widget.profile.languages
            .map((language) => language.trim())
            .where((language) => language.isNotEmpty),
      );
  }

  @override
  void dispose() {
    _viewModel.removeListener(_refresh);
    _viewModel.dispose();

    _biographyController.dispose();
    _specializationController.dispose();
    _experienceYearsController.dispose();
    _hourlyRateController.dispose();
    _locationController.dispose();
    _languageController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _addressController.dispose();

    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _selectProfileImage() async {
    if (_viewModel.isManagingProfileImage) {
      return;
    }

    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
      maxWidth: 2400,
      maxHeight: 2400,
    );

    if (image == null || !mounted) {
      return;
    }

    final croppedImage = await _imageCropper.cropImage(
      sourcePath: image.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      maxWidth: 1200,
      maxHeight: 1200,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop profile picture',
          toolbarColor: const Color(0xFF72559A),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFF72559A),
          cropStyle: CropStyle.circle,
          lockAspectRatio: true,
          hideBottomControls: false,
          initAspectRatio: CropAspectRatioPreset.square,
          aspectRatioPresets: const [CropAspectRatioPreset.square],
        ),
        IOSUiSettings(
          title: 'Crop profile picture',
          cropStyle: CropStyle.circle,
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
          aspectRatioPresets: const [CropAspectRatioPreset.square],
        ),
      ],
    );

    if (croppedImage == null || !mounted) {
      return;
    }

    setState(() {
      _selectedImage = File(croppedImage.path);

      _profileImageDeleted = false;
    });
  }

  Future<void> _uploadSelectedProfileImage() async {
    final selectedImage = _selectedImage;

    if (selectedImage == null || _viewModel.isManagingProfileImage) {
      return;
    }

    final success = await _viewModel.uploadProfileImage(selectedImage);

    if (!mounted) {
      return;
    }

    if (success) {
      setState(() {
        _selectedImage = null;
        _profileImageDeleted = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated successfully.')),
      );
    }
  }

  void _discardSelectedProfileImage() {
    if (_viewModel.isManagingProfileImage) {
      return;
    }

    setState(() {
      _selectedImage = null;
    });
  }

  Future<void> _deleteProfileImage() async {
    if (_viewModel.isManagingProfileImage) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete profile picture'),
          content: const Text(
            'Are you sure you want to delete your profile picture?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await _viewModel.deleteProfileImage();

    if (!mounted) {
      return;
    }

    if (success) {
      setState(() {
        _selectedImage = null;
        _profileImageDeleted = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture deleted successfully.')),
      );
    }
  }

  void _addLanguage() {
    final language = _languageController.text.trim();

    if (language.isEmpty) {
      return;
    }

    final alreadyExists = _languages.any(
      (existingLanguage) =>
          existingLanguage.toLowerCase() == language.toLowerCase(),
    );

    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This language has already been added.')),
      );

      return;
    }

    setState(() {
      _languages.add(language);
      _languageController.clear();
    });
  }

  void _removeLanguage(String language) {
    setState(() {
      _languages.remove(language);
    });
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_languages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one language.')),
      );

      return;
    }

    if (!_offersOnline && !_offersInPerson) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one session mode.')),
      );

      return;
    }

    if (_selectedTherapyApproachIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one therapy approach.')),
      );

      return;
    }

    final success = await _viewModel.saveProfile(
      biography: _biographyController.text.trim(),
      specialization: _specializationController.text.trim(),
      experienceYears: _experienceYearsController.text.trim(),
      hourlyRate: _hourlyRateController.text.trim(),
      location: _locationController.text.trim(),
      country: _countryController.text.trim(),
      city: _cityController.text.trim(),
      address: _addressController.text.trim(),
      offersOnline: _offersOnline,
      offersInPerson: _offersInPerson,
      languages: List<String>.from(_languages),
      therapyApproachIds: _selectedTherapyApproachIds.toList(),
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Therapist profile updated successfully.'),
        ),
      );

      Navigator.of(context).pop(true);
    }
  }

  Future<void> _selectStartTime() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _selectedStartTime,
    );

    if (selectedTime == null || !mounted) {
      return;
    }

    setState(() {
      _selectedStartTime = selectedTime;
    });
  }

  Future<void> _selectEndTime() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _selectedEndTime,
    );

    if (selectedTime == null || !mounted) {
      return;
    }

    setState(() {
      _selectedEndTime = selectedTime;
    });
  }

  String _formatTimeForApi(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');

    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute:00';
  }

  Future<void> _addAvailability() async {
    final success = await _viewModel.addAvailability(
      dayOfWeek: _selectedDayOfWeek,
      startTime: _formatTimeForApi(_selectedStartTime),
      endTime: _formatTimeForApi(_selectedEndTime),
    );

    if (!mounted) {
      return;
    }

    final message = success
        ? 'Availability added successfully.'
        : _viewModel.errorMessage ?? 'Availability could not be added.';

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _deleteAvailability(
    TherapistProfileAvailabilityModel availability,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete availability'),
          content: Text(
            'Delete ${availability.dayName}, '
            '${availability.formattedTime}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final success = await _viewModel.deleteAvailability(availability.id);

    if (!mounted) {
      return;
    }

    final message = success
        ? 'Availability deleted successfully.'
        : _viewModel.errorMessage ?? 'Availability could not be deleted.';

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _buildImageUrl(String? relativeUrl) {
    if (relativeUrl == null || relativeUrl.trim().isEmpty) {
      return null;
    }

    final value = relativeUrl.trim();

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    final baseUri = Uri.parse(ApiConstants.apiBaseUrl);
    final normalizedPath = value.startsWith('/') ? value : '/$value';

    return baseUri
        .replace(path: normalizedPath, query: null, fragment: null)
        .toString();
  }

  ImageProvider<Object>? _getProfileImage() {
    if (_selectedImage != null) {
      return FileImage(_selectedImage!);
    }

    if (_profileImageDeleted) {
      return null;
    }

    final uploadedImageUrl = _buildImageUrl(
      _viewModel.profile?.profileImageUrl,
    );

    if (uploadedImageUrl != null) {
      return NetworkImage(uploadedImageUrl);
    }

    final currentImageUrl = _buildImageUrl(widget.profile.profileImageUrl);

    if (currentImageUrl != null) {
      return NetworkImage(currentImageUrl);
    }

    return null;
  }

  String _buildProfileInitials() {
    final parts = [
      widget.profile.firstName.trim(),
      widget.profile.lastName.trim(),
    ].where((value) => value.isNotEmpty).toList();

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final profileImage = _getProfileImage();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F3FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Edit therapist profile',
          style: TextStyle(
            color: Color(0xFF40334D),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE7DDF0)),
                      ),
                      child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 58,
                                backgroundColor: const Color(0xFFEDE5FA),
                                backgroundImage: profileImage,
                                child: profileImage == null
                                    ? Text(
                                        _buildProfileInitials(),
                                        style: const TextStyle(
                                          color: Color(0xFF72559A),
                                          fontSize: 34,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      )
                                    : null,
                              ),
                              Positioned(
                                right: -5,
                                bottom: -5,
                                child: Material(
                                  elevation: 3,
                                  color: Colors.white,
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    tooltip: 'Change profile picture',
                                    onPressed: _viewModel.isManagingProfileImage
                                        ? null
                                        : _selectProfileImage,
                                    icon: _viewModel.isManagingProfileImage
                                        ? const SizedBox(
                                            width: 21,
                                            height: 21,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.camera_alt_outlined,
                                            color: Color(0xFF72559A),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          if (_selectedImage != null)
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                FilledButton.icon(
                                  onPressed: _viewModel.isManagingProfileImage
                                      ? null
                                      : _uploadSelectedProfileImage,
                                  icon: _viewModel.isUploadingImage
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.cloud_upload_outlined),
                                  label: Text(
                                    _viewModel.isUploadingImage
                                        ? 'Uploading...'
                                        : 'Upload picture',
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _viewModel.isManagingProfileImage
                                      ? null
                                      : _discardSelectedProfileImage,
                                  icon: const Icon(Icons.close),
                                  label: const Text('Cancel preview'),
                                ),
                              ],
                            )
                          else if (!_profileImageDeleted &&
                              (_viewModel.profile?.profileImageUrl
                                          ?.trim()
                                          .isNotEmpty ==
                                      true ||
                                  widget.profile.profileImageUrl
                                          ?.trim()
                                          .isNotEmpty ==
                                      true))
                            TextButton.icon(
                              onPressed: _viewModel.isManagingProfileImage
                                  ? null
                                  : _deleteProfileImage,
                              icon: _viewModel.isDeletingImage
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.delete_outline),
                              label: Text(
                                _viewModel.isDeletingImage
                                    ? 'Deleting...'
                                    : 'Delete profile picture',
                              ),
                            ),

                          const SizedBox(height: 18),
                          Text(
                            '${widget.profile.firstName} '
                            '${widget.profile.lastName}',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF40334D),
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            widget.profile.email,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF756D79)),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE7DDF0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Professional information',
                            style: TextStyle(
                              color: Color(0xFF40334D),
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Update the information visible to clients.',
                            style: TextStyle(color: Color(0xFF756D79)),
                          ),
                          const SizedBox(height: 22),

                          TextFormField(
                            controller: _specializationController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Specialization',
                              hintText: 'Example: Cognitive behavioral therapy',
                              prefixIcon: Icon(Icons.psychology_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final specialization = value?.trim() ?? '';

                              if (specialization.isEmpty) {
                                return 'Specialization is required.';
                              }

                              if (specialization.length < 2) {
                                return 'Specialization must contain at least 2 characters.';
                              }

                              if (specialization.length > 150) {
                                return 'Specialization may contain at most 150 characters.';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _biographyController,
                            minLines: 5,
                            maxLines: 9,
                            keyboardType: TextInputType.multiline,
                            decoration: const InputDecoration(
                              labelText: 'Biography',
                              hintText:
                                  'Introduce yourself, your experience and therapeutic approach.',
                              alignLabelWithHint: true,
                              prefixIcon: Padding(
                                padding: EdgeInsets.only(bottom: 95),
                                child: Icon(Icons.description_outlined),
                              ),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final biography = value?.trim() ?? '';

                              if (biography.isEmpty) {
                                return 'Biography is required.';
                              }

                              if (biography.length < 20) {
                                return 'Biography must contain at least 20 characters.';
                              }

                              if (biography.length > 2000) {
                                return 'Biography may contain at most 2000 characters.';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          LayoutBuilder(
                            builder: (context, constraints) {
                              final experienceField = TextFormField(
                                controller: _experienceYearsController,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Years of experience',
                                  hintText: 'Example: 5',
                                  prefixIcon: Icon(Icons.work_outline),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  final text = value?.trim() ?? '';

                                  if (text.isEmpty) {
                                    return 'Experience is required.';
                                  }

                                  final experience = int.tryParse(text);

                                  if (experience == null) {
                                    return 'Enter a valid whole number.';
                                  }

                                  if (experience < 0) {
                                    return 'Experience cannot be negative.';
                                  }

                                  if (experience > 70) {
                                    return 'Enter a realistic number of years.';
                                  }

                                  return null;
                                },
                              );

                              final hourlyRateField = TextFormField(
                                controller: _hourlyRateController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Hourly rate',
                                  hintText: 'Example: 60.00',
                                  suffixText: 'KM',
                                  prefixIcon: Icon(Icons.payments_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  final text =
                                      value?.trim().replaceAll(',', '.') ?? '';

                                  if (text.isEmpty) {
                                    return 'Hourly rate is required.';
                                  }

                                  final hourlyRate = double.tryParse(text);

                                  if (hourlyRate == null) {
                                    return 'Enter a valid hourly rate.';
                                  }

                                  if (hourlyRate <= 0) {
                                    return 'Hourly rate must be greater than 0.';
                                  }

                                  if (hourlyRate > 10000) {
                                    return 'Hourly rate is too high.';
                                  }

                                  return null;
                                },
                              );

                              if (constraints.maxWidth >= 600) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: experienceField),
                                    const SizedBox(width: 16),
                                    Expanded(child: hourlyRateField),
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  experienceField,
                                  const SizedBox(height: 16),
                                  hourlyRateField,
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _locationController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Location',
                              hintText:
                                  'Example: Sarajevo, Bosnia and Herzegovina',
                              prefixIcon: Icon(Icons.location_on_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final location = value?.trim() ?? '';

                              if (location.isEmpty) {
                                return 'Location is required.';
                              }

                              if (location.length < 2) {
                                return 'Location must contain at least 2 characters.';
                              }

                              if (location.length > 200) {
                                return 'Location may contain at most 200 characters.';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 24),

                          LayoutBuilder(
                            builder: (context, constraints) {
                              final countryField = TextFormField(
                                controller: _countryController,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Country',
                                  hintText: 'Example: Bosnia and Herzegovina',
                                  prefixIcon: Icon(Icons.public_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  final country = value?.trim() ?? '';

                                  if (country.isEmpty) {
                                    return 'Country is required.';
                                  }

                                  if (country.length > 100) {
                                    return 'Country may contain at most 100 characters.';
                                  }

                                  return null;
                                },
                              );

                              final cityField = TextFormField(
                                controller: _cityController,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'City',
                                  hintText: 'Example: Sarajevo',
                                  prefixIcon: Icon(
                                    Icons.location_city_outlined,
                                  ),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  final city = value?.trim() ?? '';

                                  if (city.isEmpty) {
                                    return 'City is required.';
                                  }

                                  if (city.length > 100) {
                                    return 'City may contain at most 100 characters.';
                                  }

                                  return null;
                                },
                              );

                              if (constraints.maxWidth >= 600) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: countryField),
                                    const SizedBox(width: 16),
                                    Expanded(child: cityField),
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  countryField,
                                  const SizedBox(height: 16),
                                  cityField,
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _addressController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Office address',
                              hintText: 'Street and number',
                              prefixIcon: Icon(Icons.home_work_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final address = value?.trim() ?? '';

                              if (_offersInPerson && address.isEmpty) {
                                return 'Address is required for in-person sessions.';
                              }

                              if (address.length > 250) {
                                return 'Address may contain at most 250 characters.';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 24),

                          const Text(
                            'Session modes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF40334D),
                            ),
                          ),

                          const SizedBox(height: 6),

                          const Text(
                            'Select how clients can attend sessions.',
                            style: TextStyle(color: Color(0xFF756D79)),
                          ),

                          const SizedBox(height: 12),

                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F3FB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE7DDF0),
                              ),
                            ),
                            child: Column(
                              children: [
                                SwitchListTile(
                                  value: _offersOnline,
                                  title: const Text(
                                    'Online sessions',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    'Clients can attend through an online meeting.',
                                  ),
                                  secondary: const Icon(
                                    Icons.videocam_outlined,
                                  ),
                                  onChanged: _viewModel.isSaving
                                      ? null
                                      : (value) {
                                          setState(() {
                                            _offersOnline = value;
                                          });
                                        },
                                ),
                                const Divider(height: 1),
                                SwitchListTile(
                                  value: _offersInPerson,
                                  title: const Text(
                                    'In-person sessions',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    'Clients can attend at the office address.',
                                  ),
                                  secondary: const Icon(Icons.people_outline),
                                  onChanged: _viewModel.isSaving
                                      ? null
                                      : (value) {
                                          setState(() {
                                            _offersInPerson = value;
                                          });

                                          _formKey.currentState?.validate();
                                        },
                                ),
                              ],
                            ),
                          ),

                          if (!_offersOnline && !_offersInPerson) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Select at least one session mode.',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ],

                          const SizedBox(height: 28),

                          _buildTherapyApproachesSection(),

                          const SizedBox(height: 28),

                          const Text(
                            'Languages',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF40334D),
                            ),
                          ),

                          const SizedBox(height: 12),

                          LayoutBuilder(
                            builder: (context, constraints) {
                              final languageField = TextFormField(
                                controller: _languageController,
                                textInputAction: TextInputAction.done,
                                decoration: const InputDecoration(
                                  hintText: 'Add language',
                                  border: OutlineInputBorder(),
                                ),
                                onFieldSubmitted: (_) => _addLanguage(),
                              );

                              final addButton = FilledButton.icon(
                                onPressed: _addLanguage,
                                icon: const Icon(Icons.add),
                                label: const Text('Add'),
                              );

                              if (constraints.maxWidth >= 420) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: languageField),
                                    const SizedBox(width: 12),
                                    addButton,
                                  ],
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  languageField,
                                  const SizedBox(height: 12),
                                  addButton,
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 16),

                          if (_languages.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F3FB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'No languages added.',
                                style: TextStyle(color: Color(0xFF756D79)),
                              ),
                            ),

                          if (_languages.isNotEmpty)
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _languages
                                  .map(
                                    (language) => Chip(
                                      label: Text(language),
                                      deleteIcon: const Icon(Icons.close),
                                      onDeleted: () =>
                                          _removeLanguage(language),
                                    ),
                                  )
                                  .toList(),
                            ),

                          const SizedBox(height: 28),

                          _buildAvailabilitySection(),

                          const SizedBox(height: 24),

                          const SizedBox(height: 24),

                          if (_viewModel.errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                _viewModel.errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),

                          if (_viewModel.successMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                _viewModel.successMessage!,
                                style: const TextStyle(color: Colors.green),
                              ),
                            ),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _viewModel.isSaving
                                  ? null
                                  : _saveProfile,
                              icon: _viewModel.isSaving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(
                                _viewModel.isSaving
                                    ? 'Saving...'
                                    : 'Save changes',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTherapyApproachesSection() {
    final approaches = _viewModel.availableTherapyApproaches;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Therapy approaches',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF40334D),
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Select the approaches you use in your therapeutic work.',
          style: TextStyle(color: Color(0xFF756D79), height: 1.4),
        ),

        const SizedBox(height: 14),

        if (_viewModel.isLoadingTherapyApproaches)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (approaches.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F3FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Therapy approaches could not be loaded.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF756D79)),
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: approaches.map((approach) {
              final isSelected = _selectedTherapyApproachIds.contains(
                approach.id,
              );

              return FilterChip(
                label: Text(approach.name),
                selected: isSelected,
                onSelected: _viewModel.isSaving
                    ? null
                    : (selected) {
                        setState(() {
                          if (selected) {
                            _selectedTherapyApproachIds.add(approach.id);
                          } else {
                            _selectedTherapyApproachIds.remove(approach.id);
                          }
                        });
                      },
              );
            }).toList(),
          ),

        if (_selectedTherapyApproachIds.isEmpty &&
            !_viewModel.isLoadingTherapyApproaches) ...[
          const SizedBox(height: 8),
          const Text(
            'Select at least one therapy approach.',
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildAvailabilitySection() {
    final profile = _viewModel.profile ?? widget.profile;

    final availabilities =
        List<TherapistProfileAvailabilityModel>.from(profile.availabilities)
          ..sort((first, second) {
            final dayComparison = first.dayOfWeek.compareTo(second.dayOfWeek);

            if (dayComparison != 0) {
              return dayComparison;
            }

            return first.startTime.compareTo(second.startTime);
          });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Availability',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF40334D),
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Add the weekly periods in which clients can book sessions.',
          style: TextStyle(color: Color(0xFF756D79), height: 1.4),
        ),

        const SizedBox(height: 18),

        DropdownButtonFormField<int>(
          initialValue: _selectedDayOfWeek,
          decoration: const InputDecoration(
            labelText: 'Day',
            prefixIcon: Icon(Icons.calendar_today_outlined),
            border: OutlineInputBorder(),
          ),
          items: List.generate(_dayNames.length, (index) {
            return DropdownMenuItem<int>(
              value: index,
              child: Text(_dayNames[index]),
            );
          }),
          onChanged: _viewModel.isManagingAvailability
              ? null
              : (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _selectedDayOfWeek = value;
                  });
                },
        ),

        const SizedBox(height: 14),

        LayoutBuilder(
          builder: (context, constraints) {
            final startTimeField = _AvailabilityTimeField(
              label: 'Start time',
              icon: Icons.access_time,
              value: _selectedStartTime.format(context),
              enabled: !_viewModel.isManagingAvailability,
              onTap: _selectStartTime,
            );

            final endTimeField = _AvailabilityTimeField(
              label: 'End time',
              icon: Icons.access_time_filled_outlined,
              value: _selectedEndTime.format(context),
              enabled: !_viewModel.isManagingAvailability,
              onTap: _selectEndTime,
            );

            if (constraints.maxWidth >= 420) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: startTimeField),
                  const SizedBox(width: 12),
                  Expanded(child: endTimeField),
                ],
              );
            }

            return Column(
              children: [
                startTimeField,
                const SizedBox(height: 12),
                endTimeField,
              ],
            );
          },
        ),

        const SizedBox(height: 14),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _viewModel.isManagingAvailability
                ? null
                : _addAvailability,
            icon: _viewModel.isManagingAvailability
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: const Text('Add availability'),
          ),
        ),

        const SizedBox(height: 20),

        if (availabilities.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F3FA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'No availability periods have been added.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF756D79)),
            ),
          )
        else
          ...availabilities.map((availability) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AvailabilitySlotCard(
                availability: availability,
                isDisabled: _viewModel.isManagingAvailability,
                onDelete: () => _deleteAvailability(availability),
              ),
            );
          }),
      ],
    );
  }
}

class _AvailabilityTimeField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final bool enabled;
  final VoidCallback onTap;

  const _AvailabilityTimeField({
    required this.label,
    required this.icon,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
          enabled: enabled,
        ),
        child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _AvailabilitySlotCard extends StatelessWidget {
  final TherapistProfileAvailabilityModel availability;
  final bool isDisabled;
  final VoidCallback onDelete;

  const _AvailabilitySlotCard({
    required this.availability,
    required this.isDisabled,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7DDF0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE5FA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.schedule, color: Color(0xFF72559A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  availability.dayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF40334D),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  availability.formattedTime,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF756D79)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: isDisabled
                ? 'Availability action in progress'
                : 'Delete availability',
            onPressed: isDisabled ? null : onDelete,
            icon: const Icon(Icons.delete_outline),
            color: Theme.of(context).colorScheme.error,
          ),
        ],
      ),
    );
  }
}
