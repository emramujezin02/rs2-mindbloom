import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../viewmodels/profile_viewmodel.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileViewModel _viewModel = AppInjection.createProfileViewModel();

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

    if (result == true) {
      await _viewModel.loadProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_viewModel.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_viewModel.error != null) {
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

    if (_viewModel.profile == null) {
      return const Scaffold(
        body: Center(child: Text('Unable to load profile.')),
      );
    }

    final profile = _viewModel.profile!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My profile'),
        actions: [
          IconButton(onPressed: _openEditProfile, icon: const Icon(Icons.edit)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(radius: 45, child: Icon(Icons.person, size: 45)),

            const SizedBox(height: 20),

            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Name'),
              subtitle: Text('${profile.firstName} ${profile.lastName}'),
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
