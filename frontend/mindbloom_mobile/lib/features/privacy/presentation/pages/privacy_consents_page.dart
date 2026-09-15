import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../data/models/user_consent_model.dart';
import '../viewmodels/privacy_consents_viewmodel.dart';

class PrivacyConsentsPage extends StatefulWidget {
  const PrivacyConsentsPage({super.key});

  @override
  State<PrivacyConsentsPage> createState() => _PrivacyConsentsPageState();
}

class _PrivacyConsentsPageState extends State<PrivacyConsentsPage> {
  final PrivacyConsentsViewModel _viewModel =
      AppInjection.createPrivacyConsentsViewModel();

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
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & consents')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.consents.isEmpty) {
      return const AppLoadingWidget(message: 'Loading privacy consents...');
    }

    if (_viewModel.error != null && _viewModel.consents.isEmpty) {
      return AppErrorWidget(
        title: 'Privacy consents could not be loaded',
        error: _viewModel.error,
        onRetry: _reload,
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.privacy_tip_outlined, size: 72),

          const SizedBox(height: 16),

          const Text(
            'Your privacy choices',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          const Text(
            'Here you can review which privacy and data-processing documents you accepted, including their version and acceptance date.',
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 28),

          _buildConsentSection(
            title: 'Privacy Policy',
            icon: Icons.shield_outlined,
            consentType: 'PrivacyPolicy',
          ),

          const SizedBox(height: 14),

          _buildConsentSection(
            title: 'Terms of Service',
            icon: Icons.description_outlined,
            consentType: 'TermsOfService',
          ),

          const SizedBox(height: 14),

          _buildConsentSection(
            title: 'Sensitive data processing',
            icon: Icons.health_and_safety_outlined,
            consentType: 'SensitiveDataProcessing',
            optional: true,
          ),

          finalExplanation(),

          if (_viewModel.error != null) ...[
            const SizedBox(height: 20),

            Text(
              _viewModel.error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget finalExplanation() {
    final explanation =
        _viewModel.currentVersions?.sensitiveDataUsageExplanation.trim() ?? '';

    if (explanation.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assessment data usage',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(explanation),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentSection({
    required String title,
    required IconData icon,
    required String consentType,
    bool optional = false,
  }) {
    final consent = _viewModel.latestConsent(consentType);

    final currentVersion =
        _viewModel.currentVersions?.versionFor(consentType).trim() ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 8),

                  if (consent == null) ...[
                    Text(
                      optional
                          ? 'No consent has been recorded.'
                          : 'No acceptance record is available.',
                    ),

                    if (currentVersion.isNotEmpty) ...[
                      const SizedBox(height: 4),

                      Text('Current version: $currentVersion'),
                    ],
                  ] else
                    _buildAcceptedDetails(consent, currentVersion),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptedDetails(
    UserConsentModel consent,
    String currentVersion,
  ) {
    final current = _viewModel.isCurrent(consent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              current ? Icons.verified_outlined : Icons.history_outlined,
              size: 19,
            ),

            const SizedBox(width: 7),

            Expanded(
              child: Text(
                current
                    ? 'Accepted — current version'
                    : 'Accepted — older version',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Text(
          'Accepted version: '
          '${consent.documentVersion}',
        ),

        const SizedBox(height: 4),

        Text(
          'Accepted: '
          '${_formatDateTime(consent.acceptedAtUtc)}',
        ),

        if (currentVersion.isNotEmpty) ...[
          const SizedBox(height: 4),

          Text(
            'Current version: '
            '$currentVersion',
          ),
        ],
      ],
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();

    final day = local.day.toString().padLeft(2, '0');

    final month = local.month.toString().padLeft(2, '0');

    final hour = local.hour.toString().padLeft(2, '0');

    final minute = local.minute.toString().padLeft(2, '0');

    return '$day.$month.${local.year}. '
        '$hour:$minute';
  }
}
