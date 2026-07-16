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

  Future<void> _deleteReview() async {
    final formKey = GlobalKey<FormState>();

    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove review'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: reasonController,
              autofocus: true,
              minLines: 4,
              maxLines: 6,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Moderation reason',
                hintText:
                    'Explain why this review violates the platform rules.',
                border: OutlineInputBorder(),
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

                return null;
              },
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
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    reasonController.dispose();

    if (reason == null || !mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm review removal'),
          content: const Text(
            'Are you sure you want to remove this review? '
            'The action will be recorded in the moderation audit.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Yes, remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await _viewModel.deleteReview(
      reviewId: widget.reviewId,
      reason: reason,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review removed successfully.')),
      );

      Navigator.of(context).pop(true);
    }
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
          child: Text(_viewModel.errorMessage ?? 'Review could not be loaded.'),
        ),
      );
    }

    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review details'),
        actions: [
          if (!review.isDeleted)
            IconButton(
              tooltip: 'Remove review',
              onPressed: _viewModel.isDeleting ? null : _deleteReview,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _InfoRow(label: 'Review ID', value: review.id.toString()),
                    _InfoRow(
                      label: 'Appointment ID',
                      value: review.appointmentId.toString(),
                    ),
                    _InfoRow(label: 'Client', value: review.clientName),
                    _InfoRow(label: 'Client email', value: review.clientEmail),
                    _InfoRow(label: 'Therapist', value: review.therapistName),
                    _InfoRow(
                      label: 'Therapist email',
                      value: review.therapistEmail,
                    ),
                    _InfoRow(
                      label: 'Created',
                      value: formatter.format(review.createdAtUtc.toLocal()),
                    ),
                    _InfoRow(
                      label: 'Status',
                      value: review.isDeleted ? 'Removed' : 'Active',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Rating',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      index < review.rating ? Icons.star : Icons.star_border,
                      size: 30,
                    ),
                  ),
                ),
              ),
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
                child: Text(
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
                          Text(
                            review.therapistReply!,
                            style: const TextStyle(fontSize: 16, height: 1.5),
                          ),
                          if (review.therapistReplyCreatedAtUtc != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              formatter.format(
                                review.therapistReplyCreatedAtUtc!.toLocal(),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
            if (review.isDeleted) ...[
              const SizedBox(height: 20),
              const Text(
                'Moderation information',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      _InfoRow(
                        label: 'Administrator',
                        value:
                            review.moderatedByAdminName ??
                            'Unknown administrator',
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
                        value: review.moderationReason ?? 'No reason recorded',
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Moderation audit',
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
                      '${audit.adminName} (${audit.adminEmail})\n'
                      '${formatter.format(audit.performedAtUtc.toLocal())}\n'
                      '${audit.reason}',
                    ),
                    isThreeLine: true,
                  ),
                ),
              ),
            if (_viewModel.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _viewModel.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            if (!review.isDeleted) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _viewModel.isDeleting ? null : _deleteReview,
                icon: _viewModel.isDeleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline),
                label: const Text('Remove review'),
              ),
            ],
          ],
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
          Expanded(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
