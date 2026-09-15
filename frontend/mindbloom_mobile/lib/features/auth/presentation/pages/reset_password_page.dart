import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../viewmodels/auth_viewmodel.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;

  const ResetPasswordPage({super.key, required this.email});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final AuthViewModel _viewModel = AppInjection.createAuthViewModel();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _codeController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onChanged);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _viewModel.dispose();

    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _resetPassword() async {
    if (_viewModel.isLoading || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final success = await _viewModel.resetPassword(
      email: widget.email,
      code: _codeController.text.trim(),
      newPassword: _passwordController.text,
    );

    if (!mounted || !success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password reset successful. Please login.')),
    );

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Enter reset code',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(widget.email, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _codeController,
                    enabled: !_viewModel.isLoading,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Reset code',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Reset code is required.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    enabled: !_viewModel.isLoading,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'New password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: _viewModel.isLoading
                            ? null
                            : () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                        icon: Icon(
                          _obscurePassword
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
                        return 'Password must have at least 6 characters.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirmPasswordController,
                    enabled: !_viewModel.isLoading,
                    obscureText: _obscureConfirmation,
                    decoration: InputDecoration(
                      labelText: 'Confirm password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: _viewModel.isLoading
                            ? null
                            : () {
                                setState(() {
                                  _obscureConfirmation = !_obscureConfirmation;
                                });
                              },
                        icon: Icon(
                          _obscureConfirmation
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password confirmation is required.';
                      }

                      if (value != _passwordController.text) {
                        return 'Passwords do not match.';
                      }

                      return null;
                    },
                    onFieldSubmitted: (_) {
                      _resetPassword();
                    },
                  ),
                  if (_viewModel.errorMessage != null) ...[
                    const SizedBox(height: 14),
                    AppInlineError(
                      title: 'Password could not be reset',
                      error: _viewModel.errorMessage,
                      onRetry: _resetPassword,
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _viewModel.isLoading ? null : _resetPassword,
                    child: _viewModel.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Reset password'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
