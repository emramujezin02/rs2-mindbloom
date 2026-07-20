import 'package:flutter/material.dart';
import '../../../../app/di/injection.dart';
import '../../data/models/therapist_client_appointment_model.dart';
import '../../data/models/therapist_client_details_model.dart';
import '../viewmodels/therapist_client_details_viewmodel.dart';
import '../../data/models/mood_trend_point_model.dart';
import '../../data/models/therapist_mood_entry_model.dart';
import '../../data/models/therapist_mood_trend_model.dart';

class TherapistClientDetailsPage extends StatefulWidget {
  final int clientId;

  const TherapistClientDetailsPage({super.key, required this.clientId});

  @override
  State<TherapistClientDetailsPage> createState() =>
      _TherapistClientDetailsPageState();
}

class _TherapistClientDetailsPageState
    extends State<TherapistClientDetailsPage> {
  late final TherapistClientDetailsViewModel viewModel;

  @override
  void initState() {
    super.initState();

    viewModel = AppInjection.createTherapistClientDetailsViewModel();

    viewModel.addListener(_onViewModelChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      viewModel.loadClientDetails(widget.clientId);
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

  Future<void> _refresh() async {
    await viewModel.loadClientDetails(widget.clientId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Client Details',
          style: TextStyle(
            color: Color(0xFF40334D),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: viewModel.isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _refresh, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (viewModel.isLoading && viewModel.client == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 240),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (viewModel.errorMessage != null && viewModel.client == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 130),
          _ErrorState(message: viewModel.errorMessage!, onRetry: _refresh),
        ],
      );
    }

    final client = viewModel.client;

    if (client == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 130),
          _ErrorState(
            message: 'Client details are not available.',
            onRetry: _refresh,
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ClientProfileCard(client: client),
                const SizedBox(height: 18),
                _StatisticsSection(client: client),
                const SizedBox(height: 26),

                _MoodTrackerSection(
                  history: viewModel.moodHistory,
                  trend: viewModel.moodTrend,
                ),

                const SizedBox(height: 26),
                _buildHistoryHeader(client),
                const SizedBox(height: 14),
                if (client.appointmentHistory.isEmpty)
                  const _EmptyHistoryState()
                else
                  ...client.appointmentHistory.map((appointment) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _AppointmentHistoryCard(appointment: appointment),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryHeader(TherapistClientDetailsModel client) {
    final appointmentCount = client.appointmentHistory.length;

    final countText = appointmentCount == 1
        ? '1 appointment'
        : '$appointmentCount appointments';

    return Row(
      children: [
        const Expanded(
          child: Text(
            'Appointment History',
            style: TextStyle(
              color: Color(0xFF40334D),
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFEDE5FA),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            countText,
            style: const TextStyle(
              color: Color(0xFF72559A),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ClientProfileCard extends StatelessWidget {
  final TherapistClientDetailsModel client;

  const _ClientProfileCard({required this.client});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5DBEF)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 650;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ClientAvatar(fullName: client.fullName, size: 76),
                const SizedBox(width: 20),
                Expanded(child: _ClientInformation(client: client)),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ClientAvatar(fullName: client.fullName, size: 70),
              const SizedBox(height: 18),
              _ClientInformation(client: client),
            ],
          );
        },
      ),
    );
  }
}

class _ClientInformation extends StatelessWidget {
  final TherapistClientDetailsModel client;

  const _ClientInformation({required this.client});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          client.fullName,
          style: const TextStyle(
            color: Color(0xFF40334D),
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 15),
        _InformationRow(icon: Icons.email_outlined, value: client.email),
        if (client.phoneNumber != null &&
            client.phoneNumber!.trim().isNotEmpty) ...[
          const SizedBox(height: 11),
          _InformationRow(
            icon: Icons.phone_outlined,
            value: client.phoneNumber!,
          ),
        ],
      ],
    );
  }
}

class _ClientAvatar extends StatelessWidget {
  final String fullName;
  final double size;

  const _ClientAvatar({required this.fullName, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFEDE5FA),
        borderRadius: BorderRadius.circular(22),
      ),
      alignment: Alignment.center,
      child: Text(
        _getInitials(fullName),
        style: TextStyle(
          color: const Color(0xFF72559A),
          fontSize: size * 0.3,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _getInitials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _StatisticsSection extends StatelessWidget {
  final TherapistClientDetailsModel client;

  const _StatisticsSection({required this.client});

  @override
  Widget build(BuildContext context) {
    final statistics = [
      _StatisticData(
        label: 'All appointments',
        value: client.totalAppointments,
        icon: Icons.calendar_month_outlined,
      ),
      _StatisticData(
        label: 'Completed',
        value: client.completedAppointments,
        icon: Icons.task_alt_outlined,
      ),
      _StatisticData(
        label: 'Upcoming',
        value: client.pendingAppointments + client.acceptedAppointments,
        icon: Icons.upcoming_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 3 : 1;
        const spacing = 12.0;

        final width =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: statistics.map((statistic) {
            return SizedBox(
              width: width,
              child: _StatisticCard(data: statistic),
            );
          }).toList(),
        );
      },
    );
  }
}

class _StatisticCard extends StatelessWidget {
  final _StatisticData data;

  const _StatisticCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE6DCEF)),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE5FA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(data.icon, color: const Color(0xFF72559A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value.toString(),
                  style: const TextStyle(
                    color: Color(0xFF40334D),
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.label,
                  style: const TextStyle(
                    color: Color(0xFF756D79),
                    fontSize: 13,
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

class _AppointmentHistoryCard extends StatelessWidget {
  final TherapistClientAppointmentModel appointment;

  const _AppointmentHistoryCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final start = appointment.startUtc.toLocal();
    final end = appointment.endUtc.toLocal();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFE5DBEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 49,
                height: 49,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE5FA),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  color: Color(0xFF72559A),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(start),
                      style: const TextStyle(
                        color: Color(0xFF40334D),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${_formatTime(start)} – ${_formatTime(end)}',
                      style: const TextStyle(color: Color(0xFF756D79)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _AppointmentStatusBadge(status: appointment.status),
            ],
          ),
          if (appointment.type.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            _InformationRow(
              icon: Icons.video_call_outlined,
              value: appointment.type,
            ),
          ],
          if (appointment.hasNote) ...[
            const SizedBox(height: 11),
            const _InformationRow(
              icon: Icons.notes_outlined,
              value: 'A therapist note exists for this appointment.',
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}.';
  }

  static String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

class _AppointmentStatusBadge extends StatelessWidget {
  final String status;

  const _AppointmentStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = status.trim().toLowerCase();

    final Color backgroundColor;
    final Color foregroundColor;
    final IconData icon;

    switch (normalizedStatus) {
      case 'accepted':
        backgroundColor = const Color(0xFFE4F5E9);
        foregroundColor = const Color(0xFF287A42);
        icon = Icons.check_circle_outline;
        break;

      case 'rejected':
        backgroundColor = const Color(0xFFFCE8E8);
        foregroundColor = const Color(0xFFB13B3B);
        icon = Icons.close;
        break;

      case 'completed':
        backgroundColor = const Color(0xFFE6EEFC);
        foregroundColor = const Color(0xFF365EA5);
        icon = Icons.task_alt;
        break;

      case 'cancelled':
        backgroundColor = const Color(0xFFF0ECEC);
        foregroundColor = const Color(0xFF696161);
        icon = Icons.cancel_outlined;
        break;

      default:
        backgroundColor = const Color(0xFFFFF3D9);
        foregroundColor = const Color(0xFF9A6A00);
        icon = Icons.schedule_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foregroundColor),
          const SizedBox(width: 5),
          Text(
            status.trim().isEmpty ? 'Pending' : status,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  final IconData icon;
  final String value;

  const _InformationRow({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF8063A4)),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Color(0xFF625B68), height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 52),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5DBEF)),
      ),
      child: const Column(
        children: [
          Icon(Icons.history_outlined, size: 64, color: Color(0xFF8063A4)),
          SizedBox(height: 17),
          Text(
            'No appointment history',
            style: TextStyle(
              color: Color(0xFF40334D),
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 9),
          Text(
            'There are no appointments recorded for this client.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF756D79)),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE5DBEF)),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 58, color: Colors.redAccent),
            const SizedBox(height: 17),
            const Text(
              'Client details could not be loaded',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF40334D),
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatisticData {
  final String label;
  final int value;
  final IconData icon;

  const _StatisticData({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class _MoodTrackerSection extends StatelessWidget {
  final List<TherapistMoodEntryModel> history;

  final TherapistMoodTrendModel? trend;

  const _MoodTrackerSection({required this.history, required this.trend});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _MoodTrackerHeader(),
        const SizedBox(height: 14),
        if (history.isEmpty)
          const _EmptyMoodTrackerState()
        else ...[
          _MoodSummarySection(history: history, trend: trend),
          const SizedBox(height: 14),
          _MoodTrendCard(trend: trend),
          const SizedBox(height: 14),
          _MoodHistoryCard(history: history),
          const SizedBox(height: 12),
          const _MoodPrivacyNotice(),
        ],
      ],
    );
  }
}

class _MoodTrackerHeader extends StatelessWidget {
  const _MoodTrackerHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: Text(
            'Emotional Tracker',
            style: TextStyle(
              color: Color(0xFF40334D),
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        _MoodPrivacyBadge(),
      ],
    );
  }
}

class _MoodPrivacyBadge extends StatelessWidget {
  const _MoodPrivacyBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F5ED),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 15, color: Color(0xFF34734A)),
          SizedBox(width: 5),
          Text(
            'Protected',
            style: TextStyle(
              color: Color(0xFF34734A),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodSummarySection extends StatelessWidget {
  final List<TherapistMoodEntryModel> history;

  final TherapistMoodTrendModel? trend;

  const _MoodSummarySection({required this.history, required this.trend});

  @override
  Widget build(BuildContext context) {
    final latestEntry = history.first;

    final averageMood = trend?.averageMood;

    final mostFrequentEmotion = trend?.mostFrequentEmotion;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 3 : 1;

        const spacing = 12.0;

        final width =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        final cards = [
          _MoodSummaryCard(
            icon: _moodIcon(latestEntry.mood),
            title: 'Latest mood',
            value: '${latestEntry.mood}/5',
            description: _moodLabel(latestEntry.mood),
          ),
          _MoodSummaryCard(
            icon: Icons.insights_outlined,
            title: 'Average mood',
            value: averageMood == null
                ? '—'
                : '${averageMood.toStringAsFixed(1)}/5',
            description: 'Last 30 days',
          ),
          _MoodSummaryCard(
            icon: Icons.favorite_outline,
            title: 'Main emotion',
            value: mostFrequentEmotion?.trim().isNotEmpty == true
                ? mostFrequentEmotion!
                : 'Not available',
            description:
                '${trend?.totalEntries ?? history.length} recorded entries',
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards.map((card) {
            return SizedBox(width: width, child: card);
          }).toList(),
        );
      },
    );
  }
}

class _MoodSummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String description;

  const _MoodSummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE6DCEF)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE5FA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF72559A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF756D79),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF40334D),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF756D79),
                    fontSize: 12,
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

class _MoodTrendCard extends StatelessWidget {
  final TherapistMoodTrendModel? trend;

  const _MoodTrendCard({required this.trend});

  @override
  Widget build(BuildContext context) {
    final points = trend?.points ?? <MoodTrendPointModel>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
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
                  'Mood Trend',
                  style: TextStyle(
                    color: Color(0xFF40334D),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            'Average daily mood during the selected period.',
            style: TextStyle(color: Color(0xFF756D79), height: 1.4),
          ),
          const SizedBox(height: 22),
          if (points.isEmpty)
            const SizedBox(
              height: 170,
              child: Center(
                child: Text(
                  'There is not enough data to display a mood trend.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF756D79)),
                ),
              ),
            )
          else
            SizedBox(
              height: 210,
              width: double.infinity,
              child: CustomPaint(painter: _MoodTrendPainter(points: points)),
            ),
          if (points.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '1 – Very low',
                  style: TextStyle(color: Color(0xFF756D79), fontSize: 12),
                ),
                Text(
                  '5 – Very good',
                  style: TextStyle(color: Color(0xFF756D79), fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MoodTrendPainter extends CustomPainter {
  final List<MoodTrendPointModel> points;

  const _MoodTrendPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 34.0;
    const rightPadding = 12.0;
    const topPadding = 12.0;
    const bottomPadding = 28.0;

    final chartWidth = size.width - leftPadding - rightPadding;

    final chartHeight = size.height - topPadding - bottomPadding;

    final gridPaint = Paint()
      ..color = const Color(0xFFE9E1F0)
      ..strokeWidth = 1;

    final linePaint = Paint()
      ..color = const Color(0xFF72559A)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pointPaint = Paint()
      ..color = const Color(0xFF72559A)
      ..style = PaintingStyle.fill;

    final pointBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (var mood = 1; mood <= 5; mood++) {
      final y = topPadding + chartHeight * (1 - ((mood - 1) / 4));

      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: mood.toString(),
          style: const TextStyle(color: Color(0xFF756D79), fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(leftPadding - textPainter.width - 9, y - textPainter.height / 2),
      );
    }

    if (points.isEmpty) {
      return;
    }

    final path = Path();

    final positions = <Offset>[];

    for (var index = 0; index < points.length; index++) {
      final point = points[index];

      final x = points.length == 1
          ? leftPadding + chartWidth / 2
          : leftPadding + chartWidth * (index / (points.length - 1));

      final normalizedMood = ((point.averageMood - 1) / 4).clamp(0.0, 1.0);

      final y = topPadding + chartHeight * (1 - normalizedMood);

      final position = Offset(x, y);

      positions.add(position);

      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    if (positions.length > 1) {
      canvas.drawPath(path, linePaint);
    }

    for (final position in positions) {
      canvas.drawCircle(position, 6, pointPaint);

      canvas.drawCircle(position, 6, pointBorderPaint);
    }

    final firstDate = points.first.dateUtc.toLocal();

    final lastDate = points.last.dateUtc.toLocal();

    _paintDate(
      canvas,
      _formatChartDate(firstDate),
      leftPadding,
      size.height - bottomPadding + 8,
      TextAlign.left,
    );

    if (points.length > 1) {
      _paintDate(
        canvas,
        _formatChartDate(lastDate),
        size.width - rightPadding,
        size.height - bottomPadding + 8,
        TextAlign.right,
      );
    }
  }

  void _paintDate(
    Canvas canvas,
    String value,
    double x,
    double y,
    TextAlign alignment,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: value,
        style: const TextStyle(color: Color(0xFF756D79), fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
      textAlign: alignment,
    )..layout();

    final offsetX = alignment == TextAlign.right ? x - textPainter.width : x;

    textPainter.paint(canvas, Offset(offsetX, y));
  }

  String _formatChartDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}.'
        '${value.month.toString().padLeft(2, '0')}.';
  }

  @override
  bool shouldRepaint(covariant _MoodTrendPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _MoodHistoryCard extends StatelessWidget {
  final List<TherapistMoodEntryModel> history;

  const _MoodHistoryCard({required this.history});

  @override
  Widget build(BuildContext context) {
    final visibleEntries = history.take(10).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFE5DBEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_outlined, color: Color(0xFF72559A)),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Mood History',
                  style: TextStyle(
                    color: Color(0xFF40334D),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE5FA),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  '${history.length} entries',
                  style: const TextStyle(
                    color: Color(0xFF72559A),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...visibleEntries.asMap().entries.map((item) {
            final index = item.key;
            final entry = item.value;

            return Column(
              children: [
                _MoodHistoryItem(entry: entry),
                if (index < visibleEntries.length - 1)
                  const Divider(height: 25, color: Color(0xFFE9E1F0)),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _MoodHistoryItem extends StatelessWidget {
  final TherapistMoodEntryModel entry;

  const _MoodHistoryItem({required this.entry});

  @override
  Widget build(BuildContext context) {
    final date = entry.createdAtUtc.toLocal();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF4EEFA),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(_moodIcon(entry.mood), color: const Color(0xFF72559A)),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.emotion.trim().isEmpty
                          ? 'Emotion not specified'
                          : entry.emotion,
                      style: const TextStyle(
                        color: Color(0xFF40334D),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _MoodScoreBadge(mood: entry.mood),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${_formatMoodDate(date)} at ${_formatMoodTime(date)}',
                style: const TextStyle(color: Color(0xFF756D79), fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                _moodLabel(entry.mood),
                style: const TextStyle(
                  color: Color(0xFF72559A),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MoodScoreBadge extends StatelessWidget {
  final int mood;

  const _MoodScoreBadge({required this.mood});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE5FA),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        '$mood/5',
        style: const TextStyle(
          color: Color(0xFF72559A),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MoodPrivacyNotice extends StatelessWidget {
  const _MoodPrivacyNotice();

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
              'Only mood scores and emotions are displayed. Private journal notes are not shared with the therapist.',
              style: TextStyle(color: Color(0xFF42634C), height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMoodTrackerState extends StatelessWidget {
  const _EmptyMoodTrackerState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 45),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5DBEF)),
      ),
      child: const Column(
        children: [
          Icon(Icons.mood_outlined, size: 62, color: Color(0xFF8063A4)),
          SizedBox(height: 16),
          Text(
            'No emotional tracker entries',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF40334D),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 9),
          Text(
            'This client has not recorded any mood or emotion entries yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF756D79), height: 1.4),
          ),
        ],
      ),
    );
  }
}

IconData _moodIcon(int mood) {
  switch (mood) {
    case 1:
      return Icons.sentiment_very_dissatisfied;
    case 2:
      return Icons.sentiment_dissatisfied;
    case 3:
      return Icons.sentiment_neutral;
    case 4:
      return Icons.sentiment_satisfied;
    case 5:
      return Icons.sentiment_very_satisfied;
    default:
      return Icons.mood_outlined;
  }
}

String _moodLabel(int mood) {
  switch (mood) {
    case 1:
      return 'Very low';
    case 2:
      return 'Low';
    case 3:
      return 'Neutral';
    case 4:
      return 'Good';
    case 5:
      return 'Very good';
    default:
      return 'Unknown';
  }
}

String _formatMoodDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}.';
}

String _formatMoodTime(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}
