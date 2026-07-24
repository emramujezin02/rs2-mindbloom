import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../therapist/data/models/mood_trend_point_model.dart';
import '../../../therapist/data/models/therapist_mood_trend_model.dart';
import '../viewmodels/client_emotional_analytics_viewmodel.dart';

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
      appBar: AppBar(
        title: const Text('My emotional patterns'),
        actions: [
          IconButton(
            onPressed: _viewModel.isLoading ? null : _viewModel.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.analytics == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.error != null && _viewModel.analytics == null) {
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
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _viewModel.refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final analytics = _viewModel.analytics;

    return RefreshIndicator(
      onRefresh: _viewModel.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildPeriodFilter(),

          if (_viewModel.isLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],

          if (_viewModel.error != null) ...[
            const SizedBox(height: 12),
            Text(_viewModel.error!, style: const TextStyle(color: Colors.red)),
          ],

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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analysis period',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _InfoRow(
              icon: Icons.sentiment_satisfied,
              label: 'Average mood',
              value: '${analytics.averageMood?.toStringAsFixed(2) ?? '—'}/5',
            ),
            const Divider(),
            _InfoRow(
              icon: Icons.edit_note,
              label: 'Number of entries',
              value: analytics.totalEntries.toString(),
            ),
            const Divider(),
            _InfoRow(
              icon: Icons.favorite_outline,
              label: 'Most frequent emotion',
              value: analytics.mostFrequentEmotion ?? 'Not available',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBestAndHardestDays(TherapistMoodTrendModel analytics) {
    return Row(
      children: [
        Expanded(
          child: _DayCard(
            title: 'Best day',
            point: analytics.bestDay,
            icon: Icons.trending_up,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DayCard(
            title: 'Most difficult day',
            point: analytics.hardestDay,
            icon: Icons.trending_down,
          ),
        ),
      ],
    );
  }

  Widget _buildMoodChart(TherapistMoodTrendModel analytics) {
    final points = analytics.points;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mood changes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            const Text('Daily average mood on a scale from 1 to 5.'),

            const SizedBox(height: 16),

            const Row(
              children: [
                Icon(Icons.show_chart, size: 18),
                SizedBox(width: 6),
                Text('Daily average mood'),
              ],
            ),

            const SizedBox(height: 16),

            SizedBox(
              height: 260,
              child: LineChart(_buildLineChartData(points)),
            ),

            const SizedBox(height: 12),

            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  style: const TextStyle(fontSize: 10),
                ),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
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
          belowBarData: BarAreaData(show: true),
        ),
      ],
    );
  }

  Widget _buildEmotions(TherapistMoodTrendModel analytics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Most frequent emotions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                            Expanded(child: Text(emotion.emotion)),
                            Text(
                              '${emotion.count} · '
                              '${emotion.percentage.toStringAsFixed(1)}%',
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        LinearProgressIndicator(
                          value: emotion.percentage.clamp(0, 100) / 100,
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
    return Card(
      child: ListTile(
        leading: Icon(_trendIcon(analytics.trend)),
        title: Text(_trendTitle(analytics.trend)),
        subtitle: Text(_trendExplanation(analytics)),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('Important note'),
        subtitle: Text(
          'This analysis summarizes your recorded mood and emotion entries. '
          'It is not a medical diagnosis and does not replace advice from a qualified healthcare professional.',
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28, vertical: 54),
        child: Column(
          children: [
            Icon(Icons.insights_outlined, size: 58),
            SizedBox(height: 16),
            Text(
              'No data for this period',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Record your mood and emotions to see patterns and trends.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      trailing: Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              value == null
                  ? 'Not available'
                  : DateFormat('dd.MM.yyyy.').format(value.dateUtc.toLocal()),
            ),
            if (value != null)
              Text('${value.averageMood.toStringAsFixed(2)}/5'),
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
