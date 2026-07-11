import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../session/presentation/viewmodels/session_scope.dart';
import '../viewmodels/auth_viewmodel.dart';

class Verify2FAPage extends StatefulWidget {
  final String email;

  const Verify2FAPage({super.key, required this.email});

  @override
  State<Verify2FAPage> createState() => _Verify2FAPageState();
}

class _Verify2FAPageState extends State<Verify2FAPage> {
  final AuthViewModel _viewModel = AppInjection.createAuthViewModel();

  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_refresh);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_refresh);
    _codeController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await _viewModel.verify2FA(
      email: widget.email,
      code: _codeController.text.trim(),
    );

    if (!mounted || !success) {
      return;
    }

    final session = SessionScope.of(context);

    await session.initialize();

    if (!mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRouter.home, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Two-factor authentication')),
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
                  const Icon(Icons.security, size: 70),
                  const SizedBox(height: 20),
                  const Text(
                    'Enter the six-digit code sent to your email.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Verification code',
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
                  ),
                  const SizedBox(height: 16),
                  if (_viewModel.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _viewModel.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ElevatedButton.icon(
                    onPressed: _viewModel.isLoading ? null : _verify,
                    icon: const Icon(Icons.verified_user),
                    label: _viewModel.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Verify'),
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
