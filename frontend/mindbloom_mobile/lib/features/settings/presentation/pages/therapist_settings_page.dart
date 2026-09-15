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
      backgroundColor: const Color(0xFFF7F3FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Color(0xFF40334D),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
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

                  _SettingsSection(
                    title: 'Security',
                    children: [
                      _SettingsActionTile(
                        icon: Icons.lock_outline,
                        title: 'Change password',
                        description: 'Update your account password.',
                        onTap: () {
                          Navigator.of(
                            context,
                          ).pushNamed(AppRouter.changePassword);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _SettingsSection(
                    title: 'Notifications',
                    children: [
                      _SettingsSwitchTile(
                        icon: Icons.notifications_outlined,
                        title: 'Enable notifications',
                        description:
                            'Receive appointment, message and account notifications.',
                        value: _viewModel.notificationsEnabled,
                        onChanged: _viewModel.setNotificationsEnabled,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _SettingsSection(
                    title: 'Privacy',
                    children: [
                      _SettingsSwitchTile(
                        icon: Icons.public_outlined,
                        title: 'Public profile',
                        description:
                            'Allow clients to find and view your therapist profile.',
                        value: _viewModel.showProfilePublicly,
                        onChanged: _viewModel.setShowProfilePublicly,
                      ),
                      const Divider(height: 1, color: Color(0xFFE7DDF0)),
                      _SettingsActionTile(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy & consents',
                        description:
                            'Review accepted privacy documents and consent versions.',
                        onTap: () {
                          Navigator.of(
                            context,
                          ).pushNamed(AppRouter.privacyConsents);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
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
                  ),

                  const SizedBox(height: 24),

                  _SettingsSection(
                    title: 'Account',
                    children: [
                      _SettingsActionTile(
                        icon: Icons.delete_forever_outlined,
                        title: 'Delete account',
                        description:
                            'Permanently delete and anonymize your account data.',
                        isDestructive: true,
                        onTap: _deleteAccount,
                      ),
                      const Divider(height: 1, color: Color(0xFFE7DDF0)),
                      _SettingsActionTile(
                        icon: Icons.logout,
                        title: 'Log out',
                        description: 'End this therapist session.',
                        isDestructive: true,
                        onTap: _logout,
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF40334D),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE7DDF0)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isDestructive;
  final VoidCallback onTap;

  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? Theme.of(context).colorScheme.error
        : const Color(0xFF72559A);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: _SettingsIcon(icon: icon, color: color),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isDestructive ? color : const Color(0xFF40334D),
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        description,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xFF756D79), height: 1.35),
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF8063A4)),
      onTap: onTap,
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      secondary: _SettingsIcon(icon: icon, color: const Color(0xFF72559A)),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF40334D),
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        description,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xFF756D79), height: 1.35),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _SettingsIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color),
    );
  }
}
