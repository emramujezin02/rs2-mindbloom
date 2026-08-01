import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../viewmodels/review_moderation_details_viewmodel.dart';

class ReviewModerationDetailsPage extends StatefulWidget {
  final int reviewId;

  const ReviewModerationDetailsPage({super.key, required this.reviewId});

  @override
  State<ReviewModerationDetailsPage> createState() =>
      _ReviewModerationDetailsPageState();
}

class _ReviewModerationDetailsPageState
    extends State<ReviewModerationDetailsPage> {
  final ReviewModerationDetailsViewModel _viewModel =
      AppInjection.createReviewModerationDetailsViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onChanged);

    _viewModel.load(widget.reviewId);
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

  Future<void> _approveReview() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Approve review'),
          content: const Text(
            'Approve this review for public display? '
            'The decision will be recorded in the moderation history.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.check),
              label: const Text('Approve'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await _viewModel.approveReview(widget.reviewId);

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review approved successfully.')),
      );
    }
  }

  Future<String?> _requestReason({
    required String title,
    required String hint,
  }) async {
    final controller = TextEditingController();

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                autofocus: true,
                minLines: 4,
                maxLines: 6,
                maxLength: 1000,
                decoration: InputDecoration(
                  labelText: 'Moderation reason',
                  hintText: hint,
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  final reason = value?.trim() ?? '';

                  if (reason.isEmpty) {
                    return 'Moderation reason is required.';
                  }

                  if (reason.length < 5) {
                    return 'Reason must contain at least 5 characters.';
                  }

                  if (reason.length > 1000) {
                    return 'Reason may contain at most 1000 characters.';
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

                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    return result;
  }

  Future<void> _rejectReview() async {
    final reason = await _requestReason(
      title: 'Reject review',
      hint: 'Explain why this review cannot be published.',
    );

    if (reason == null || !mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm rejection'),
          content: Text('Reject this review?\n\nReason: $reason'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('No'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.close),
              label: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await _viewModel.rejectReview(
      reviewId: widget.reviewId,
      reason: reason,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review rejected successfully.')),
      );
    }
  }

  Future<void> _hideReview() async {
    final reason = await _requestReason(
      title: 'Hide published review',
      hint: 'Explain why this published review must be hidden.',
    );

    if (reason == null || !mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm hiding review'),
          content: Text(
            'This review is currently public. '
            'It will no longer be publicly visible.\n\n'
            'Reason: $reason',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('No'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.visibility_off),
              label: const Text('Hide review'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await _viewModel.hideReview(
      reviewId: widget.reviewId,
      reason: reason,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review hidden successfully.')),
      );
    }
  }

  bool get _isPending {
    return _viewModel.review?.moderationStatus.trim().toLowerCase() ==
        'pending';
  }

  bool get _isApproved {
    return _viewModel.review?.moderationStatus.trim().toLowerCase() ==
        'approved';
  }

  bool get _isRejected {
    return _viewModel.review?.moderationStatus.trim().toLowerCase() ==
        'rejected';
  }

  bool get _isHidden {
    return _viewModel.review?.moderationStatus.trim().toLowerCase() == 'hidden';
  }

  @override
  Widget build(BuildContext context) {
    if (_viewModel.isLoading && _viewModel.review == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final review = _viewModel.review;

    if (review == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review details')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _viewModel.errorMessage ?? 'Review could not be loaded.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    _viewModel.load(widget.reviewId);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text('Review #${review.id}'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _viewModel.isProcessing
                ? null
                : () {
                    _viewModel.load(widget.reviewId);
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_viewModel.errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _viewModel.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _DetailsCard(
                      title: 'Review',
                      rows: {
                        'Review ID': review.id.toString(),
                        'Status': review.moderationStatus,
                        'Created': formatter.format(
                          review.createdAtUtc.toLocal(),
                        ),
                        'Rating': '${review.rating} / 5',
                      },
                    ),

                    _DetailsCard(
                      title: 'Appointment',
                      rows: {'Appointment ID': review.appointmentId.toString()},
                    ),

                    _DetailsCard(
                      title: 'Client',
                      rows: {
                        'Client ID': review.clientId.toString(),
                        'Name': review.clientName,
                        'Email': review.clientEmail,
                      },
                    ),

                    _DetailsCard(
                      title: 'Therapist',
                      rows: {
                        'Therapist ID': review.therapistId.toString(),
                        'Name': review.therapistName,
                        'Email': review.therapistEmail,
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                const Text(
                  'Client comment',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: SelectableText(
                      review.comment,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Therapist reply',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child:
                        review.therapistReply == null ||
                            review.therapistReply!.trim().isEmpty
                        ? const Text('The therapist has not replied.')
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(
                                review.therapistReply!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                              if (review.therapistReplyCreatedAtUtc !=
                                  null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  formatter.format(
                                    review.therapistReplyCreatedAtUtc!
                                        .toLocal(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                ),

                if (review.moderatedAtUtc != null ||
                    review.moderationReason != null) ...[
                  const SizedBox(height: 20),

                  const Text(
                    'Current moderation decision',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          _InfoRow(
                            label: 'Status',
                            value: review.moderationStatus,
                          ),

                          _InfoRow(
                            label: 'Administrator',
                            value:
                                review.moderatedByAdminName ?? 'Not recorded',
                          ),

                          _InfoRow(
                            label: 'Moderated at',
                            value: review.moderatedAtUtc == null
                                ? 'Not recorded'
                                : formatter.format(
                                    review.moderatedAtUtc!.toLocal(),
                                  ),
                          ),

                          _InfoRow(
                            label: 'Reason',
                            value:
                                review.moderationReason ?? 'No reason recorded',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                const Text(
                  'Moderation history',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                if (review.auditHistory.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('No moderation actions recorded.'),
                    ),
                  )
                else
                  ...review.auditHistory.map(
                    (audit) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(audit.action),
                        subtitle: Text(
                          '${audit.adminName} '
                          '(${audit.adminEmail})\n'
                          '${formatter.format(audit.performedAtUtc.toLocal())}\n'
                          'Reason: ${audit.reason}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                if (!review.isDeleted)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (_isPending || _isRejected)
                        ElevatedButton.icon(
                          onPressed: _viewModel.isProcessing
                              ? null
                              : _approveReview,
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Approve'),
                        ),

                      if (_isPending)
                        ElevatedButton.icon(
                          onPressed: _viewModel.isProcessing
                              ? null
                              : _rejectReview,
                          icon: const Icon(Icons.cancel),
                          label: const Text('Reject'),
                        ),

                      if (_isApproved)
                        ElevatedButton.icon(
                          onPressed: _viewModel.isProcessing
                              ? null
                              : _hideReview,
                          icon: const Icon(Icons.visibility_off),
                          label: const Text('Hide published review'),
                        ),

                      if (_isHidden)
                        const Chip(
                          avatar: Icon(Icons.visibility_off),
                          label: Text('Review is hidden'),
                        ),

                      if (_viewModel.isProcessing)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final String title;

  final Map<String, String> rows;

  const _DetailsCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 330,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const Divider(height: 24),

              ...rows.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 125,
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(child: SelectableText(entry.value)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;

  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),

          const SizedBox(width: 16),

          Expanded(child: SelectableText(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
