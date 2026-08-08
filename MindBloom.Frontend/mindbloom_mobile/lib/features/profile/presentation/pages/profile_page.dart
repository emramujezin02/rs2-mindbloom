import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../therapist/data/models/therapist_profile_model.dart';
import '../../../therapist/presentation/viewmodels/therapist_profile_viewmodel.dart';
import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/constants/api_constants.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../../data/models/profile_model.dart';
import '../../../session/presentation/viewmodels/session_scope.dart';
import 'package:intl/intl.dart';
import '../../../appointment/data/models/unavailable_date_model.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileViewModel _viewModel = AppInjection.createProfileViewModel();
  final TherapistProfileViewModel _therapistProfileViewModel =
      AppInjection.createTherapistProfileViewModel();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_refresh);
    _therapistProfileViewModel.addListener(_refresh);

    _viewModel.loadProfile();
    _therapistProfileViewModel.loadProfile();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_refresh);
    _therapistProfileViewModel.removeListener(_refresh);

    _viewModel.dispose();
    _therapistProfileViewModel.dispose();

    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openEditProfile() async {
    final result = await Navigator.of(
      context,
    ).pushNamed(AppRouter.editProfile, arguments: _viewModel.profile);

    if (!mounted) {
      return;
    }

    if (result == true) {
      await _viewModel.loadProfile();
    }
  }

  Future<void> _openTherapistEditProfile() async {
    final therapistProfile = _therapistProfileViewModel.profile;

    if (therapistProfile == null) {
      return;
    }

    final result = await Navigator.of(
      context,
    ).pushNamed(AppRouter.therapistEditProfile, arguments: therapistProfile);

    if (!mounted) {
      return;
    }

    if (result == true) {
      await _therapistProfileViewModel.loadProfile();
    }
  }

  Future<void> _selectProfileImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );

    if (image == null || !mounted) {
      return;
    }

    final success = await _viewModel.uploadProfileImage(image.path);

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated successfully.')),
      );
    }
  }

  String _formatPriceRange(ProfileModel profile) {
    final minimum = profile.minimumPricePerSession;

    final maximum = profile.maximumPricePerSession;

    if (minimum == null && maximum == null) {
      return 'No preference';
    }

    if (minimum != null && maximum != null) {
      return '${minimum.toStringAsFixed(2)} - '
          '${maximum.toStringAsFixed(2)} BAM';
    }

    if (minimum != null) {
      return 'From '
          '${minimum.toStringAsFixed(2)} BAM';
    }

    return 'Up to '
        '${maximum!.toStringAsFixed(2)} BAM';
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

  Future<void> _deleteAccount() async {
    final passwordController = TextEditingController();

    var obscurePassword = true;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Delete account'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'This action is permanent. '
                        'Your private account data will be deleted '
                        'or anonymized and you will no longer be '
                        'able to sign in.',
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'Financial and audit records that must '
                        'remain for system integrity may be '
                        'retained in anonymized form.',
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'If you have pending or accepted '
                        'appointments, cancel them before '
                        'deleting your account.',
                      ),

                      const SizedBox(height: 20),

                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        autofocus: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: 'Current password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () {
                              setDialogState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text('Cancel'),
                ),

                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  onPressed: () {
                    if (passwordController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Enter your current password.'),
                        ),
                      );

                      return;
                    }

                    Navigator.of(dialogContext).pop(true);
                  },
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Delete account'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) {
      passwordController.dispose();

      return;
    }

    /*
   * Važno:
   * ne trimujemo stvarnu lozinku.
   */
    final password = passwordController.text;

    passwordController.dispose();

    final authViewModel = AppInjection.createAuthViewModel();

    try {
      final success = await authViewModel.deleteAccount(password: password);

      if (!mounted) {
        return;
      }

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              authViewModel.errorMessage ?? 'Account could not be deleted.',
            ),
          ),
        );

        return;
      }

      /*
     * AuthRepository je nakon uspješnog
     * backend deletiona uklonio lokalne
     * tokene.
     *
     * Uklanjamo cijeli navigation stack
     * kako se korisnik ne bi mogao vratiti
     * Back dugmetom na privatne ekrane.
     */
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
    } finally {
      authViewModel.dispose();
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Log out'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final session = SessionScope.of(context);

    await session.logout();

    if (!mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
  }

  Future<void> _showAddAvailabilityDialog() async {
    int selectedDay = DateTime.monday;

    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);

    TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add working hours'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: selectedDay,
                      decoration: const InputDecoration(
                        labelText: 'Working day',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: DateTime.monday,
                          child: Text('Monday'),
                        ),
                        DropdownMenuItem(
                          value: DateTime.tuesday,
                          child: Text('Tuesday'),
                        ),
                        DropdownMenuItem(
                          value: DateTime.wednesday,
                          child: Text('Wednesday'),
                        ),
                        DropdownMenuItem(
                          value: DateTime.thursday,
                          child: Text('Thursday'),
                        ),
                        DropdownMenuItem(
                          value: DateTime.friday,
                          child: Text('Friday'),
                        ),
                        DropdownMenuItem(
                          value: DateTime.saturday,
                          child: Text('Saturday'),
                        ),
                        DropdownMenuItem(
                          value: DateTime.sunday,
                          child: Text('Sunday'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedDay = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule_outlined),
                      title: const Text('Start time'),
                      subtitle: Text(startTime.format(dialogContext)),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: dialogContext,
                          initialTime: startTime,
                        );

                        if (picked != null) {
                          setDialogState(() {
                            startTime = picked;
                          });
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule_outlined),
                      title: const Text('End time'),
                      subtitle: Text(endTime.format(dialogContext)),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: dialogContext,
                          initialTime: endTime,
                        );

                        if (picked != null) {
                          setDialogState(() {
                            endTime = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'To create a break, add two separate working intervals '
                      'for the same day, for example 09:00–12:00 and 13:00–17:00.',
                    ),
                  ],
                ),
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
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || !mounted) {
      return;
    }

    final success = await _therapistProfileViewModel.addAvailability(
      dayOfWeek: selectedDay == DateTime.sunday ? 0 : selectedDay,
      startTime: _formatApiTime(startTime),
      endTime: _formatApiTime(endTime),
    );

    if (!mounted) {
      return;
    }

    _showTherapistResultMessage(success);
  }

  @override
  Widget build(BuildContext context) {
    if (_viewModel.isLoading && _viewModel.profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_viewModel.error != null && _viewModel.profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My profile')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _viewModel.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      );
    }

    final profile = _viewModel.profile;

    if (profile == null) {
      return const Scaffold(
        body: Center(child: Text('Unable to load profile.')),
      );
    }

    final imageUrl = _buildImageUrl(profile.profileImageUrl);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My profile'),
        actions: [
          IconButton(onPressed: _openEditProfile, icon: const Icon(Icons.edit)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _viewModel.loadProfile(),
            _therapistProfileViewModel.loadProfile(),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundImage: imageUrl != null
                        ? NetworkImage(imageUrl)
                        : null,
                    child: imageUrl == null
                        ? const Icon(Icons.person, size: 52)
                        : null,
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Material(
                      shape: const CircleBorder(),
                      elevation: 3,
                      child: IconButton(
                        onPressed: _viewModel.isUploadingImage
                            ? null
                            : _selectProfileImage,
                        tooltip: 'Change profile picture',
                        icon: _viewModel.isUploadingImage
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.camera_alt),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Name'),
              subtitle: Text(
                '${profile.firstName} '
                '${profile.lastName}',
              ),
            ),

            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Email'),
              subtitle: Text(profile.email),
            ),

            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Phone'),
              subtitle: Text(
                profile.phoneNumber.isEmpty ? 'Not added' : profile.phoneNumber,
              ),
            ),

            if (profile.dateOfBirth != null)
              ListTile(
                leading: const Icon(Icons.cake),
                title: const Text('Date of birth'),
                subtitle: Text(
                  '${profile.dateOfBirth!.day.toString().padLeft(2, '0')}.'
                  '${profile.dateOfBirth!.month.toString().padLeft(2, '0')}.'
                  '${profile.dateOfBirth!.year}.',
                ),
              ),

            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Therapy preferences',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.location_on_outlined),
                      title: const Text('Location'),
                      subtitle: Text(
                        profile.location == null ||
                                profile.location!.trim().isEmpty
                            ? 'Not added'
                            : profile.location!,
                      ),
                    ),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_search_outlined),
                      title: const Text('Preferred therapist gender'),
                      subtitle: Text(
                        profile.preferredTherapistGender == null ||
                                profile.preferredTherapistGender!
                                        .toLowerCase() ==
                                    'any'
                            ? 'No preference'
                            : profile.preferredTherapistGender!,
                      ),
                    ),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.video_call_outlined),
                      title: const Text('Preferred session type'),
                      subtitle: Text(
                        profile.preferredSessionType == null ||
                                profile.preferredSessionType!.toLowerCase() ==
                                    'any'
                            ? 'No preference'
                            : profile.preferredSessionType == 'InPerson'
                            ? 'In person'
                            : profile.preferredSessionType!,
                      ),
                    ),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.payments_outlined),
                      title: const Text('Preferred price range'),
                      subtitle: Text(_formatPriceRange(profile)),
                    ),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.language),
                      title: const Text('Preferred languages'),
                      subtitle: Text(
                        profile.preferredLanguages.isEmpty
                            ? 'No preference'
                            : profile.preferredLanguages.join(', '),
                      ),
                    ),

                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.of(
                            context,
                          ).pushNamed(AppRouter.onboarding);

                          if (!mounted) {
                            return;
                          }

                          if (result == true) {
                            await _viewModel.loadProfile();
                          }
                        },
                        icon: const Icon(Icons.tune),
                        label: const Text('Edit recommendation preferences'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_therapistProfileViewModel.profile != null) ...[
              const SizedBox(height: 20),

              _buildTherapistProfileSection(
                _therapistProfileViewModel.profile!,
              ),
            ],

            if (_viewModel.error != null) ...[
              const SizedBox(height: 12),
              Text(
                _viewModel.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ],

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRouter.changePassword);
                },
                icon: const Icon(Icons.lock_reset),
                label: const Text('Change password'),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRouter.twoFactorSettings);
                },
                icon: const Icon(Icons.security),
                label: const Text('Two-factor authentication'),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRouter.privacyConsents);
                },
                icon: const Icon(Icons.privacy_tip_outlined),
                label: const Text('Privacy & consents'),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRouter.myReviews);
                },
                icon: const Icon(Icons.reviews),
                label: const Text('My reviews'),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                ),
                onPressed: _deleteAccount,
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Delete account'),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTherapistProfileSection(TherapistProfileModel therapistProfile) {
    final languages = therapistProfile.languages
        .map((language) => language.trim())
        .where((language) => language.isNotEmpty)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7DDF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Professional profile',
                  style: TextStyle(
                    color: Color(0xFF40334D),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Edit professional profile',
                onPressed: _openTherapistEditProfile,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildTherapistInfoRow(
            icon: Icons.psychology_outlined,
            title: 'Specialization',
            value: therapistProfile.specialization,
          ),

          _buildTherapistInfoRow(
            icon: Icons.work_outline,
            title: 'Experience',
            value: '${therapistProfile.experienceYears} years',
          ),

          _buildTherapistInfoRow(
            icon: Icons.payments_outlined,
            title: 'Hourly rate',
            value: '${therapistProfile.hourlyRate.toStringAsFixed(2)} KM',
          ),

          _buildTherapistInfoRow(
            icon: Icons.location_on_outlined,
            title: 'Location',
            value: therapistProfile.location,
          ),

          if (therapistProfile.biography.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Biography',
              style: TextStyle(
                color: Color(0xFF40334D),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              therapistProfile.biography.trim(),
              style: const TextStyle(color: Color(0xFF68616D), height: 1.5),
            ),
          ],

          if (languages.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'Languages',
              style: TextStyle(
                color: Color(0xFF40334D),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: languages
                  .map((language) => Chip(label: Text(language)))
                  .toList(),
            ),
          ],

          const SizedBox(height: 24),

          const Divider(),

          const SizedBox(height: 18),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Working hours',
                  style: TextStyle(
                    color: Color(0xFF40334D),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _therapistProfileViewModel.isManagingAvailability
                    ? null
                    : _showAddAvailabilityDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (therapistProfile.availabilities.isEmpty)
            const Text(
              'No working hours have been added.',
              style: TextStyle(color: Color(0xFF756D79)),
            )
          else
            ...therapistProfile.availabilities.map(
              (availability) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.schedule_outlined),
                  title: Text(availability.dayName),
                  subtitle: Text(availability.formattedTime),
                  trailing: IconButton(
                    tooltip: 'Delete working hours',
                    onPressed: _therapistProfileViewModel.isManagingAvailability
                        ? null
                        : () {
                            _deleteAvailability(availability.id);
                          },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 24),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Unavailable periods',
                  style: TextStyle(
                    color: Color(0xFF40334D),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _therapistProfileViewModel.isManagingAvailability
                    ? null
                    : _showAddUnavailablePeriodDialog,
                icon: const Icon(Icons.block_outlined),
                label: const Text('Add'),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (_therapistProfileViewModel.unavailableDates.isEmpty)
            const Text(
              'No breaks, blocked times or leave periods have been added.',
              style: TextStyle(color: Color(0xFF756D79)),
            )
          else
            ..._therapistProfileViewModel.unavailableDates.map(
              _buildUnavailablePeriodCard,
            ),
        ],
      ),
    );
  }

  Widget _buildTherapistInfoRow({
    required IconData icon,
    required String title,
    required String? value,
  }) {
    final normalizedValue = value?.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF72559A)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF40334D),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  normalizedValue == null || normalizedValue.isEmpty
                      ? 'Not added'
                      : normalizedValue,
                  style: const TextStyle(color: Color(0xFF756D79)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatApiTime(TimeOfDay value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}:00';
  }

  Future<void> _showAddUnavailablePeriodDialog() async {
    const reasons = [
      'Break',
      'Blocked time',
      'Annual leave',
      'Temporarily unavailable',
    ];

    var selectedReason = reasons.first;

    var start = DateTime.now().add(const Duration(hours: 1));

    var end = start.add(const Duration(hours: 1));

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add unavailable period'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedReason,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      items: reasons
                          .map(
                            (reason) => DropdownMenuItem<String>(
                              value: reason,
                              child: Text(reason),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedReason = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.play_circle_outline),
                      title: const Text('Starts'),
                      subtitle: Text(
                        DateFormat('dd.MM.yyyy. HH:mm').format(start),
                      ),
                      onTap: () async {
                        final selected = await _pickDateTime(
                          dialogContext,
                          start,
                        );

                        if (selected != null) {
                          setDialogState(() {
                            start = selected;

                            if (!end.isAfter(start)) {
                              end = start.add(const Duration(hours: 1));
                            }
                          });
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.stop_circle_outlined),
                      title: const Text('Ends'),
                      subtitle: Text(
                        DateFormat('dd.MM.yyyy. HH:mm').format(end),
                      ),
                      onTap: () async {
                        final selected = await _pickDateTime(
                          dialogContext,
                          end,
                        );

                        if (selected != null) {
                          setDialogState(() {
                            end = selected;
                          });
                        }
                      },
                    ),
                  ],
                ),
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
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || !mounted) {
      return;
    }

    final success = await _therapistProfileViewModel.addUnavailablePeriod(
      start: start,
      end: end,
      reason: selectedReason,
    );

    if (!mounted) {
      return;
    }

    _showTherapistResultMessage(success);
  }

  Future<DateTime?> _pickDateTime(
    BuildContext dialogContext,
    DateTime initialValue,
  ) async {
    final date = await showDatePicker(
      context: dialogContext,
      initialDate: initialValue,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (date == null || !dialogContext.mounted) {
      return null;
    }

    final time = await showTimePicker(
      context: dialogContext,
      initialTime: TimeOfDay.fromDateTime(initialValue),
    );

    if (time == null) {
      return null;
    }

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _deleteAvailability(int availabilityId) async {
    final confirmed = await _confirmDelete(
      title: 'Delete working hours?',
      message:
          'The selected working interval will no longer be available for booking.',
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await _therapistProfileViewModel.deleteAvailability(
      availabilityId,
    );

    if (!mounted) {
      return;
    }

    _showTherapistResultMessage(success);
  }

  Future<void> _deleteUnavailablePeriod(int unavailableDateId) async {
    final confirmed = await _confirmDelete(
      title: 'Delete unavailable period?',
      message: 'This period will become available for booking again.',
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await _therapistProfileViewModel.deleteUnavailablePeriod(
      unavailableDateId,
    );

    if (!mounted) {
      return;
    }

    _showTherapistResultMessage(success);
  }

  Future<bool?> _confirmDelete({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
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
  }

  void _showTherapistResultMessage(bool success) {
    final message = success
        ? _therapistProfileViewModel.successMessage ??
              'Availability updated successfully.'
        : _therapistProfileViewModel.errorMessage ??
              'Availability could not be updated.';

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildUnavailablePeriodCard(UnavailableDateModel period) {
    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(_unavailableReasonIcon(period.reason)),
        title: Text(period.reason.isEmpty ? 'Unavailable' : period.reason),
        subtitle: Text(
          '${formatter.format(period.localStart)}\n'
          '${formatter.format(period.localEnd)}',
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: 'Delete unavailable period',
          onPressed: _therapistProfileViewModel.isManagingAvailability
              ? null
              : () {
                  _deleteUnavailablePeriod(period.id);
                },
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }

  IconData _unavailableReasonIcon(String reason) {
    switch (reason.trim().toLowerCase()) {
      case 'break':
        return Icons.free_breakfast_outlined;

      case 'blocked time':
        return Icons.event_busy_outlined;

      case 'annual leave':
        return Icons.beach_access_outlined;

      case 'temporarily unavailable':
        return Icons.pause_circle_outline;

      default:
        return Icons.block_outlined;
    }
  }
}
