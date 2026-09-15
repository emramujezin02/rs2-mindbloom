import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../viewmodels/auth_viewmodel.dart';

class VerifyEmailPage extends StatefulWidget {
  final String email;

  const VerifyEmailPage({super.key, required this.email});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final AuthViewModel _viewModel = AppInjection.createAuthViewModel();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _codeController.dispose();

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _verify() async {
    if (_viewModel.isLoading || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final success = await _viewModel.verifyEmailCode(
      email: widget.email,
      code: _codeController.text.trim(),
    );

    if (!mounted || !success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Email verified successfully. Please log in.'),
      ),
    );

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
  }

  Future<void> _resendCode() async {
    if (_viewModel.isLoading) {
      return;
    }

    final success = await _viewModel.sendEmailVerificationCode(
      email: widget.email,
    );

    if (!mounted || !success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('A new verification code has been sent.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify email')),
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
                  const Icon(Icons.mark_email_read, size: 80),
                  const SizedBox(height: 20),
                  const Text(
                    'We sent a six-digit verification code to:',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.email,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _codeController,
                    enabled: !_viewModel.isLoading,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Verification code',
                      hintText: '123456',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    validator: (value) {
                      final code = value?.trim() ?? '';

                      if (code.isEmpty) {
                        return 'Verification code is required.';
                      }

                      if (!RegExp(r'^\d{6}$').hasMatch(code)) {
                        return 'Enter a valid six-digit code.';
                      }

                      return null;
                    },
                    onFieldSubmitted: (_) {
                      _verify();
                    },
                  ),
                  if (_viewModel.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    AppInlineError(
                      title: 'Email verification failed',
                      error: _viewModel.errorMessage,
                      onRetry: _verify,
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _viewModel.isLoading ? null : _verify,
                    icon: _viewModel.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified),
                    label: Text(
                      _viewModel.isLoading ? 'Verifying...' : 'Verify email',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _viewModel.isLoading ? null : _resendCode,
                    child: const Text('Send a new code'),
                  ),
                  TextButton(
                    onPressed: _viewModel.isLoading
                        ? null
                        : () {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              AppRouter.login,
                              (route) => false,
                            );
                          },
                    child: const Text('Back to login'),
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
