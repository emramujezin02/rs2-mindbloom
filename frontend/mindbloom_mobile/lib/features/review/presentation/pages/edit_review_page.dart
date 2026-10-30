import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/validation/app_validators.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../data/models/review_model.dart';
import '../viewmodels/create_review_viewmodel.dart';

class EditReviewPage extends StatefulWidget {
  final ReviewModel review;
  final CreateReviewViewModel? viewModel;

  const EditReviewPage({super.key, this.viewModel, required this.review});

  @override
  State<EditReviewPage> createState() => _EditReviewPageState();
}

class _EditReviewPageState extends State<EditReviewPage> {
  late final CreateReviewViewModel _viewModel;
  bool _shareAuthorDemographics = false;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _commentController;

  late int _rating;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModel ?? AppInjection.createCreateReviewViewModel();
    _shareAuthorDemographics = widget.review.shareAuthorDemographics;

    _rating = widget.review.rating;
    _commentController = TextEditingController(text: widget.review.comment);

    _viewModel.addListener(_refresh);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_refresh);
    _commentController.dispose();
    _viewModel.dispose();

    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _save() async {
    if (_viewModel.isLoading || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final success = await _viewModel.updateReview(
      reviewId: widget.review.id,
      rating: _rating,
      shareAuthorDemographics: _shareAuthorDemographics,
      comment: _commentController.text.trim(),
    );

    if (!success && mounted) {
      _formKey.currentState?.validate();
    }

    if (!mounted || !success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _rating == widget.review.rating &&
                  _commentController.text.trim() == widget.review.comment
              ? 'Review privacy preferences updated.'
              : 'Review updated and submitted for moderation again.',
        ),
      ),
    );

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit review')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Changes to the rating or comment require moderation again. Privacy preferences can be changed at any time.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<int>(
                initialValue: _rating,
                decoration: const InputDecoration(
                  labelText: 'Rating',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(5, (index) {
                  final value = index + 1;

                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text('$value / 5'),
                  );
                }),
                onChanged: _viewModel.isLoading
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _rating = value;
                        });
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
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  return _viewModel.fieldError('Comment') ??
                      AppValidators.reviewComment(value);
                },
              ),
              CheckboxListTile(
                key: const Key('review-demographics-consent'),
                contentPadding: EdgeInsets.zero,
                value: _shareAuthorDemographics,
                onChanged: _viewModel.isLoading
                    ? null
                    : (value) => setState(
                        () => _shareAuthorDemographics = value ?? false,
                      ),
                title: const Text(
                  'Share my gender and age with this public review',
                ),
                subtitle: const Text(
                  'Optional. Shown only for adults with a public profile. You can withdraw consent by editing your review.',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_viewModel.error != null) ...[
                const SizedBox(height: 12),
                AppInlineError(
                  title: 'Review could not be updated',
                  error: _viewModel.error,
                  onRetry: _save,
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _viewModel.isLoading ? null : _save,
                icon: _viewModel.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _viewModel.isLoading ? 'Saving...' : 'Save changes',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
