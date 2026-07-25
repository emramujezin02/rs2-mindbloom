import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../appointment/data/models/appointment_model.dart';
import '../viewmodels/create_review_viewmodel.dart';

class CreateReviewPage extends StatefulWidget {
  final AppointmentModel appointment;

  const CreateReviewPage({super.key, required this.appointment});

  @override
  State<CreateReviewPage> createState() => _CreateReviewPageState();
}

class _CreateReviewPageState extends State<CreateReviewPage> {
  final CreateReviewViewModel _viewModel =
      AppInjection.createCreateReviewViewModel();

  final _formKey = GlobalKey<FormState>();

  final _commentController = TextEditingController();

  int _rating = 5;

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_refresh);

    _viewModel.checkEligibility(widget.appointment.id);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_refresh);
    _viewModel.dispose();
    _commentController.dispose();

    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await _viewModel.createReview(
      appointmentId: widget.appointment.id,
      rating: _rating,
      comment: _commentController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review submitted and sent for moderation.'),
        ),
      );

      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave review')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isCheckingEligibility) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.error != null && _viewModel.eligibility == null) {
      return _MessageState(
        icon: Icons.error_outline,
        message: _viewModel.error!,
        buttonText: 'Try again',
        onPressed: () {
          _viewModel.checkEligibility(widget.appointment.id);
        },
      );
    }

    final eligibility = _viewModel.eligibility;

    if (eligibility == null) {
      return const _MessageState(
        icon: Icons.error_outline,
        message: 'Review eligibility could not be determined.',
      );
    }

    if (!eligibility.canReview) {
      return _MessageState(
        icon: eligibility.existingReviewId != null
            ? Icons.rate_review_outlined
            : Icons.lock_outline,
        message: eligibility.message,
        secondaryMessage: eligibility.moderationStatus == null
            ? null
            : 'Moderation status: '
                  '${eligibility.moderationStatus}',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.appointment.therapistName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            const Text(
              'Your review will become public only '
              'after administrator approval.',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            const Text('Rating', style: TextStyle(fontWeight: FontWeight.bold)),

            const SizedBox(height: 8),

            DropdownButtonFormField<int>(
              initialValue: _rating,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 - Very bad')),
                DropdownMenuItem(value: 2, child: Text('2 - Bad')),
                DropdownMenuItem(value: 3, child: Text('3 - Okay')),
                DropdownMenuItem(value: 4, child: Text('4 - Good')),
                DropdownMenuItem(value: 5, child: Text('5 - Excellent')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _rating = value;
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _commentController,
              minLines: 4,
              maxLines: 7,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Comment',
                hintText: 'Describe your experience with the therapist.',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                final comment = value?.trim() ?? '';

                if (comment.isEmpty) {
                  return 'Comment is required.';
                }

                if (comment.length > 1000) {
                  return 'Comment may contain at most '
                      '1000 characters.';
                }

                return null;
              },
            ),

            if (_viewModel.error != null) ...[
              const SizedBox(height: 12),
              Text(
                _viewModel.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ],

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _viewModel.isLoading ? null : _submitReview,
              icon: _viewModel.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.star),
              label: Text(
                _viewModel.isLoading ? 'Submitting...' : 'Submit review',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? secondaryMessage;
  final String? buttonText;
  final VoidCallback? onPressed;

  const _MessageState({
    required this.icon,
    required this.message,
    this.secondaryMessage,
    this.buttonText,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64),

            const SizedBox(height: 16),

            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17),
            ),

            if (secondaryMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                secondaryMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],

            if (buttonText != null && onPressed != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(onPressed: onPressed, child: Text(buttonText!)),
            ],
          ],
        ),
      ),
    );
  }
}
