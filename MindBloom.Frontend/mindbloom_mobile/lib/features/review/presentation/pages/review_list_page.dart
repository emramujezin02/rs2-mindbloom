import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../viewmodels/review_list_viewmodel.dart';

class ReviewListPage extends StatefulWidget {
  final int therapistId;

  const ReviewListPage({super.key, required this.therapistId});

  @override
  State<ReviewListPage> createState() => _ReviewListPageState();
}

class _ReviewListPageState extends State<ReviewListPage> {
  final ReviewListViewModel _viewModel = AppInjection.createReviewViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_refresh);

    _viewModel.loadReviews(widget.therapistId);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_refresh);

    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reviews")),
      body: _viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _viewModel.reviews.length,
              itemBuilder: (context, index) {
                final review = _viewModel.reviews[index];

                return Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          review.clientName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),

                        const SizedBox(height: 6),

                        Text("⭐ ${review.rating}"),

                        const SizedBox(height: 6),

                        Text(review.comment),

                        if (review.therapistReply != null) ...[
                          const Divider(),
                          const Text(
                            "Therapist reply",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(review.therapistReply!),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
