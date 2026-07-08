import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
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
  }

  @override
  void dispose() {
    _viewModel.removeListener(_refresh);
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
        const SnackBar(content: Text('Review submitted successfully.')),
      );

      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRouter.myAppointments, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = widget.appointment.status.toLowerCase() == 'completed';

    return Scaffold(
      appBar: AppBar(title: const Text('Leave review')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: isCompleted
            ? Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.appointment.therapistName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'Rating',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 8),

                    DropdownButtonFormField<int>(
                      initialValue: _rating,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 - Very bad')),
                        DropdownMenuItem(value: 2, child: Text('2 - Bad')),
                        DropdownMenuItem(value: 3, child: Text('3 - Okay')),
                        DropdownMenuItem(value: 4, child: Text('4 - Good')),
                        DropdownMenuItem(
                          value: 5,
                          child: Text('5 - Excellent'),
                        ),
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
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Comment',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Comment is required.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    if (_viewModel.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _viewModel.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),

                    ElevatedButton.icon(
                      onPressed: _viewModel.isLoading ? null : _submitReview,
                      icon: const Icon(Icons.star),
                      label: _viewModel.isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Submit review'),
                    ),
                  ],
                ),
              )
            : const Center(
                child: Text(
                  'You can leave a review only after completed appointments.',
                  textAlign: TextAlign.center,
                ),
              ),
      ),
    );
  }
}
