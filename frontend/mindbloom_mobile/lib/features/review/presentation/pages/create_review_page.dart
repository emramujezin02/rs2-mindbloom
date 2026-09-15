import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/validation/app_validators.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
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

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _commentController = TextEditingController();

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

  Future<void> _checkEligibility() {
    return _viewModel.checkEligibility(widget.appointment.id);
  }

  Future<void> _submitReview() async {
    if (_viewModel.isLoading || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final success = await _viewModel.createReview(
      appointmentId: widget.appointment.id,
      rating: _rating,
      comment: _commentController.text.trim(),
    );

    if (!success && mounted) {
      _formKey.currentState?.validate();
    }

    if (!mounted || !success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recenzija je poslana na moderaciju.')),
    );

    Navigator.of(context).pop(true);
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
      return const AppLoadingWidget(message: 'Checking review eligibility...');
    }

    if (_viewModel.error != null && _viewModel.eligibility == null) {
      return AppErrorWidget(
        title: 'Review eligibility could not be checked',
        error: _viewModel.error,
        onRetry: _checkEligibility,
      );
    }

    final eligibility = _viewModel.eligibility;

    if (eligibility == null) {
      return const AppEmptyStateWidget(
        title: 'Review unavailable',
        message: 'Review eligibility could not be determined.',
        icon: Icons.rate_review_outlined,
      );
    }

    if (!eligibility.canReview) {
      return AppEmptyStateWidget(
        title: 'Review unavailable',
        message: eligibility.message,
        icon: eligibility.existingReviewId != null
            ? Icons.rate_review_outlined
            : Icons.lock_outline,
        footer: eligibility.moderationStatus == null
            ? null
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Moderation status: '
                  '${eligibility.moderationStatus}',
                  textAlign: TextAlign.center,
                ),
              ),
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
              'Your review will become public only after administrator approval.',
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
              onChanged: _viewModel.isLoading
                  ? null
                  : (value) {
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
              enabled: !_viewModel.isLoading,
              decoration: const InputDecoration(
                labelText: 'Comment',
                hintText: 'Describe your experience with the therapist.',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                return _viewModel.fieldError('Comment') ??
                    AppValidators.reviewComment(value);
              },
            ),
            if (_viewModel.error != null) ...[
              const SizedBox(height: 12),
              AppInlineError(
                title: 'Review could not be submitted',
                error: _viewModel.error,
                onRetry: _submitReview,
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
