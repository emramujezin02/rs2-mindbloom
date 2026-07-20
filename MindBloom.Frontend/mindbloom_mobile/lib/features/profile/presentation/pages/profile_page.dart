import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../therapist/data/models/therapist_profile_model.dart';
import '../../../therapist/presentation/viewmodels/therapist_profile_viewmodel.dart';
import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/constants/api_constants.dart';
import '../viewmodels/profile_viewmodel.dart';

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
                  Navigator.of(context).pushNamed(AppRouter.myReviews);
                },
                icon: const Icon(Icons.reviews),
                label: const Text('My reviews'),
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
}
