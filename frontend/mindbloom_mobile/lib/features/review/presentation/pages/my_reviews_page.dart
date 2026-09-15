import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../data/models/review_model.dart';
import '../viewmodels/my_reviews_viewmodel.dart';
import 'edit_review_page.dart';

class MyReviewsPage extends StatefulWidget {
  const MyReviewsPage({super.key});

  @override
  State<MyReviewsPage> createState() => _MyReviewsPageState();
}

class _MyReviewsPageState extends State<MyReviewsPage> {
  final MyReviewsViewModel _viewModel = AppInjection.createMyReviewsViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);
    _viewModel.loadReviews();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _reload() {
    return _viewModel.loadReviews();
  }

  Future<void> _openEdit(ReviewModel review) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditReviewPage(review: review)),
    );

    if (!mounted || updated != true) {
      return;
    }

    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My reviews')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.reviews.isEmpty) {
      return const AppLoadingWidget.skeleton(
        message: 'Loading your reviews...',
        skeletonItemCount: 4,
      );
    }

    if (_viewModel.error != null && _viewModel.reviews.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: AppErrorWidget(
          title: 'Your reviews could not be loaded',
          error: _viewModel.error,
          onRetry: _reload,
        ),
      );
    }

    if (_viewModel.reviews.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: const AppEmptyStateWidget(
          title: 'No reviews yet',
          message: 'You have not submitted any reviews yet.',
          icon: Icons.rate_review_outlined,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_viewModel.error != null)
            AppInlineError(
              title: 'Your reviews could not be refreshed',
              error: _viewModel.error,
              onRetry: _reload,
              margin: const EdgeInsets.only(bottom: 16),
            ),

          ..._viewModel.reviews.map(
            (review) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReviewCard(
                review: review,
                onEdit: review.canEdit
                    ? () {
                        _openEdit(review);
                      }
                    : null,
              ),
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
              onRetry: _viewModel.retryLoadMore,
            )
          else if (_viewModel.hasMore)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: OutlinedButton.icon(
                onPressed: _viewModel.loadMore,
                icon: const Icon(Icons.expand_more),
                label: const Text('Load more'),
              ),
            )
          else
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
  final VoidCallback? onEdit;

  const _ReviewCard({required this.review, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    final normalizedTherapistName = review.therapistName.trim();

    final therapistName = normalizedTherapistName.isEmpty
        ? 'Therapist'
        : normalizedTherapistName;

    final moderationReason = review.moderationReason?.trim();
    final therapistReply = review.therapistReply?.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(child: Icon(Icons.psychology)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    therapistName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _ModerationStatusChip(
                  isApproved: review.isApproved,
                  status: review.moderationStatus,
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

            Text(
              review.comment,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                const Icon(Icons.schedule, size: 16),
                const SizedBox(width: 6),
                Text(
                  formatter.format(review.createdAtUtc.toLocal()),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),

            if (moderationReason != null && moderationReason.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.errorContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Moderation note: $moderationReason')),
                  ],
                ),
              ),
            ],

            if (therapistReply != null && therapistReply.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.reply, size: 20),
                  SizedBox(width: 7),
                  Text(
                    'Therapist reply',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(therapistReply, style: const TextStyle(height: 1.4)),
            ],

            if (onEdit != null) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit review'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModerationStatusChip extends StatelessWidget {
  final bool isApproved;
  final String status;

  const _ModerationStatusChip({required this.isApproved, required this.status});

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = status.trim().isEmpty
        ? isApproved
              ? 'Approved'
              : 'Pending'
        : status.trim();

    final lowerStatus = normalizedStatus.toLowerCase();

    final isRejected =
        lowerStatus.contains('reject') ||
        lowerStatus.contains('declin') ||
        lowerStatus.contains('denied');

    final icon = isApproved
        ? Icons.check_circle
        : isRejected
        ? Icons.cancel
        : Icons.hourglass_top;

    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(normalizedStatus),
      visualDensity: VisualDensity.compact,
    );
  }
}
