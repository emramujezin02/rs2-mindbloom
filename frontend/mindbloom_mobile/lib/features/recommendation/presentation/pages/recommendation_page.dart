import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../../therapist/presentation/widgets/therapist_profile_image.dart';
import '../../data/models/recommendation_reason_model.dart';
import '../../data/models/therapist_recommendation_model.dart';
import '../viewmodels/recommendation_viewmodel.dart';

const _recommendationBackground = Color(0xFFFCFAFF);
const _recommendationLavender = Color(0xFFF5EFFC);
const _recommendationSurface = Color(0xFFFFFFFF);
const _recommendationTint = Color(0xFFFAF7FE);
const _recommendationBorder = Color(0xFFE8DEF3);
const _recommendationPrimary = Color(0xFF6D4F91);
const _recommendationText = Color(0xFF3E3152);
const _recommendationBody = Color(0xFF625B6B);
const _recommendationRadius = 20.0;

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

    _viewModel.dispose();

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

  Future<void> _editPreferences() async {
    final result = await Navigator.of(context).pushNamed(AppRouter.onboarding);

    if (!mounted || result != true) {
      return;
    }

    await _viewModel.loadRecommendations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _recommendationBackground,
      appBar: AppBar(
        title: const Text('Recommended therapists'),
        backgroundColor: _recommendationBackground,
        foregroundColor: _recommendationText,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _viewModel.isLoading ? null : _editPreferences,
            tooltip: 'Edit preferences',
            icon: const Icon(Icons.tune),
          ),
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
    if (_viewModel.isLoading && _viewModel.recommendations.isEmpty) {
      return const AppLoadingWidget.skeleton(
        message: 'Finding the best therapists...',
        skeletonItemCount: 4,
        padding: EdgeInsets.fromLTRB(16, 14, 16, 16),
      );
    }

    if (_viewModel.error != null && _viewModel.recommendations.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: AppErrorWidget(
          title: 'Recommendations could not be loaded',
          error: _viewModel.error,
          onRetry: _refresh,
        ),
      );
    }

    if (_viewModel.recommendations.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: AppEmptyStateWidget(
          title: 'No recommendations',
          message:
              'Complete or update your preferences to receive therapist recommendations.',
          icon: Icons.psychology_outlined,
          actionLabel: 'Edit preferences',
          onAction: _editPreferences,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _RecommendationHeader(
            recommendationCount: _viewModel.recommendations.length,
            onEditPreferences: _viewModel.isLoading ? null : _editPreferences,
          ),
          if (_viewModel.error != null)
            AppInlineError(
              title: 'Recommendations could not be refreshed',
              error: _viewModel.error,
              onRetry: _refresh,
              margin: const EdgeInsets.only(bottom: 12),
            ),
          ..._viewModel.recommendations.map(
            (recommendation) => _RecommendationCard(
              recommendation: recommendation,
              onOpenProfile: () {
                Navigator.of(context).pushNamed(
                  AppRouter.therapistDetails,
                  arguments: recommendation.therapistId,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationHeader extends StatelessWidget {
  final int recommendationCount;
  final VoidCallback? onEditPreferences;

  const _RecommendationHeader({
    required this.recommendationCount,
    required this.onEditPreferences,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _recommendationLavender,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _recommendationBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9DFFF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: _recommendationPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Therapists selected for you',
                      style: TextStyle(
                        color: _recommendationText,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$recommendationCount recommendation'
                      '${recommendationCount == 1 ? '' : 's'} found',
                      style: const TextStyle(
                        color: _recommendationPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Recommendations are calculated using your preferences, therapist experience, rating, availability and previous activity.',
            style: TextStyle(color: _recommendationBody, height: 1.45),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onEditPreferences,
            icon: const Icon(Icons.tune),
            label: const Text('Edit preferences'),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final TherapistRecommendationModel recommendation;
  final VoidCallback onOpenProfile;

  const _RecommendationCard({
    required this.recommendation,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: _recommendationSurface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_recommendationRadius),
        side: const BorderSide(color: _recommendationBorder),
      ),
      child: InkWell(
        onTap: onOpenProfile,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RecommendationTherapistHeader(recommendation: recommendation),
              const SizedBox(height: 14),
              _RecommendationScore(recommendation: recommendation),
              const SizedBox(height: 14),
              _RecommendationDetails(recommendation: recommendation),
              if (recommendation.reasons.isNotEmpty) ...[
                const SizedBox(height: 10),
                _RecommendationReasons(reasons: recommendation.reasons),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onOpenProfile,
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
}

class _RecommendationTherapistHeader extends StatelessWidget {
  final TherapistRecommendationModel recommendation;

  const _RecommendationTherapistHeader({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final specialization = recommendation.specialization.trim().isEmpty
        ? 'Psychotherapist'
        : recommendation.specialization.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TherapistProfileImage(
          fullName: recommendation.fullName,
          profileImageUrl: recommendation.profileImageUrl,
          radius: 36,
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      recommendation.fullName.trim().isEmpty
                          ? 'Therapist'
                          : recommendation.fullName.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _recommendationText,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (recommendation.isFavorite) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.favorite,
                      color: _recommendationPrimary,
                      size: 22,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                specialization,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _recommendationPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              _InlineMetric(
                icon: Icons.star_rounded,
                iconColor: Color(0xFFF2B84B),
                text: recommendation.reviewCount == 0
                    ? 'No reviews'
                    : '${recommendation.averageRating.toStringAsFixed(1)} '
                          '(${recommendation.reviewCount})',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecommendationScore extends StatelessWidget {
  final TherapistRecommendationModel recommendation;

  const _RecommendationScore({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final progress = (recommendation.matchPercentage / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _recommendationTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _recommendationBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  color: _recommendationPrimary,
                  backgroundColor: const Color(0xFFE9DFFF),
                ),
                Text(
                  '${recommendation.matchPercentage}%',
                  style: const TextStyle(
                    color: _recommendationText,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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
                  style: TextStyle(
                    color: _recommendationText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Recommendation score: '
                  '${recommendation.score.toStringAsFixed(1)}/100',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _recommendationBody),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationDetails extends StatelessWidget {
  final TherapistRecommendationModel recommendation;

  const _RecommendationDetails({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MetaPill(
          icon: Icons.payments_outlined,
          label: '${recommendation.pricePerSession.toStringAsFixed(2)} KM',
        ),
        _MetaPill(
          icon: Icons.workspace_premium_outlined,
          label: recommendation.experienceYears == 1
              ? '1 year experience'
              : '${recommendation.experienceYears} years experience',
        ),
        if (recommendation.availableDays.isNotEmpty)
          _MetaPill(
            icon: Icons.calendar_month_outlined,
            label:
                '${recommendation.availableDays.length} available day'
                '${recommendation.availableDays.length == 1 ? '' : 's'}',
          ),
        if (recommendation.hasPreviousAppointment)
          const _MetaPill(icon: Icons.history, label: 'Previously booked'),
      ],
    );
  }
}

class _RecommendationReasons extends StatelessWidget {
  final List<RecommendationReasonModel> reasons;

  const _RecommendationReasons({required this.reasons});

  @override
  Widget build(BuildContext context) {
    final positiveReasons = reasons
        .where((reason) => reason.awardedPoints > 0)
        .take(3)
        .toList();

    final displayedReasons = positiveReasons.isNotEmpty
        ? positiveReasons
        : reasons.take(3).toList();

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        title: const Text(
          'Why this therapist?',
          style: TextStyle(
            color: _recommendationText,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: const Text(
          'Based on recommendation details from MindBloom',
          style: TextStyle(color: _recommendationBody),
        ),
        children: displayedReasons
            .map((reason) => _RecommendationReason(reason: reason))
            .toList(),
      ),
    );
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
              color: _recommendationPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (reason.criterion.trim().isNotEmpty) ...[
                  Text(
                    reason.criterion,
                    style: const TextStyle(
                      color: _recommendationText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  reason.explanation,
                  style: const TextStyle(
                    color: _recommendationBody,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${reason.awardedPoints.toStringAsFixed(1)}'
                  '/${reason.maximumPoints.toStringAsFixed(1)} points',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _recommendationBody,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _recommendationTint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _recommendationBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _recommendationPrimary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _recommendationBody,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color iconColor;

  const _InlineMetric({
    required this.icon,
    required this.text,
    this.iconColor = _recommendationPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 230),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _recommendationText,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
