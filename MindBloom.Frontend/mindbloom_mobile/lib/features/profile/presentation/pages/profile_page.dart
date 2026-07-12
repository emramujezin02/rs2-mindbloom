import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_refresh);
    _viewModel.loadProfile();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_refresh);
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
        onRefresh: _viewModel.loadProfile,
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
}
