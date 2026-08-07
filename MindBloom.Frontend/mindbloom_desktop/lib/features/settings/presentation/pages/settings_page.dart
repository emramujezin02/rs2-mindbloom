import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../session/presentation/viewmodels/session_scope.dart';
import '../viewmodels/admin_settings_viewmodel.dart';
import '../../../../core/widgets/app_error_panel.dart';
import '../../../../core/widgets/app_loading_state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final AdminSettingsViewModel _viewModel;

  final GlobalKey<FormState> _profileFormKey = GlobalKey<FormState>();

  final GlobalKey<FormState> _passwordFormKey = GlobalKey<FormState>();

  final TextEditingController _firstNameController = TextEditingController();

  final TextEditingController _lastNameController = TextEditingController();

  final TextEditingController _phoneController = TextEditingController();

  final TextEditingController _currentPasswordController =
      TextEditingController();

  final TextEditingController _newPasswordController = TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _profileInitialized = false;

  bool _obscureCurrentPassword = true;

  bool _obscureNewPassword = true;

  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();

    _viewModel = AppInjection.createAdminSettingsViewModel();

    _viewModel.addListener(_onViewModelChanged);

    _viewModel.initialize();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);

    _viewModel.dispose();

    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();

    _currentPasswordController.dispose();

    _newPasswordController.dispose();

    _confirmPasswordController.dispose();

    super.dispose();
  }

  void _onViewModelChanged() {
    if (!mounted) {
      return;
    }

    final profile = _viewModel.profile;

    if (!_profileInitialized && profile != null) {
      _profileInitialized = true;

      _firstNameController.text = profile.firstName;

      _lastNameController.text = profile.lastName;

      _phoneController.text = profile.phoneNumber;
    }

    setState(() {});
  }

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) {
      return;
    }

    final success = await _viewModel.updateProfile(
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      phoneNumber: _phoneController.text,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      return;
    }

    final profile = _viewModel.profile;

    if (profile != null) {
      _firstNameController.text = profile.firstName;

      _lastNameController.text = profile.lastName;

      _phoneController.text = profile.phoneNumber;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profil administratora je uspješno ažuriran.'),
      ),
    );
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) {
      return;
    }

    final success = await _viewModel.changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
      confirmNewPassword: _confirmPasswordController.text,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      return;
    }

    _currentPasswordController.clear();

    _newPasswordController.clear();

    _confirmPasswordController.clear();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Lozinka je promijenjena'),
          content: const Text(
            'Lozinka je uspješno promijenjena. '
            'Radi sigurnosti ćete biti odjavljeni '
            'i potrebno je ponovo se prijaviti.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('U redu'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    /*
     * Backend je nakon promjene lozinke
     * opozvao refresh tokene.
     *
     * Ovdje uklanjamo i trenutnu lokalnu
     * desktop sesiju.
     */
    final session = SessionScope.of(context);

    await session.logout();

    if (!mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
  }

  Future<void> _changeNotifications(bool value) async {
    final previousValue = _viewModel.accountSettings?.notificationsEnabled;

    final success = await _viewModel.setNotificationsEnabled(value);

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Notifikacije su uključene.'
                : 'Notifikacije su isključene.',
          ),
        ),
      );

      return;
    }

    if (previousValue != null) {
      setState(() {});
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Odjava'),
          content: const Text(
            'Da li ste sigurni da se želite '
            'odjaviti iz MindBloom '
            'administratorske aplikacije?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Odustani'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.logout),
              label: const Text('Odjavi se'),
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

  @override
  Widget build(BuildContext context) {
    if (_viewModel.isLoading && _viewModel.profile == null) {
      return const AppLoadingState(
        message: 'Učitavanje administratorskih postavki...',
      );
    }

    if (_viewModel.profile == null) {
      return AppErrorPanel(
        message:
            _viewModel.errorMessage ??
            'Postavke administratora nije moguće učitati.',
        onRetry: _viewModel.isLoading
            ? null
            : () {
                _profileInitialized = false;

                _viewModel.initialize();
              },
      );
    }

    return SingleChildScrollView(
      key: const PageStorageKey<String>('admin-settings'),
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),

              if (_viewModel.errorMessage != null) ...[
                const SizedBox(height: 18),
                AppErrorBanner(
                  message: _viewModel.errorMessage!,
                  onDismiss: _viewModel.clearError,
                ),
              ],

              const SizedBox(height: 24),

              _buildProfileCard(),

              const SizedBox(height: 20),

              _buildNotificationCard(),

              const SizedBox(height: 20),

              _buildPasswordCard(),

              const SizedBox(height: 20),

              _buildApplicationCard(),

              const SizedBox(height: 20),

              _buildLogoutCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Postavke',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 6),
        Text(
          'Upravljajte administratorskim profilom, '
          'sigurnošću naloga i osnovnim postavkama aplikacije.',
        ),
      ],
    );
  }

  Widget _buildProfileCard() {
    final profile = _viewModel.profile!;

    final session = SessionScope.of(context);

    final role = session.currentUser?.role.trim().isNotEmpty == true
        ? session.currentUser!.role
        : 'Admin';

    final initial = profile.fullName.trim().isEmpty
        ? 'A'
        : profile.fullName.trim()[0].toUpperCase();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _profileFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 38,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Administratorski profil',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          profile.email,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Chip(
                          avatar: const Icon(
                            Icons.admin_panel_settings_outlined,
                            size: 18,
                          ),
                          label: Text(role),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 26),

              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 700;

                  final firstName = TextFormField(
                    controller: _firstNameController,
                    enabled: !_viewModel.isSavingProfile,
                    maxLength: 50,
                    decoration: const InputDecoration(
                      labelText: 'Ime',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final normalized = value?.trim() ?? '';

                      if (normalized.isEmpty) {
                        return 'Ime je obavezno.';
                      }

                      if (normalized.length < 2) {
                        return 'Ime mora imati najmanje 2 karaktera.';
                      }

                      return null;
                    },
                  );

                  final lastName = TextFormField(
                    controller: _lastNameController,
                    enabled: !_viewModel.isSavingProfile,
                    maxLength: 50,
                    decoration: const InputDecoration(
                      labelText: 'Prezime',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final normalized = value?.trim() ?? '';

                      if (normalized.isEmpty) {
                        return 'Prezime je obavezno.';
                      }

                      if (normalized.length < 2) {
                        return 'Prezime mora imati najmanje 2 karaktera.';
                      }

                      return null;
                    },
                  );

                  if (compact) {
                    return Column(
                      children: [
                        firstName,
                        const SizedBox(height: 12),
                        lastName,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: firstName),
                      const SizedBox(width: 16),
                      Expanded(child: lastName),
                    ],
                  );
                },
              ),

              const SizedBox(height: 12),

              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: TextFormField(
                  controller: _phoneController,
                  enabled: !_viewModel.isSavingProfile,
                  maxLength: 20,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Broj telefona',
                    hintText: '+387 61 123 456',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final phone = value?.trim() ?? '';

                    if (phone.isEmpty) {
                      return null;
                    }

                    if (phone.length < 7 || phone.length > 20) {
                      return 'Broj telefona mora imati između 7 i 20 karaktera.';
                    }

                    final valid = RegExp(r'^\+?[0-9 \-]+$').hasMatch(phone);

                    if (!valid) {
                      return 'Broj telefona sadrži nedozvoljene karaktere.';
                    }

                    return null;
                  },
                ),
              ),

              const SizedBox(height: 6),

              _ReadOnlyInfoRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: profile.email,
              ),

              const SizedBox(height: 12),

              _ReadOnlyInfoRow(
                icon: Icons.admin_panel_settings_outlined,
                label: 'Uloga',
                value: role,
              ),

              const SizedBox(height: 8),

              Text(
                'Uloga administratora se ne može mijenjati kroz postavke naloga.',
                style: Theme.of(context).textTheme.bodySmall,
              ),

              const SizedBox(height: 22),

              FilledButton.icon(
                onPressed: _viewModel.isSavingProfile ? null : _saveProfile,
                icon: _viewModel.isSavingProfile
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _viewModel.isSavingProfile
                      ? 'Spremanje...'
                      : 'Sačuvaj profil',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard() {
    final settings = _viewModel.accountSettings;

    if (settings == null) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              const Icon(Icons.notifications_outlined),
              const SizedBox(width: 14),
              const Expanded(
                child: Text('Postavke notifikacija trenutno nisu dostupne.'),
              ),
              IconButton(
                tooltip: 'Osvježi',
                onPressed: _viewModel.isLoading ? null : _viewModel.initialize,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notifikacije',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Odaberite da li želite primati '
              'notifikacije povezane sa administratorskim nalogom.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('Omogući notifikacije'),
              subtitle: Text(
                settings.notificationsEnabled
                    ? 'Notifikacije su trenutno uključene.'
                    : 'Notifikacije su trenutno isključene.',
              ),
              value: settings.notificationsEnabled,
              onChanged: _viewModel.isSavingNotifications
                  ? null
                  : _changeNotifications,
            ),
            if (_viewModel.isSavingNotifications)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _passwordFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Promjena lozinke',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Za promjenu lozinke morate unijeti '
                'trenutnu lozinku i potvrditi novu.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 22),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: _obscureCurrentPassword,
                      enabled: !_viewModel.isChangingPassword,
                      decoration: InputDecoration(
                        labelText: 'Trenutna lozinka',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _obscureCurrentPassword
                              ? 'Prikaži lozinku'
                              : 'Sakrij lozinku',
                          onPressed: () {
                            setState(() {
                              _obscureCurrentPassword =
                                  !_obscureCurrentPassword;
                            });
                          },
                          icon: Icon(
                            _obscureCurrentPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Trenutna lozinka je obavezna.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: _obscureNewPassword,
                      enabled: !_viewModel.isChangingPassword,
                      decoration: InputDecoration(
                        labelText: 'Nova lozinka',
                        prefixIcon: const Icon(Icons.password_outlined),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _obscureNewPassword
                              ? 'Prikaži lozinku'
                              : 'Sakrij lozinku',
                          onPressed: () {
                            setState(() {
                              _obscureNewPassword = !_obscureNewPassword;
                            });
                          },
                          icon: Icon(
                            _obscureNewPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Nova lozinka je obavezna.';
                        }

                        if (value.length < 6) {
                          return 'Nova lozinka mora imati najmanje 6 karaktera.';
                        }

                        if (value == _currentPasswordController.text) {
                          return 'Nova lozinka mora biti različita od trenutne.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      enabled: !_viewModel.isChangingPassword,
                      decoration: InputDecoration(
                        labelText: 'Potvrdi novu lozinku',
                        prefixIcon: const Icon(Icons.password_outlined),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _obscureConfirmPassword
                              ? 'Prikaži lozinku'
                              : 'Sakrij lozinku',
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Potvrda nove lozinke je obavezna.';
                        }

                        if (value != _newPasswordController.text) {
                          return 'Lozinke se ne podudaraju.';
                        }

                        return null;
                      },
                      onFieldSubmitted: (_) {
                        if (!_viewModel.isChangingPassword) {
                          _changePassword();
                        }
                      },
                    ),

                    const SizedBox(height: 20),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: _viewModel.isChangingPassword
                            ? null
                            : _changePassword,
                        icon: _viewModel.isChangingPassword
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.lock_reset),
                        label: Text(
                          _viewModel.isChangingPassword
                              ? 'Promjena...'
                              : 'Promijeni lozinku',
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
    );
  }

  Widget _buildApplicationCard() {
    final info = _viewModel.applicationInfo;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informacije o aplikaciji',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            _ReadOnlyInfoRow(
              icon: Icons.info_outline,
              label: 'Verzija aplikacije',
              value: info?.displayVersion ?? '—',
            ),
            if (info?.environment != null) ...[
              const SizedBox(height: 14),
              _ReadOnlyInfoRow(
                icon: Icons.code_outlined,
                label: 'Okruženje',
                value: info!.environment!,
              ),
              const SizedBox(height: 8),
              Text(
                'Informacija o okruženju prikazuje se samo u development/debug modu.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Odjava',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text('Završite trenutnu administratorsku sesiju.'),
                ],
              ),
            ),
            const SizedBox(width: 20),
            OutlinedButton.icon(
              onPressed: _viewModel.isBusy ? null : _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Odjavi se'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyInfoRow extends StatelessWidget {
  final IconData icon;

  final String label;

  final String value;

  const _ReadOnlyInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 3),
              SelectableText(
                value.trim().isEmpty ? '—' : value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
