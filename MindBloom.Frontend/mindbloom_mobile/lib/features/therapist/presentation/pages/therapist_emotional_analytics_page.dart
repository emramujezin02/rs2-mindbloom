import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../data/models/emotion_analytics_item_model.dart';
import '../../data/models/mood_trend_point_model.dart';
import '../../data/models/therapist_mood_trend_model.dart';
import '../viewmodels/therapist_emotional_analytics_viewmodel.dart';

class TherapistEmotionalAnalyticsPage extends StatefulWidget {
  final int clientId;
  final String? clientName;

  const TherapistEmotionalAnalyticsPage({
    super.key,
    required this.clientId,
    this.clientName,
  });

  @override
  State<TherapistEmotionalAnalyticsPage> createState() =>
      _TherapistEmotionalAnalyticsPageState();
}

class _TherapistEmotionalAnalyticsPageState
    extends State<TherapistEmotionalAnalyticsPage> {
  late final TherapistEmotionalAnalyticsViewModel viewModel;

  @override
  void initState() {
    super.initState();

    viewModel = AppInjection.createTherapistEmotionalAnalyticsViewModel();

    viewModel.addListener(_onViewModelChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      viewModel.loadAnalytics(clientId: widget.clientId);
    });
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    viewModel.removeListener(_onViewModelChanged);

    viewModel.dispose();

    super.dispose();
  }

  Future<void> _refresh() {
    return viewModel.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF40334D)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Emotional Analytics',
              style: TextStyle(
                color: Color(0xFF40334D),
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (widget.clientName?.trim().isNotEmpty == true)
              Text(
                widget.clientName!.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF756D79),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh analytics',
            onPressed: viewModel.isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _refresh, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (viewModel.isLoading && viewModel.analytics == null) {
      return const AppLoadingWidget.skeleton(
        message: 'Loading emotional analytics...',
        skeletonItemCount: 5,
      );
    }

    if (viewModel.errorMessage != null && viewModel.analytics == null) {
      return AppErrorWidget(
        title: 'Analytics could not be loaded',
        error: viewModel.errorMessage,
        onRetry: _refresh,
      );
    }

    final analytics = viewModel.analytics;

    if (analytics == null) {
      return AppEmptyStateWidget(
        title: 'Analytics unavailable',
        message: 'Emotional analytics are not available for this client.',
        icon: Icons.insights_outlined,
        actionLabel: 'Refresh',
        onAction: _refresh,
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AnalyticsIntroductionCard(analytics: analytics),
                const SizedBox(height: 18),
                _PeriodFilter(
                  selectedPeriod: viewModel.selectedPeriod,
                  isLoading: viewModel.isLoading,
                  periods:
                      TherapistEmotionalAnalyticsViewModel.availablePeriods,
                  onSelected: viewModel.changePeriod,
                ),
                if (viewModel.isLoading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(minHeight: 3),
                ],
                if (viewModel.errorMessage != null) ...[
                  const SizedBox(height: 14),
                  AppInlineError(
                    title: 'Analytics could not be refreshed',
                    error: viewModel.errorMessage,
                    onRetry: _refresh,
                  ),
                ],
                const SizedBox(height: 18),
                if (!analytics.hasData)
                  AppEmptyStateWidget(
                    title: 'No analytics data',
                    message:
                        'The client has not recorded any mood or emotion entries '
                        'during the last ${analytics.days} days.',
                    icon: Icons.insights_outlined,
                    actionLabel: 'Refresh',
                    onAction: _refresh,
                  )
                else ...[
                  _AnalyticsSummarySection(analytics: analytics),
                  const SizedBox(height: 18),
                  _MoodLineChartCard(analytics: analytics),
                  const SizedBox(height: 18),
                  _EmotionAnalyticsCard(analytics: analytics),
                  const SizedBox(height: 18),
                  _TrendExplanationCard(analytics: analytics),
                  const SizedBox(height: 14),
                  const _AnalyticsPrivacyNotice(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AnalyticsIntroductionCard extends StatelessWidget {
  final TherapistMoodTrendModel analytics;

  const _AnalyticsIntroductionCard({required this.analytics});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5DBEF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE5FA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.analytics_outlined,
              color: Color(0xFF72559A),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Client emotional overview',
                  style: TextStyle(
                    color: Color(0xFF40334D),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _buildPeriodDescription(analytics),
                  style: const TextStyle(
                    color: Color(0xFF756D79),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildPeriodDescription(TherapistMoodTrendModel analytics) {
    final from = analytics.fromUtc?.toLocal();

    final to = analytics.toUtc?.toLocal();

    if (from == null || to == null) {
      return 'Analytics for the last '
          '${analytics.days} days.';
    }

    return 'Analytics from '
        '${_formatDate(from)} to '
        '${_formatDate(to)}.';
  }
}

class _PeriodFilter extends StatelessWidget {
  final int selectedPeriod;
  final bool isLoading;
  final List<int> periods;
  final ValueChanged<int> onSelected;

  const _PeriodFilter({
    required this.selectedPeriod,
    required this.isLoading,
    required this.periods,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5DBEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.date_range_outlined, color: Color(0xFF72559A)),
              SizedBox(width: 9),
              Text(
                'Analytics period',
                style: TextStyle(
                  color: Color(0xFF40334D),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: periods.map((period) {
              final selected = selectedPeriod == period;

              return ChoiceChip(
                selected: selected,
                label: Text(_periodLabel(period)),
                onSelected: isLoading
                    ? null
                    : (_) {
                        onSelected(period);
                      },
                showCheckmark: false,
                backgroundColor: const Color(0xFFF7F3FB),
                selectedColor: const Color(0xFFE4D8F4),
                side: BorderSide(
                  color: selected
                      ? const Color(0xFF8063A4)
                      : const Color(0xFFE5DBEF),
                ),
                labelStyle: TextStyle(
                  color: selected
                      ? const Color(0xFF624683)
                      : const Color(0xFF756D79),
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsSummarySection extends StatelessWidget {
  final TherapistMoodTrendModel analytics;

  const _AnalyticsSummarySection({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _AnalyticsSummaryData(
        title: 'Average mood',
        value: analytics.averageMood == null
            ? '—'
            : '${analytics.averageMood!.toStringAsFixed(1)}/5',
        description: '${analytics.totalEntries} recorded entries',
        icon: Icons.sentiment_satisfied_alt,
      ),
      _AnalyticsSummaryData(
        title: 'Emotional trend',
        value: _formatTrend(analytics.trend),
        description: _trendDifferenceText(analytics.trendDifference),
        icon: _trendIcon(analytics.trend),
      ),
      _AnalyticsSummaryData(
        title: 'Main emotion',
        value: analytics.mostFrequentEmotion?.trim().isNotEmpty == true
            ? analytics.mostFrequentEmotion!
            : 'Not available',
        description: '${analytics.emotions.length} different emotions',
        icon: Icons.favorite_outline,
      ),
      _AnalyticsSummaryData(
        title: 'Selected period',
        value: _periodLabel(analytics.days),
        description: _shortPeriodRange(analytics),
        icon: Icons.calendar_today_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 850
            ? 4
            : constraints.maxWidth >= 560
            ? 2
            : 1;

        const spacing = 12.0;

        final cardWidth =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards.map((item) {
            return SizedBox(
              width: cardWidth,
              child: _AnalyticsSummaryCard(data: item),
            );
          }).toList(),
        );
      },
    );
  }
}

class _AnalyticsSummaryCard extends StatelessWidget {
  final _AnalyticsSummaryData data;

  const _AnalyticsSummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 126),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE6DCEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 41,
                height: 41,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE5FA),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  data.icon,
                  size: 22,
                  color: const Color(0xFF72559A),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  data.title,
                  style: const TextStyle(
                    color: Color(0xFF756D79),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF40334D),
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF756D79),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodLineChartCard extends StatelessWidget {
  final TherapistMoodTrendModel analytics;

  const _MoodLineChartCard({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final points = analytics.points;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5DBEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.show_chart, color: Color(0xFF72559A)),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Mood trend graph',
                  style: TextStyle(
                    color: Color(0xFF40334D),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Average mood score by day. '
            'The scale ranges from 1 to 5.',
            style: TextStyle(color: Color(0xFF756D79), height: 1.4),
          ),
          const SizedBox(height: 24),
          if (points.isEmpty)
            const SizedBox(
              height: 230,
              child: Center(
                child: Text(
                  'There are no mood entries '
                  'for the selected period.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF756D79)),
                ),
              ),
            )
          else
            SizedBox(
              height: 270,
              child: LineChart(
                _buildLineChartData(points),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
              ),
            ),
          if (points.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                _MoodScaleLabel(value: '1', label: 'Very low'),
                _MoodScaleLabel(value: '3', label: 'Neutral'),
                _MoodScaleLabel(value: '5', label: 'Very good'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  LineChartData _buildLineChartData(List<MoodTrendPointModel> points) {
    final spots = List<FlSpot>.generate(points.length, (index) {
      return FlSpot(
        index.toDouble(),
        points[index].averageMood.clamp(1.0, 5.0).toDouble(),
      );
    });

    final titleInterval = _calculateTitleInterval(points.length);

    return LineChartData(
      minX: 0,
      maxX: math.max(points.length - 1, 1).toDouble(),
      minY: 1,
      maxY: 5,
      clipData: const FlClipData.all(),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 1,
        getDrawingHorizontalLine: (value) {
          return const FlLine(color: Color(0xFFE9E1F0), strokeWidth: 1);
        },
      ),
      borderData: FlBorderData(
        show: true,
        border: const Border(
          left: BorderSide(color: Color(0xFFDCD1E7)),
          bottom: BorderSide(color: Color(0xFFDCD1E7)),
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            interval: 1,
            getTitlesWidget: (value, meta) {
              if (value < 1 || value > 5) {
                return const SizedBox.shrink();
              }

              return SideTitleWidget(
                meta: meta,
                child: Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: Color(0xFF756D79),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 38,
            interval: titleInterval.toDouble(),
            getTitlesWidget: (value, meta) {
              final index = value.round();

              if (index < 0 || index >= points.length) {
                return const SizedBox.shrink();
              }

              if (index % titleInterval != 0 && index != points.length - 1) {
                return const SizedBox.shrink();
              }

              final date = points[index].dateUtc.toLocal();

              return SideTitleWidget(
                meta: meta,
                space: 8,
                child: Text(
                  _formatShortDate(date),
                  style: const TextStyle(
                    color: Color(0xFF756D79),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        enabled: true,
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => const Color(0xFF51405F),
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final index = spot.x.round();

              if (index < 0 || index >= points.length) {
                return null;
              }

              final point = points[index];

              return LineTooltipItem(
                '${_formatDate(point.dateUtc.toLocal())}\n'
                '${point.averageMood.toStringAsFixed(1)}/5'
                ' • ${point.entryCount} '
                '${point.entryCount == 1 ? 'entry' : 'entries'}',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              );
            }).toList();
          },
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: points.length > 2,
          curveSmoothness: 0.25,
          color: const Color(0xFF72559A),
          barWidth: 3,
          isStrokeCapRound: true,
          preventCurveOverShooting: true,
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF72559A).withValues(alpha: 0.24),
                const Color(0xFF72559A).withValues(alpha: 0.02),
              ],
            ),
          ),
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 4.5,
                color: const Color(0xFF72559A),
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            },
          ),
        ),
      ],
    );
  }

  int _calculateTitleInterval(int length) {
    if (length <= 7) {
      return 1;
    }

    if (length <= 15) {
      return 2;
    }

    if (length <= 31) {
      return 5;
    }

    if (length <= 90) {
      return 10;
    }

    return math.max(1, (length / 6).ceil());
  }
}

class _MoodScaleLabel extends StatelessWidget {
  final String value;
  final String label;

  const _MoodScaleLabel({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 23,
          height: 23,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFEDE5FA),
            shape: BoxShape.circle,
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF72559A),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF756D79), fontSize: 11),
        ),
      ],
    );
  }
}

class _EmotionAnalyticsCard extends StatelessWidget {
  final TherapistMoodTrendModel analytics;

  const _EmotionAnalyticsCard({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final emotions = analytics.emotions;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5DBEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.favorite_border, color: Color(0xFF72559A)),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Emotion distribution',
                  style: TextStyle(
                    color: Color(0xFF40334D),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Distribution of recorded emotions '
            'during the selected period.',
            style: TextStyle(color: Color(0xFF756D79), height: 1.4),
          ),
          const SizedBox(height: 22),
          if (emotions.isEmpty)
            const SizedBox(
              height: 180,
              child: Center(
                child: Text(
                  'No emotions were recorded '
                  'during this period.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF756D79)),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 720;

                final chart = _EmotionPieChart(emotions: emotions);

                final list = _EmotionDistributionList(emotions: emotions);

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: math.min(300, constraints.maxWidth * 0.42),
                        height: 300,
                        child: chart,
                      ),
                      const SizedBox(width: 28),
                      Expanded(child: list),
                    ],
                  );
                }

                return Column(
                  children: [
                    SizedBox(width: double.infinity, height: 280, child: chart),
                    const SizedBox(height: 20),
                    list,
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _EmotionPieChart extends StatelessWidget {
  final List<EmotionAnalyticsItemModel> emotions;

  const _EmotionPieChart({required this.emotions});

  static const List<Color> _sectionColors = [
    Color(0xFF72559A),
    Color(0xFF9A78BE),
    Color(0xFFB995D2),
    Color(0xFF9675A9),
    Color(0xFF8063A4),
    Color(0xFFC5A9D8),
    Color(0xFF6B7EA8),
    Color(0xFFA77C8B),
  ];

  @override
  Widget build(BuildContext context) {
    final visible = emotions.take(8).toList();

    final total = visible.fold<int>(0, (sum, item) => sum + item.count);

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 3,
            centerSpaceRadius: 66,
            startDegreeOffset: -90,
            pieTouchData: PieTouchData(enabled: true),
            sections: List<PieChartSectionData>.generate(visible.length, (
              index,
            ) {
              final item = visible[index];

              final percentage = total == 0 ? 0.0 : item.count * 100 / total;

              return PieChartSectionData(
                value: item.count.toDouble(),
                color: _sectionColors[index % _sectionColors.length],
                radius: 48,
                title: percentage >= 8
                    ? '${percentage.toStringAsFixed(0)}%'
                    : '',
                titleStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              );
            }),
          ),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              total.toString(),
              style: const TextStyle(
                color: Color(0xFF40334D),
                fontSize: 27,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Text(
              'emotions',
              style: TextStyle(color: Color(0xFF756D79), fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

class _EmotionDistributionList extends StatelessWidget {
  final List<EmotionAnalyticsItemModel> emotions;

  const _EmotionDistributionList({required this.emotions});

  static const List<Color> _indicatorColors = [
    Color(0xFF72559A),
    Color(0xFF9A78BE),
    Color(0xFFB995D2),
    Color(0xFF9675A9),
    Color(0xFF8063A4),
    Color(0xFFC5A9D8),
    Color(0xFF6B7EA8),
    Color(0xFFA77C8B),
  ];

  @override
  Widget build(BuildContext context) {
    final visible = emotions.take(8).toList();

    return Column(
      children: visible.asMap().entries.map((entry) {
        final index = entry.key;
        final emotion = entry.value;

        return Padding(
          padding: const EdgeInsets.only(bottom: 13),
          child: _EmotionDistributionItem(
            emotion: emotion,
            color: _indicatorColors[index % _indicatorColors.length],
          ),
        );
      }).toList(),
    );
  }
}

class _EmotionDistributionItem extends StatelessWidget {
  final EmotionAnalyticsItemModel emotion;
  final Color color;

  const _EmotionDistributionItem({required this.emotion, required this.color});

  @override
  Widget build(BuildContext context) {
    final normalizedPercentage = emotion.percentage.clamp(0, 100).toDouble();

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                emotion.emotion,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF40334D),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${emotion.count}',
              style: const TextStyle(
                color: Color(0xFF756D79),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 58,
              child: Text(
                '${normalizedPercentage.toStringAsFixed(1)}%',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFF72559A),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: LinearProgressIndicator(
            value: normalizedPercentage / 100,
            minHeight: 7,
            backgroundColor: const Color(0xFFF0EAF5),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _TrendExplanationCard extends StatelessWidget {
  final TherapistMoodTrendModel analytics;

  const _TrendExplanationCard({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final appearance = _trendAppearance(analytics.trend);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: appearance.background,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: appearance.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 47,
                height: 47,
                decoration: BoxDecoration(
                  color: appearance.iconBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(appearance.icon, color: appearance.foreground),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatTrend(analytics.trend),
                      style: TextStyle(
                        color: appearance.foreground,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _trendSummary(analytics),
                      style: TextStyle(
                        color: appearance.foreground,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (analytics.previousAverageMood != null &&
              analytics.recentAverageMood != null) ...[
            const SizedBox(height: 19),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 540;

                final previous = _TrendPeriodValue(
                  title: 'Earlier period',
                  value: analytics.previousAverageMood!,
                );

                final recent = _TrendPeriodValue(
                  title: 'Recent period',
                  value: analytics.recentAverageMood!,
                );

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(child: previous),
                      const SizedBox(width: 12),
                      Expanded(child: recent),
                    ],
                  );
                }

                return Column(
                  children: [previous, const SizedBox(height: 10), recent],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _TrendPeriodValue extends StatelessWidget {
  final String title;
  final double value;

  const _TrendPeriodValue({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF625B68),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${value.toStringAsFixed(2)}/5',
            style: const TextStyle(
              color: Color(0xFF40334D),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsPrivacyNotice extends StatelessWidget {
  const _AnalyticsPrivacyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7F3),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFD6E8DB)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.privacy_tip_outlined, color: Color(0xFF34734A)),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Analytics are calculated only '
              'from mood scores and emotion names. '
              'Private journal notes are never '
              'included or displayed.',
              style: TextStyle(color: Color(0xFF42634C), height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsSummaryData {
  final String title;
  final String value;
  final String description;
  final IconData icon;

  const _AnalyticsSummaryData({
    required this.title,
    required this.value,
    required this.description,
    required this.icon,
  });
}

class _TrendAppearance {
  final Color background;
  final Color border;
  final Color iconBackground;
  final Color foreground;
  final IconData icon;

  const _TrendAppearance({
    required this.background,
    required this.border,
    required this.iconBackground,
    required this.foreground,
    required this.icon,
  });
}

String _periodLabel(int days) {
  switch (days) {
    case 7:
      return '7 days';
    case 14:
      return '14 days';
    case 30:
      return '30 days';
    case 90:
      return '3 months';
    case 180:
      return '6 months';
    case 365:
      return '1 year';
    default:
      return '$days days';
  }
}

String _formatTrend(String value) {
  switch (value.trim().toLowerCase()) {
    case 'improving':
      return 'Improving';
    case 'declining':
      return 'Declining';
    case 'stable':
      return 'Stable';
    case 'insufficientdata':
    case 'insufficient_data':
      return 'Insufficient data';
    default:
      return value.trim().isEmpty ? 'Insufficient data' : value;
  }
}

IconData _trendIcon(String trend) {
  switch (trend.trim().toLowerCase()) {
    case 'improving':
      return Icons.trending_up;
    case 'declining':
      return Icons.trending_down;
    case 'stable':
      return Icons.trending_flat;
    default:
      return Icons.help_outline;
  }
}

String _trendDifferenceText(double? difference) {
  if (difference == null) {
    return 'Not enough data for comparison';
  }

  final prefix = difference > 0 ? '+' : '';

  return '$prefix${difference.toStringAsFixed(2)} '
      'mood points';
}

String _trendSummary(TherapistMoodTrendModel analytics) {
  final difference = analytics.trendDifference;

  switch (analytics.trend.trim().toLowerCase()) {
    case 'improving':
      return difference == null
          ? 'The recent mood average is higher '
                'than the earlier average.'
          : 'The recent mood average increased '
                'by ${difference.abs().toStringAsFixed(2)} points.';

    case 'declining':
      return difference == null
          ? 'The recent mood average is lower '
                'than the earlier average.'
          : 'The recent mood average decreased '
                'by ${difference.abs().toStringAsFixed(2)} points.';

    case 'stable':
      return 'The recent and earlier mood '
          'averages are relatively similar.';

    default:
      return 'At least two recorded days are '
          'required to calculate a meaningful trend.';
  }
}

_TrendAppearance _trendAppearance(String trend) {
  switch (trend.trim().toLowerCase()) {
    case 'improving':
      return const _TrendAppearance(
        background: Color(0xFFF0F8F2),
        border: Color(0xFFD0E7D5),
        iconBackground: Color(0xFFDDEFE1),
        foreground: Color(0xFF34734A),
        icon: Icons.trending_up,
      );

    case 'declining':
      return const _TrendAppearance(
        background: Color(0xFFFFF1F1),
        border: Color(0xFFF1D1D1),
        iconBackground: Color(0xFFF8DEDE),
        foreground: Color(0xFFA54242),
        icon: Icons.trending_down,
      );

    case 'stable':
      return const _TrendAppearance(
        background: Color(0xFFF3F0FA),
        border: Color(0xFFDDD3EC),
        iconBackground: Color(0xFFE5DDF1),
        foreground: Color(0xFF72559A),
        icon: Icons.trending_flat,
      );

    default:
      return const _TrendAppearance(
        background: Color(0xFFFFF8E9),
        border: Color(0xFFEEE0BC),
        iconBackground: Color(0xFFF5E8C8),
        foreground: Color(0xFF8A681B),
        icon: Icons.help_outline,
      );
  }
}

String _shortPeriodRange(TherapistMoodTrendModel analytics) {
  final from = analytics.fromUtc?.toLocal();

  final to = analytics.toUtc?.toLocal();

  if (from == null || to == null) {
    return 'Selected analytics range';
  }

  return '${_formatShortDate(from)} – '
      '${_formatShortDate(to)}';
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}.';
}

String _formatShortDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.';
}
