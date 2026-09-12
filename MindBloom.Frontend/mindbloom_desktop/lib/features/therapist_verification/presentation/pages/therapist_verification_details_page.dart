import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/widgets/admin_status_badge.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/app_error_panel.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../../core/widgets/app_responsive_dialog_content.dart';
import '../viewmodels/therapist_verification_details_viewmodel.dart';

class TherapistVerificationDetailsPage extends StatefulWidget {
  final int therapistId;

  const TherapistVerificationDetailsPage({
    super.key,
    required this.therapistId,
  });

  @override
  State<TherapistVerificationDetailsPage> createState() =>
      _TherapistVerificationDetailsPageState();
}

class _TherapistVerificationDetailsPageState
    extends State<TherapistVerificationDetailsPage> {
  final TherapistVerificationDetailsViewModel _viewModel =
      AppInjection.createTherapistVerificationDetailsViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onChanged);

    _viewModel.load(widget.therapistId);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);

    _viewModel.dispose();

    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  String? _fileUrl(String? value) {
    final path = value?.trim() ?? '';

    if (path.isEmpty) {
      return null;
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    final normalized = path.startsWith('/') ? path : '/$path';

    return '${ApiConstants.baseUrl}$normalized';
  }

  Future<void> _openFile(String path) async {
    final url = _fileUrl(path);

    if (url == null) {
      return;
    }

    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );

    if (!mounted) {
      return;
    }

    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document could not be opened.')),
      );
    }
  }

  Future<void> _approve() async {
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Approve therapist'),
          content: AppResponsiveDialogContent(
            preferredWidth: 520,
            child: TextField(
              controller: notesController,
              maxLines: 4,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                alignLabelWithHint: true,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Approve'),
            ),
          ],
        );
      },
    );

    final notes = notesController.text.trim();

    notesController.dispose();

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await _viewModel.approve(
      therapistId: widget.therapistId,
      notes: notes.isEmpty ? null : notes,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Therapist approved successfully.')),
      );

      Navigator.of(context).pop(true);
    }
  }

  Future<void> _reject() async {
    final formKey = GlobalKey<FormState>();

    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reject therapist'),
          content: AppResponsiveDialogContent(
            preferredWidth: 520,
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: reasonController,
                minLines: 4,
                maxLines: 6,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Rejection reason',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  final reason = value?.trim() ?? '';

                  if (reason.isEmpty) {
                    return 'Rejection reason is required.';
                  }

                  if (reason.length < 5) {
                    return 'Reason must contain at least 5 characters.';
                  }

                  return null;
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                Navigator.of(dialogContext).pop(reasonController.text.trim());
              },
              icon: const Icon(Icons.close),
              label: const Text('Reject'),
            ),
          ],
        );
      },
    );

    reasonController.dispose();

    if (reason == null || !mounted) {
      return;
    }

    final success = await _viewModel.reject(
      therapistId: widget.therapistId,
      reason: reason,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Therapist rejected successfully.')),
      );

      Navigator.of(context).pop(true);
    }
  }

  Future<void> _requestChanges() async {
    final formKey = GlobalKey<FormState>();

    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Request changes'),
          content: AppResponsiveDialogContent(
            preferredWidth: 520,
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: reasonController,
                minLines: 4,
                maxLines: 6,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Required changes',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  final normalized = value?.trim() ?? '';

                  if (normalized.isEmpty) {
                    return 'Description of required changes is required.';
                  }

                  if (normalized.length < 5) {
                    return 'Description must contain at least 5 characters.';
                  }

                  return null;
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                Navigator.of(dialogContext).pop(reasonController.text.trim());
              },
              child: const Text('Request changes'),
            ),
          ],
        );
      },
    );

    reasonController.dispose();

    if (reason == null || !mounted) {
      return;
    }

    final success = await _viewModel.requestChanges(
      therapistId: widget.therapistId,
      reason: reason,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Therapist application returned for changes.'),
        ),
      );

      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_viewModel.isLoading && _viewModel.therapist == null) {
      return const Scaffold(
        body: AppLoadingState(message: 'Loading therapist application...'),
      );
    }

    final therapist = _viewModel.therapist;

    if (therapist == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Therapist verification')),
        body: AppErrorPanel(
          message: _viewModel.errorMessage ?? 'Therapist could not be loaded.',
          onRetry: () {
            _viewModel.load(widget.therapistId);
          },
          retryLabel: 'Try again',
        ),
      );
    }

    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    final birthFormatter = DateFormat('dd.MM.yyyy.');

    final imageUrl = _fileUrl(therapist.profileImageUrl);

    final isPending = therapist.verificationStatus.toLowerCase() == 'pending';

    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Therapist verification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 55,
                          backgroundImage: imageUrl == null
                              ? null
                              : NetworkImage(imageUrl),
                          child: imageUrl == null
                              ? Text(
                                  therapist.fullName.isEmpty
                                      ? '?'
                                      : therapist.fullName[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 34),
                                )
                              : null,
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                therapist.fullName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                therapist.specialization,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: colors.onSurfaceVariant),
                              ),
                              const SizedBox(height: 8),
                              _VerificationStatusBadge(
                                status: therapist.verificationStatus,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _InfoRow(label: 'Email', value: therapist.email),
                        _InfoRow(
                          label: 'Phone',
                          value: therapist.phoneNumber?.isNotEmpty == true
                              ? therapist.phoneNumber!
                              : 'Not provided',
                        ),
                        _InfoRow(
                          label: 'Date of birth',
                          value: birthFormatter.format(therapist.dateOfBirth),
                        ),
                        _InfoRow(
                          label: 'Experience',
                          value: '${therapist.experienceYears} years',
                        ),
                        _InfoRow(
                          label: 'Hourly rate',
                          value:
                              '${therapist.hourlyRate.toStringAsFixed(2)} KM',
                        ),
                        _InfoRow(
                          label: 'Registered',
                          value: formatter.format(
                            therapist.registeredAtUtc.toLocal(),
                          ),
                        ),
                        if (therapist.decisionAtUtc != null)
                          _InfoRow(
                            label: 'Decision date',
                            value: formatter.format(
                              therapist.decisionAtUtc!.toLocal(),
                            ),
                          ),
                        if (therapist.decisionByAdminName?.trim().isNotEmpty ==
                            true)
                          _InfoRow(
                            label: 'Decision by',
                            value: therapist.decisionByAdminName!,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Biography',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(therapist.biography),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Education',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      therapist.education.trim().isEmpty
                          ? 'Education information was not provided.'
                          : therapist.education,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Therapy approaches',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: therapist.therapyApproaches.isEmpty
                        ? const Text('No therapy approaches selected.')
                        : Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: therapist.therapyApproaches
                                .map(
                                  (approach) => Tooltip(
                                    message: approach.description ?? '',
                                    child: Chip(label: Text(approach.name)),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Verification documents',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (therapist.documents.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('No documents uploaded.'),
                    ),
                  )
                else
                  ...therapist.documents.map(
                    (document) => Card(
                      child: ListTile(
                        leading: Icon(
                          document.contentType == 'application/pdf'
                              ? Icons.picture_as_pdf
                              : Icons.image,
                        ),
                        title: Text(document.fileName),
                        subtitle: Text(
                          formatter.format(document.createdAtUtc.toLocal()),
                        ),
                        trailing: OutlinedButton.icon(
                          onPressed: () {
                            _openFile(document.filePath);
                          },
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Open'),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                const Text(
                  'Verification audit',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (therapist.auditHistory.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('No verification changes recorded.'),
                    ),
                  )
                else
                  ...therapist.auditHistory.map(
                    (audit) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(
                          '${audit.previousStatus} → ${audit.newStatus}',
                        ),
                        subtitle: Text(
                          '${audit.adminName}\n'
                          '${formatter.format(audit.changedAtUtc.toLocal())}'
                          '${audit.notes?.isNotEmpty == true ? '\n${audit.notes}' : ''}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  ),
                if (_viewModel.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  AppErrorBanner(message: _viewModel.errorMessage!),
                ],
                if (isPending) ...[
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 14,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 220,
                        child: OutlinedButton.icon(
                          onPressed: _viewModel.isSubmitting ? null : _reject,
                          icon: const Icon(Icons.close),
                          label: const Text('Reject'),
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: OutlinedButton.icon(
                          onPressed: _viewModel.isSubmitting
                              ? null
                              : _requestChanges,
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Request changes'),
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: ElevatedButton.icon(
                          onPressed: _viewModel.isSubmitting ? null : _approve,
                          icon: const Icon(Icons.check),
                          label: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VerificationStatusBadge extends StatelessWidget {
  final String status;

  const _VerificationStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      'Approved' => AdminStatusTone.success,
      'Pending' => AdminStatusTone.warning,
      'RequiresChanges' => AdminStatusTone.warning,
      'Rejected' => AdminStatusTone.danger,
      _ => AdminStatusTone.neutral,
    };

    return AdminStatusBadge(label: status, tone: tone);
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;

        final labelWidget = Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        );

        final valueWidget = SelectableText(
          value,
          textAlign: compact ? TextAlign.left : TextAlign.right,
        );

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    labelWidget,
                    const SizedBox(height: 4),
                    valueWidget,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: labelWidget),
                    const SizedBox(width: 16),
                    Expanded(child: valueWidget),
                  ],
                ),
        );
      },
    );
  }
}
