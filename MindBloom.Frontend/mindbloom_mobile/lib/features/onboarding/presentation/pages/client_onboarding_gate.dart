import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
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

  @override
  Widget build(BuildContext context) {
    if (_completedInCurrentSession) {
      return widget.child;
    }

    if (_viewModel.isLoading && _viewModel.onboarding == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_viewModel.error != null && _viewModel.onboarding == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_viewModel.error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _viewModel.load,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
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
