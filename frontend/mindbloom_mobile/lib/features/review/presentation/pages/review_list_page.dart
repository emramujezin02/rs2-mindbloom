import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
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

  Future<void> _loadMore() {
    return _viewModel.loadMore(widget.therapistId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.reviews.isEmpty) {
      return const AppLoadingWidget.skeleton(
        message: 'Loading reviews...',
        skeletonItemCount: 4,
      );
    }

    if (_viewModel.error != null && _viewModel.reviews.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: AppErrorWidget(
          title: 'Reviews could not be loaded',
          error: _viewModel.error,
          onRetry: _reload,
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
          if (_viewModel.error != null)
            AppInlineError(
              title: 'Reviews could not be refreshed',
              error: _viewModel.error,
              onRetry: _reload,
              margin: const EdgeInsets.only(bottom: 16),
            ),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.star, size: 42, color: Colors.amber),
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
              padding: EdgeInsets.symmetric(vertical: 28),
              child: AppInlineEmptyState(
                message: 'This therapist has no approved reviews yet.',
                icon: Icons.rate_review_outlined,
              ),
            )
          else
            ..._viewModel.reviews.map(
              (review) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ReviewCard(review: review),
              ),
            ),

          if (_viewModel.isLoadingMore)
            const AppLoadMoreIndicator(
              loadingMessage: 'Loading more reviews...',
            )
          else if (_viewModel.loadMoreError != null)
            AppLoadMoreError(
              error: _viewModel.loadMoreError,
              fallbackMessage: 'More reviews could not be loaded.',
              onRetry: () {
                return _viewModel.retryLoadMore(widget.therapistId);
              },
            )
          else if (_viewModel.hasMore)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: OutlinedButton.icon(
                onPressed: _loadMore,
                icon: const Icon(Icons.expand_more),
                label: const Text('Load more reviews'),
              ),
            )
          else if (_viewModel.reviews.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'All reviews have been loaded.',
                textAlign: TextAlign.center,
              ),
            ),
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

    final normalizedClientName = review.clientName.trim();

    final displayedClientName = normalizedClientName.isEmpty
        ? 'Client'
        : normalizedClientName;

    final clientInitial = normalizedClientName.isEmpty
        ? '?'
        : normalizedClientName.substring(0, 1).toUpperCase();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(child: Text(clientInitial)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayedClientName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatter.format(review.createdAtUtc.toLocal()),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
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
              Text(review.therapistReply!.trim()),
            ],
          ],
        ),
      ),
    );
  }
}
