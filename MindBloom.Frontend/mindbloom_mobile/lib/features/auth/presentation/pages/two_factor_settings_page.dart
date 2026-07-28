import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../viewmodels/auth_viewmodel.dart';

class TwoFactorSettingsPage extends StatefulWidget {
  const TwoFactorSettingsPage({super.key});

  @override
  State<TwoFactorSettingsPage> createState() => _TwoFactorSettingsPageState();
}

class _TwoFactorSettingsPageState extends State<TwoFactorSettingsPage> {
  final AuthViewModel _viewModel = AppInjection.createAuthViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_refresh);
    _viewModel.load2FAStatus();
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

  Future<void> _reload() {
    return _viewModel.load2FAStatus();
  }

  Future<void> _changeStatus(bool enabled) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(enabled ? 'Enable 2FA' : 'Disable 2FA'),
          content: Text(
            enabled
                ? 'A verification code will be required during future logins.'
                : 'Future logins will no longer require a verification code.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await _viewModel.set2FAEnabled(enabled);

    if (!mounted || !success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? 'Two-factor authentication enabled.'
              : 'Two-factor authentication disabled.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Two-factor authentication'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _viewModel.isLoading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.errorMessage == null) {
      return const AppLoadingWidget(
        message: 'Loading two-factor authentication settings...',
      );
    }

    if (_viewModel.errorMessage != null) {
      return AppErrorWidget(
        title: 'Two-factor authentication settings could not be loaded',
        error: _viewModel.errorMessage,
        onRetry: _reload,
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.security, size: 80),
          const SizedBox(height: 20),
          const Text(
            'Two-factor authentication adds an email verification code to your login process.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Enable two-factor authentication'),
            subtitle: Text(
              _viewModel.isTwoFactorEnabled
                  ? 'Currently enabled'
                  : 'Currently disabled',
            ),
            value: _viewModel.isTwoFactorEnabled,
            onChanged: _viewModel.isLoading ? null : _changeStatus,
          ),
        ],
      ),
    );
  }
}
