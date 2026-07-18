import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/constants/api_constants.dart';
import '../../data/models/recommendation_reason_model.dart';
import '../../data/models/therapist_recommendation_model.dart';
import '../viewmodels/recommendation_viewmodel.dart';

class RecommendationPage extends StatefulWidget {
  const RecommendationPage({super.key});

  @override
  State<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  final RecommendationViewModel _viewModel =
      AppInjection.createRecommendationViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);

    _viewModel.loadRecommendations();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refresh() async {
    await _viewModel.refresh();
  }

  String? _buildImageUrl(String? imagePath) {
    final value = imagePath?.trim() ?? '';

    if (value.isEmpty) {
      return null;
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    final normalizedPath = value.startsWith('/') ? value : '/$value';

    return '${ApiConstants.baseUrl}$normalizedPath';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommended therapists'),
        actions: [
          IconButton(
            onPressed: _viewModel.isLoading ? null : _refresh,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.error != null && _viewModel.recommendations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _viewModel.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _refresh,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_viewModel.recommendations.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 170),
            Icon(Icons.psychology_outlined, size: 70),
            SizedBox(height: 16),
            Center(child: Text('No therapist recommendations were found.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: _viewModel.recommendations.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const _RecommendationHeader();
          }

          final recommendation = _viewModel.recommendations[index - 1];

          return _RecommendationCard(
            recommendation: recommendation,
            imageUrl: _buildImageUrl(recommendation.profileImageUrl),
          );
        },
      ),
    );
  }
}

class _RecommendationHeader extends StatelessWidget {
  const _RecommendationHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(4, 8, 4, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Therapists selected for you',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Recommendations are calculated using your '
            'preferences, therapist experience, rating, '
            'availability and previous activity.',
            style: TextStyle(fontSize: 15, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final TherapistRecommendationModel recommendation;
  final String? imageUrl;

  const _RecommendationCard({
    required this.recommendation,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(
            AppRouter.therapistDetails,
            arguments: recommendation.therapistId,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTherapistHeader(context),
              const SizedBox(height: 16),
              _buildScore(context),
              const SizedBox(height: 14),
              _buildDetails(),
              if (recommendation.reasons.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildReasons(context),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      AppRouter.therapistDetails,
                      arguments: recommendation.therapistId,
                    );
                  },
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Open profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTherapistHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 32,
          foregroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
          child: imageUrl == null
              ? Text(
                  _buildInitials(recommendation.fullName),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recommendation.fullName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                recommendation.specialization.trim().isEmpty
                    ? 'Psychotherapist'
                    : recommendation.specialization,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.star, size: 19, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    recommendation.reviewCount == 0
                        ? 'No reviews'
                        : '${recommendation.averageRating.toStringAsFixed(1)} '
                              '(${recommendation.reviewCount})',
                  ),
                ],
              ),
            ],
          ),
        ),
        if (recommendation.isFavorite)
          const Icon(Icons.favorite, color: Colors.red),
      ],
    );
  }

  Widget _buildScore(BuildContext context) {
    final progress = (recommendation.matchPercentage / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(value: progress, strokeWidth: 6),
                Text(
                  '${recommendation.matchPercentage}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Match with your needs',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Recommendation score: '
                  '${recommendation.score.toStringAsFixed(1)}/100',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(
          avatar: const Icon(Icons.payments_outlined, size: 17),
          label: Text(
            '${recommendation.pricePerSession.toStringAsFixed(2)} KM',
          ),
        ),
        Chip(
          avatar: const Icon(Icons.workspace_premium_outlined, size: 17),
          label: Text('${recommendation.experienceYears} years of experience'),
        ),
        if (recommendation.availableDays.isNotEmpty)
          Chip(
            avatar: const Icon(Icons.calendar_month_outlined, size: 17),
            label: Text(
              '${recommendation.availableDays.length} available days',
            ),
          ),
        if (recommendation.hasPreviousAppointment)
          const Chip(
            avatar: Icon(Icons.history, size: 17),
            label: Text('Previously booked'),
          ),
      ],
    );
  }

  Widget _buildReasons(BuildContext context) {
    final positiveReasons = recommendation.reasons
        .where((reason) => reason.awardedPoints > 0)
        .take(3)
        .toList();

    if (positiveReasons.isEmpty) {
      return const SizedBox.shrink();
    }

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 4),
      title: const Text(
        'Why is this therapist recommended?',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      children: positiveReasons
          .map((reason) => _RecommendationReason(reason: reason))
          .toList(),
    );
  }

  String _buildInitials(String fullName) {
    final names = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((name) => name.isNotEmpty)
        .toList();

    if (names.isEmpty) {
      return 'T';
    }

    if (names.length == 1) {
      return names.first[0].toUpperCase();
    }

    return '${names.first[0]}${names.last[0]}'.toUpperCase();
  }
}

class _RecommendationReason extends StatelessWidget {
  final RecommendationReasonModel reason;

  const _RecommendationReason({required this.reason});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_circle_outline,
              size: 18,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reason.explanation),
                const SizedBox(height: 3),
                Text(
                  '${reason.awardedPoints.toStringAsFixed(1)}'
                  '/${reason.maximumPoints.toStringAsFixed(1)} points',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
