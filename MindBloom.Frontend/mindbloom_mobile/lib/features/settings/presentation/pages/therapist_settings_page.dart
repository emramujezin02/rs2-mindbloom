import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../notification/presentation/viewmodels/notification_scope.dart';
import '../../../session/presentation/viewmodels/session_scope.dart';
import '../viewmodels/therapist_settings_viewmodel.dart';

class TherapistSettingsPage extends StatefulWidget {
  const TherapistSettingsPage({super.key});

  @override
  State<TherapistSettingsPage> createState() => _TherapistSettingsPageState();
}

class _TherapistSettingsPageState extends State<TherapistSettingsPage> {
  static const String _activeTabKey =
      'mindbloom_therapist_active_navigation_tab';

  final TherapistSettingsViewModel _viewModel =
      AppInjection.createTherapistSettingsViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_refresh);
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_refresh);
    _viewModel.dispose();

    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _save() async {
    final success = await _viewModel.save();

    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_viewModel.error ?? 'Settings could not be saved.'),
        ),
      );

      return;
    }

    final notifications = NotificationScope.of(context);

    if (_viewModel.notificationsEnabled) {
      await notifications.initialize();
    } else {
      await notifications.stop();
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved successfully.')),
    );
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
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This action is permanent. '
                      'Your private data will be deleted or anonymized '
                      'and you will no longer be able to sign in.',
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Financial and audit records that must remain '
                      'for system integrity may be retained in anonymized form.',
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Current password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
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
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
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
                  child: const Text('Delete account'),
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
     * Backend je već opozvao sesije,
     * a repository je očistio lokalni
     * token storage.
     *
     * Gasimo i lokalne notification
     * konekcije prije odlaska na login.
     */
      final notifications = NotificationScope.of(context);

      await notifications.stop();

      if (!mounted) {
        return;
      }

      final preferences = await SharedPreferences.getInstance();

      await preferences.remove(_activeTabKey);

      if (!mounted) {
        return;
      }

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
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Log out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final session = SessionScope.of(context);

    final notifications = NotificationScope.of(context);

    await notifications.stop();
    await session.logout();

    final preferences = await SharedPreferences.getInstance();

    await preferences.remove(_activeTabKey);

    if (!mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _viewModel.load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_viewModel.error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _viewModel.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const _SectionTitle(title: 'Security'),

                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Change password'),
                      subtitle: const Text('Update your account password.'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(
                          context,
                        ).pushNamed(AppRouter.changePassword);
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  const _SectionTitle(title: 'Notifications'),

                  Card(
                    child: SwitchListTile(
                      secondary: const Icon(Icons.notifications_outlined),
                      title: const Text('Enable notifications'),
                      subtitle: const Text(
                        'Receive appointment, message and account notifications.',
                      ),
                      value: _viewModel.notificationsEnabled,
                      onChanged: _viewModel.setNotificationsEnabled,
                    ),
                  ),

                  const SizedBox(height: 24),

                  const _SectionTitle(title: 'Privacy'),

                  Card(
                    child: SwitchListTile(
                      secondary: const Icon(Icons.public_outlined),
                      title: const Text('Public profile'),
                      subtitle: const Text(
                        'Allow clients to find and view your therapist profile.',
                      ),
                      value: _viewModel.showProfilePublicly,
                      onChanged: _viewModel.setShowProfilePublicly,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('Privacy & consents'),
                      subtitle: const Text(
                        'Review accepted privacy documents and consent versions.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(
                          context,
                        ).pushNamed(AppRouter.privacyConsents);
                      },
                    ),
                  ),

                  const SizedBox(height: 28),

                  FilledButton.icon(
                    onPressed: _viewModel.isSaving ? null : _save,
                    icon: _viewModel.isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _viewModel.isSaving ? 'Saving...' : 'Save settings',
                    ),
                  ),

                  const SizedBox(height: 28),

                  const _SectionTitle(title: 'Account'),

                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_forever_outlined,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        'Delete account',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Permanently delete and anonymize your account data.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _deleteAccount,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.logout,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        'Log out',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: _logout,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}
