import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../therapist/data/models/mood_trend_point_model.dart';
import '../../../therapist/data/models/therapist_mood_trend_model.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../viewmodels/client_emotional_analytics_viewmodel.dart';

const _analyticsBackground = Color(0xFFFCFAFF);
const _analyticsSurface = Color(0xFFFFFFFF);
const _analyticsLavender = Color(0xFFF6F0FC);
const _analyticsBorder = Color(0xFFE7DDF1);
const _analyticsPrimary = Color(0xFF6D4F91);
const _analyticsText = Color(0xFF372D45);
const _analyticsMuted = Color(0xFF6C6278);
const _analyticsRadius = 20.0;

class ClientEmotionalAnalyticsPage extends StatefulWidget {
  const ClientEmotionalAnalyticsPage({super.key});

  @override
  State<ClientEmotionalAnalyticsPage> createState() =>
      _ClientEmotionalAnalyticsPageState();
}

class _ClientEmotionalAnalyticsPageState
    extends State<ClientEmotionalAnalyticsPage> {
  final ClientEmotionalAnalyticsViewModel _viewModel =
      AppInjection.createClientEmotionalAnalyticsViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_refresh);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.loadInitial();
    });
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

  Future<void> _selectCustomPeriod() async {
    final now = DateTime.now();

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange:
          _viewModel.customFrom != null && _viewModel.customTo != null
          ? DateTimeRange(
              start: _viewModel.customFrom!,
              end: _viewModel.customTo!,
            )
          : DateTimeRange(
              start: now.subtract(const Duration(days: 29)),
              end: now,
            ),
    );

    if (range == null) {
      return;
    }

    final days = range.duration.inDays + 1;

    if (days > 365) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Custom period may contain at most 365 days.'),
        ),
      );

      return;
    }

    await _viewModel.selectCustom(from: range.start, to: range.end);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _analyticsBackground,
      appBar: AppBar(
        title: const Text('My emotional patterns'),
        backgroundColor: _analyticsBackground,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _viewModel.isLoading ? null : _viewModel.refresh,
            tooltip: 'Refresh analytics',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.analytics == null) {
      return const AppLoadingWidget.skeleton(
        message: 'Loading emotional analytics...',
        skeletonItemCount: 5,
      );
    }

    if (_viewModel.error != null && _viewModel.analytics == null) {
      return AppErrorWidget(
        title: 'Emotional analytics could not be loaded',
        error: _viewModel.error,
        onRetry: _viewModel.refresh,
      );
    }

    final analytics = _viewModel.analytics;

    return RefreshIndicator(
      onRefresh: _viewModel.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _buildPeriodFilter(),

          if (_viewModel.isLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],

          if (_viewModel.error != null)
            AppInlineError(
              title: 'Analytics could not be refreshed',
              error: _viewModel.error,
              onRetry: _viewModel.refresh,
            ),

          const SizedBox(height: 16),

          if (analytics == null || !analytics.hasData)
            _buildEmptyState()
          else ...[
            _buildSummary(analytics),

            const SizedBox(height: 16),

            _buildBestAndHardestDays(analytics),

            const SizedBox(height: 16),

            _buildMoodChart(analytics),

            const SizedBox(height: 16),

            _buildEmotions(analytics),

            const SizedBox(height: 16),

            _buildExplanation(analytics),

            const SizedBox(height: 16),

            _buildDisclaimer(),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodFilter() {
    return _AnalyticsCard(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analysis period',
              style: TextStyle(
                color: _analyticsText,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Week'),
                  selected:
                      _viewModel.selectedPeriod == AnalyticsPeriodType.week,
                  onSelected: _viewModel.isLoading
                      ? null
                      : (_) {
                          _viewModel.selectWeek();
                        },
                ),
                ChoiceChip(
                  label: const Text('Month'),
                  selected:
                      _viewModel.selectedPeriod == AnalyticsPeriodType.month,
                  onSelected: _viewModel.isLoading
                      ? null
                      : (_) {
                          _viewModel.selectMonth();
                        },
                ),
                ChoiceChip(
                  label: const Text('Custom period'),
                  selected:
                      _viewModel.selectedPeriod == AnalyticsPeriodType.custom,
                  onSelected: _viewModel.isLoading
                      ? null
                      : (_) {
                          _selectCustomPeriod();
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(TherapistMoodTrendModel analytics) {
    return _AnalyticsCard(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _InfoRow(
              icon: Icons.sentiment_satisfied_alt_outlined,
              label: 'Average mood',
              value: '${analytics.averageMood?.toStringAsFixed(2) ?? '—'}/5',
            ),
            const Divider(height: 24),
            _InfoRow(
              icon: Icons.edit_note_outlined,
              label: 'Number of entries',
              value: analytics.totalEntries.toString(),
            ),
            const Divider(height: 24),
            _InfoRow(
              icon: Icons.favorite_border,
              label: 'Most frequent emotion',
              value: analytics.mostFrequentEmotion ?? 'Not available',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBestAndHardestDays(TherapistMoodTrendModel analytics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bestDay = _DayCard(
          title: 'Best day',
          point: analytics.bestDay,
          icon: Icons.trending_up,
        );
        final hardestDay = _DayCard(
          title: 'Most difficult day',
          point: analytics.hardestDay,
          icon: Icons.trending_down,
        );

        if (constraints.maxWidth < 360) {
          return Column(
            children: [bestDay, const SizedBox(height: 12), hardestDay],
          );
        }

        return Row(
          children: [
            Expanded(child: bestDay),
            const SizedBox(width: 12),
            Expanded(child: hardestDay),
          ],
        );
      },
    );
  }

  Widget _buildMoodChart(TherapistMoodTrendModel analytics) {
    final points = analytics.points;

    return _AnalyticsCard(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mood changes',
              style: TextStyle(
                color: _analyticsText,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Daily average mood on a scale from 1 to 5.',
              style: TextStyle(color: _analyticsMuted, height: 1.35),
            ),

            const SizedBox(height: 16),

            const Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.show_chart, size: 18, color: _analyticsPrimary),
                Text(
                  'Daily average mood',
                  style: TextStyle(
                    color: _analyticsText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            SizedBox(
              height: 250,
              child: LineChart(_buildLineChartData(points)),
            ),

            const SizedBox(height: 12),

            const Wrap(
              spacing: 12,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text('1 – Very low'),
                Text('3 – Neutral'),
                Text('5 – Very good'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _buildLineChartData(List<MoodTrendPointModel> points) {
    final spots = List<FlSpot>.generate(
      points.length,
      (index) => FlSpot(
        index.toDouble(),
        points[index].averageMood.clamp(1.0, 5.0).toDouble(),
      ),
    );

    return LineChartData(
      minX: 0,
      maxX: math.max(points.length - 1, 1).toDouble(),
      minY: 1,
      maxY: 5,
      gridData: const FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 1,
        getDrawingHorizontalLine: _analyticsGridLine,
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: _analyticsBorder),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: const AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 38,
            getTitlesWidget: (value, meta) {
              final index = value.round();

              if (index < 0 || index >= points.length) {
                return const SizedBox.shrink();
              }

              final interval = points.length <= 7
                  ? 1
                  : math.max(1, (points.length / 6).ceil());

              if (index % interval != 0 && index != points.length - 1) {
                return const SizedBox.shrink();
              }

              return SideTitleWidget(
                meta: meta,
                child: Text(
                  DateFormat('dd.MM.').format(points[index].dateUtc.toLocal()),
                  style: const TextStyle(
                    color: _analyticsMuted,
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
        touchTooltipData: LineTouchTooltipData(
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final point = points[spot.x.round()];

              return LineTooltipItem(
                '${DateFormat('dd.MM.yyyy.').format(point.dateUtc.toLocal())}\n'
                '${point.averageMood.toStringAsFixed(2)}/5'
                ' • ${point.entryCount} entries',
                const TextStyle(color: Colors.white),
              );
            }).toList();
          },
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: points.length > 2,
          barWidth: 3,
          dotData: const FlDotData(show: true),
          color: _analyticsPrimary,
          belowBarData: BarAreaData(
            show: true,
            color: _analyticsPrimary.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }

  Widget _buildEmotions(TherapistMoodTrendModel analytics) {
    return _AnalyticsCard(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Most frequent emotions',
              style: TextStyle(
                color: _analyticsText,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 12),

            ...analytics.emotions
                .take(8)
                .map(
                  (emotion) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                emotion.emotion,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _analyticsText,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${emotion.count} · '
                              '${emotion.percentage.toStringAsFixed(1)}%',
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        LinearProgressIndicator(
                          value: emotion.percentage.clamp(0, 100) / 100,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(999),
                          backgroundColor: _analyticsLavender,
                          color: _analyticsPrimary,
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanation(TherapistMoodTrendModel analytics) {
    return _AnalyticsCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(_trendIcon(analytics.trend)),
        title: Text(
          _trendTitle(analytics.trend),
          style: const TextStyle(
            color: _analyticsText,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          _trendExplanation(analytics),
          style: const TextStyle(color: _analyticsMuted, height: 1.4),
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return const _AnalyticsCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.info_outline),
        title: Text(
          'Important note',
          style: TextStyle(color: _analyticsText, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          'This analysis summarizes your recorded mood and emotion entries. '
          'It is not a medical diagnosis and does not replace advice from a qualified healthcare professional.',
          style: TextStyle(color: _analyticsMuted, height: 1.4),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const _AnalyticsCard(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28, vertical: 54),
        child: Column(
          children: [
            Icon(Icons.insights_outlined, size: 58, color: _analyticsPrimary),
            SizedBox(height: 16),
            Text(
              'No data for this period',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _analyticsText,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Record your mood and emotions to see patterns and trends.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _analyticsMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final Widget child;

  const _AnalyticsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _analyticsSurface,
        borderRadius: BorderRadius.circular(_analyticsRadius),
        border: Border.all(color: _analyticsBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _analyticsLavender,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _analyticsPrimary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _analyticsMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: _analyticsText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  final String title;
  final MoodTrendPointModel? point;
  final IconData icon;

  const _DayCard({
    required this.title,
    required this.point,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final value = point;

    return _AnalyticsCard(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Icon(icon, color: _analyticsPrimary),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _analyticsText,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value == null
                  ? 'Not available'
                  : DateFormat('dd.MM.yyyy.').format(value.dateUtc.toLocal()),
              textAlign: TextAlign.center,
              style: const TextStyle(color: _analyticsMuted),
            ),
            if (value != null)
              Text(
                '${value.averageMood.toStringAsFixed(2)}/5',
                style: const TextStyle(
                  color: _analyticsText,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _trendTitle(String trend) {
  switch (trend.toLowerCase()) {
    case 'improving':
      return 'Improving trend';
    case 'declining':
      return 'Declining trend';
    case 'stable':
      return 'Stable trend';
    default:
      return 'Not enough data';
  }
}

IconData _trendIcon(String trend) {
  switch (trend.toLowerCase()) {
    case 'improving':
      return Icons.trending_up;
    case 'declining':
      return Icons.trending_down;
    case 'stable':
      return Icons.trending_flat;
    default:
      return Icons.info_outline;
  }
}

FlLine _analyticsGridLine(double value) {
  return const FlLine(color: _analyticsBorder, strokeWidth: 1);
}

String _trendExplanation(TherapistMoodTrendModel analytics) {
  switch (analytics.trend.toLowerCase()) {
    case 'improving':
      return 'Your recent recorded mood average is higher than in the earlier part of the selected period.';
    case 'declining':
      return 'Your recent recorded mood average is lower than in the earlier part of the selected period.';
    case 'stable':
      return 'Your recorded mood average remained relatively stable during the selected period.';
    default:
      return 'More entries across different days are needed to calculate a meaningful trend.';
  }
}
