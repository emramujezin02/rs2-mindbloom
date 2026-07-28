import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../viewmodels/client_onboarding_viewmodel.dart';
import 'client_onboarding_page.dart';

class ClientOnboardingGate extends StatefulWidget {
  final Widget child;

  const ClientOnboardingGate({super.key, required this.child});

  @override
  State<ClientOnboardingGate> createState() => _ClientOnboardingGateState();
}

class _ClientOnboardingGateState extends State<ClientOnboardingGate> {
  final ClientOnboardingViewModel _viewModel =
      AppInjection.createClientOnboardingViewModel();

  bool _completedInCurrentSession = false;

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

  Future<void> _reload() {
    return _viewModel.load();
  }

  @override
  Widget build(BuildContext context) {
    if (_completedInCurrentSession) {
      return widget.child;
    }

    if (_viewModel.isLoading && _viewModel.onboarding == null) {
      return const Scaffold(
        body: AppLoadingWidget(message: 'Loading onboarding information...'),
      );
    }

    if (_viewModel.error != null && _viewModel.onboarding == null) {
      return Scaffold(
        body: AppErrorWidget(
          title: 'Onboarding information could not be loaded',
          error: _viewModel.error,
          onRetry: _reload,
        ),
      );
    }

    final completed = _viewModel.onboarding?.hasCompletedOnboarding == true;

    if (completed) {
      return widget.child;
    }

    return ClientOnboardingPage(
      isRequired: true,
      onCompleted: () {
        setState(() {
          _completedInCurrentSession = true;
        });
      },
    );
  }
}
