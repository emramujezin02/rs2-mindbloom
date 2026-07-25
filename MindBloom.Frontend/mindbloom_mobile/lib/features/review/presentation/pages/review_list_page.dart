import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../data/models/review_model.dart';
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
    _viewModel.dispose();

    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _reload() {
    return _viewModel.loadReviews(widget.therapistId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.error != null && _viewModel.reviews.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _viewModel.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _reload,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final rating = _viewModel.rating;

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.star, size: 42),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rating == null
                              ? '0.0 / 5'
                              : '${rating.averageRating.toStringAsFixed(1)} / 5',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rating == null
                              ? '0 approved reviews'
                              : '${rating.totalReviews} approved reviews',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (_viewModel.reviews.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Text(
                'This therapist has no approved reviews yet.',
                textAlign: TextAlign.center,
              ),
            )
          else
            ..._viewModel.reviews.map(
              (review) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ReviewCard(review: review),
              ),
            ),

          if (_viewModel.error != null && _viewModel.reviews.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _viewModel.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ],

          if (_viewModel.hasMore) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _viewModel.isLoadingMore
                  ? null
                  : () {
                      _viewModel.loadMore(widget.therapistId);
                    },
              child: _viewModel.isLoadingMore
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Load more reviews'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd.MM.yyyy.');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(
                    review.clientName.isEmpty ? '?' : review.clientName[0],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    review.clientName.isEmpty ? 'Client' : review.clientName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(formatter.format(review.createdAtUtc.toLocal())),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: List.generate(5, (index) {
                return Icon(
                  index < review.rating ? Icons.star : Icons.star_border,
                  size: 22,
                  color: Colors.amber,
                );
              }),
            ),

            const SizedBox(height: 10),

            Text(review.comment, style: const TextStyle(height: 1.4)),

            if (review.therapistReply != null &&
                review.therapistReply!.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(),
              const Text(
                'Therapist reply',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(review.therapistReply!),
            ],
          ],
        ),
      ),
    );
  }
}
