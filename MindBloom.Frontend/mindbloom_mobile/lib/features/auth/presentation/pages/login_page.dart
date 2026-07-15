import 'package:flutter/material.dart';
import '../../../notification/presentation/viewmodels/notification_scope.dart';
import '../../../../app/di/injection.dart';
import '../../../session/presentation/viewmodels/session_scope.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../../../../app/router/app_router.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthViewModel _viewModel = AppInjection.createAuthViewModel();

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();

    final success = await _viewModel.login(
      email: email,
      password: _passwordController.text,
      rememberMe: _rememberMe,
    );

    if (!mounted) {
      return;
    }

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

    if (_viewModel.requiresTwoFactor) {
      Navigator.of(context).pushNamed(AppRouter.verify2FA, arguments: email);

      return;
    }

    final session = SessionScope.of(context);

    final notifications = NotificationScope.of(context);

    await session.initialize();

    if (!mounted) {
      return;
    }

    await notifications.initialize();

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
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email is required.';
                      }

                      if (!value.contains('@')) {
                        return 'Enter a valid email address.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password is required.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  CheckboxListTile(
                    value: _rememberMe,
                    onChanged: (value) {
                      setState(() {
                        _rememberMe = value ?? false;
                      });
                    },
                    title: const Text('Remember me'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),

                  if (_viewModel.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _viewModel.errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),

                  ElevatedButton(
                    onPressed: _viewModel.isLoading ? null : _login,
                    child: _viewModel.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Login'),
                  ),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushNamed(AppRouter.forgotPassword);
                      },
                      child: const Text('Forgot password?'),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: () {
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
