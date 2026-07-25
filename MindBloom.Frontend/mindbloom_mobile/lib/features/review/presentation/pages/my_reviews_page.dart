import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
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

  Future<void> _openEdit(ReviewModel review) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditReviewPage(review: review)),
    );

    if (updated == true && mounted) {
      await _viewModel.loadReviews();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My reviews')),
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
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _viewModel.loadReviews,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _viewModel.loadReviews,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_viewModel.reviews.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Text(
                'You have not submitted any reviews yet.',
                textAlign: TextAlign.center,
              ),
            )
          else
            ..._viewModel.reviews.map(
              (review) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ReviewCard(
                  review: review,
                  onEdit: review.canEdit ? () => _openEdit(review) : null,
                ),
              ),
            ),

          if (_viewModel.error != null && _viewModel.reviews.isNotEmpty) ...[
            Text(
              _viewModel.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 12),
          ],

          if (_viewModel.hasMore)
            OutlinedButton(
              onPressed: _viewModel.isLoadingMore ? null : _viewModel.loadMore,
              child: _viewModel.isLoadingMore
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Load more'),
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

    final therapistName = review.therapistName.isEmpty
        ? 'Therapist'
        : review.therapistName;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                Chip(
                  avatar: Icon(
                    review.isApproved
                        ? Icons.check_circle
                        : Icons.hourglass_top,
                    size: 18,
                  ),
                  label: Text(review.moderationStatus),
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

            Text(
              formatter.format(review.createdAtUtc.toLocal()),
              style: Theme.of(context).textTheme.bodySmall,
            ),

            if (review.moderationReason != null &&
                review.moderationReason!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Moderation note: '
                '${review.moderationReason}',
              ),
            ],

            if (review.therapistReply != null &&
                review.therapistReply!.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Therapist reply',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(review.therapistReply!),
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
