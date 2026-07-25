import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../data/models/review_model.dart';
import '../viewmodels/create_review_viewmodel.dart';

class EditReviewPage extends StatefulWidget {
  final ReviewModel review;

  const EditReviewPage({super.key, required this.review});

  @override
  State<EditReviewPage> createState() => _EditReviewPageState();
}

class _EditReviewPageState extends State<EditReviewPage> {
  final CreateReviewViewModel _viewModel =
      AppInjection.createCreateReviewViewModel();

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _commentController;

  late int _rating;

  @override
  void initState() {
    super.initState();

    _rating = widget.review.rating;

    _commentController = TextEditingController(text: widget.review.comment);

    _viewModel.addListener(_refresh);
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await _viewModel.updateReview(
      reviewId: widget.review.id,
      rating: _rating,
      comment: _commentController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review updated and sent for moderation again.'),
        ),
      );

      Navigator.of(context).pop(true);
    }
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
                'Updating a review sends it through '
                'moderation again.',
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

                  return DropdownMenuItem(
                    value: value,
                    child: Text('$value / 5'),
                  );
                }),
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
