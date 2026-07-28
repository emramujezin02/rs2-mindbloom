import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../notification/presentation/viewmodels/notification_scope.dart';
import '../../../session/presentation/viewmodels/session_scope.dart';
import '../viewmodels/auth_viewmodel.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthViewModel _viewModel = AppInjection.createAuthViewModel();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();

    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _login() async {
    if (_viewModel.isLoading || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();

    final success = await _viewModel.login(
      email: email,
      password: _passwordController.text,
      rememberMe: _rememberMe,
    );

    if (!mounted) {
      return;
    }

    /*
     * Ranija funkcionalnost:
     * korisnik čiji email nije potvrđen ide na verifikaciju emaila.
     */
    if (!success && _viewModel.needsEmailVerification) {
      Navigator.of(context).pushNamed(
        AppRouter.verifyEmail,
        arguments: _viewModel.pendingVerificationEmail ?? email,
      );

      return;
    }

    if (!success) {
      return;
    }

    /*
     * Ranija funkcionalnost:
     * korisnik kojem je uključen 2FA prvo mora potvrditi kod.
     */
    if (_viewModel.requiresTwoFactor) {
      Navigator.of(context).pushNamed(AppRouter.verify2FA, arguments: email);

      return;
    }

    /*
     * Nakon uspješne prijave ponovo se učitava korisnička sesija.
     */
    final session = SessionScope.of(context);

    /*
     * Ranija funkcionalnost:
     * nakon prijave inicijalizuju se i notifikacije.
     */
    final notifications = NotificationScope.of(context);

    await session.initialize();

    if (!mounted) {
      return;
    }

    await notifications.initialize();

    if (!mounted) {
      return;
    }

    /*
     * HomeScreen zatim na osnovu uloge prikazuje odgovarajući shell:
     * ClientNavigationShell ili TherapistNavigationShell.
     */
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRouter.home, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
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
                    'Welcome to MindBloom',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    enabled: !_viewModel.isLoading,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';

                      if (email.isEmpty) {
                        return 'Email is required.';
                      }

                      if (!email.contains('@')) {
                        return 'Enter a valid email address.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    enabled: !_viewModel.isLoading,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
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
                        return 'Password is required.';
                      }

                      return null;
                    },
                    onFieldSubmitted: (_) {
                      if (!_viewModel.isLoading) {
                        _login();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _rememberMe,
                    onChanged: _viewModel.isLoading
                        ? null
                        : (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                    title: const Text('Remember me'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_viewModel.errorMessage != null) ...[
                    const SizedBox(height: 4),
                    AppInlineError(
                      title: 'Login failed',
                      error: _viewModel.errorMessage,
                      onRetry: _login,
                    ),
                    const SizedBox(height: 16),
                  ] else
                    const SizedBox(height: 4),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _viewModel.isLoading ? null : _login,
                      icon: _viewModel.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(
                        _viewModel.isLoading ? 'Logging in...' : 'Login',
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _viewModel.isLoading
                          ? null
                          : () {
                              Navigator.of(
                                context,
                              ).pushNamed(AppRouter.forgotPassword);
                            },
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _viewModel.isLoading
                        ? null
                        : () {
                            Navigator.of(
                              context,
                            ).pushReplacementNamed(AppRouter.register);
                          },
                    child: const Text('Do not have an account? Register'),
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
