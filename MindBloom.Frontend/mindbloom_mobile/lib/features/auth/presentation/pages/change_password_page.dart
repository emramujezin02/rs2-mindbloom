import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../viewmodels/auth_viewmodel.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final AuthViewModel _viewModel = AppInjection.createAuthViewModel();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _currentPasswordController =
      TextEditingController();

  final TextEditingController _newPasswordController = TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _hideCurrentPassword = true;
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();

    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _changePassword() async {
    if (_viewModel.isLoading || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final success = await _viewModel.changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully.')),
      );

      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter your current password and choose a new password.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _currentPasswordController,
                enabled: !_viewModel.isLoading,
                obscureText: _hideCurrentPassword,
                decoration: InputDecoration(
                  labelText: 'Current password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: _viewModel.isLoading
                        ? null
                        : () {
                            setState(() {
                              _hideCurrentPassword = !_hideCurrentPassword;
                            });
                          },
                    icon: Icon(
                      _hideCurrentPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Current password is required.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                enabled: !_viewModel.isLoading,
                obscureText: _hideNewPassword,
                decoration: InputDecoration(
                  labelText: 'New password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: _viewModel.isLoading
                        ? null
                        : () {
                            setState(() {
                              _hideNewPassword = !_hideNewPassword;
                            });
                          },
                    icon: Icon(
                      _hideNewPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'New password is required.';
                  }

                  if (value.length < 6) {
                    return 'Password must contain at least 6 characters.';
                  }

                  if (value == _currentPasswordController.text) {
                    return 'New password must be different from the current password.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                enabled: !_viewModel.isLoading,
                obscureText: _hideConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm new password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: _viewModel.isLoading
                        ? null
                        : () {
                            setState(() {
                              _hideConfirmPassword = !_hideConfirmPassword;
                            });
                          },
                    icon: Icon(
                      _hideConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password confirmation is required.';
                  }

                  if (value != _newPasswordController.text) {
                    return 'Passwords do not match.';
                  }

                  return null;
                },
                onFieldSubmitted: (_) {
                  _changePassword();
                },
              ),
              if (_viewModel.errorMessage != null) ...[
                const SizedBox(height: 16),
                AppInlineError(
                  title: 'Password could not be changed',
                  error: _viewModel.errorMessage,
                  onRetry: _changePassword,
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _viewModel.isLoading ? null : _changePassword,
                icon: _viewModel.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_reset),
                label: Text(
                  _viewModel.isLoading
                      ? 'Changing password...'
                      : 'Change password',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
