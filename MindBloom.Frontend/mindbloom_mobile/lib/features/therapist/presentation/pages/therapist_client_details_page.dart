import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../data/models/therapist_client_appointment_model.dart';
import '../../data/models/therapist_client_details_model.dart';
import '../viewmodels/therapist_client_details_viewmodel.dart';

class TherapistClientDetailsPage extends StatefulWidget {
  final int clientId;

  const TherapistClientDetailsPage({
    super.key,
    required this.clientId,
  });

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

    viewModel =
        AppInjection.createTherapistClientDetailsViewModel();

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
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (viewModel.isLoading && viewModel.client == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 240),
          Center(
            child: CircularProgressIndicator(),
          ),
        ],
      );
    }

    if (viewModel.errorMessage != null &&
        viewModel.client == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 130),
          _ErrorState(
            message: viewModel.errorMessage!,
            onRetry: _refresh,
          ),
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
            constraints: const BoxConstraints(
              maxWidth: 1000,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ClientProfileCard(
                  client: client,
                ),
                const SizedBox(height: 18),
                _StatisticsSection(
                  client: client,
                ),
                const SizedBox(height: 26),
                _buildHistoryHeader(client),
                const SizedBox(height: 14),
                if (client.appointments.isEmpty)
                  const _EmptyHistoryState()
                else
                  ...client.appointments.map(
                    (appointment) {
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: 14,
                        ),
                        child: _AppointmentHistoryCard(
                          appointment: appointment,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryHeader(
    TherapistClientDetailsModel client,
  ) {
    final appointmentCount = client.appointments.length;

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
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 7,
          ),
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

  const _ClientProfileCard({
    required this.client,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE5DBEF),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 650;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ClientAvatar(
                  fullName: client.fullName,
                  size: 76,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _ClientInformation(
                    client: client,
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ClientAvatar(
                fullName: client.fullName,
                size: 70,
              ),
              const SizedBox(height: 18),
              _ClientInformation(
                client: client,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ClientInformation extends StatelessWidget {
  final TherapistClientDetailsModel client;

  const _ClientInformation({
    required this.client,
  });

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
        _InformationRow(
          icon: Icons.email_outlined,
          value: client.email,
        ),
        if (client.phoneNumber != null &&
            client.phoneNumber!.trim().isNotEmpty) ...[
          const SizedBox(height: 11),
          _InformationRow(
            icon: Icons.phone_outlined,
            value: client.phoneNumber!,
          ),
        ],
        if (client.dateOfBirth != null) ...[
          const SizedBox(height: 11),
          _InformationRow(
            icon: Icons.cake_outlined,
            value:
                'Date of birth: ${_formatDate(client.dateOfBirth!.toLocal())}',
          ),
        ],
      ],
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}.';
  }
}

class _ClientAvatar extends StatelessWidget {
  final String fullName;
  final double size;

  const _ClientAvatar({
    required this.fullName,
    required this.size,
  });

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

  const _StatisticsSection({
    required this.client,
  });

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
        value: client.upcomingAppointments,
        icon: Icons.upcoming_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 3 : 1;
        const spacing = 12.0;

        final width =
            (constraints.maxWidth - ((columns - 1) * spacing)) /
                columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: statistics.map((statistic) {
            return SizedBox(
              width: width,
              child: _StatisticCard(
                data: statistic,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _StatisticCard extends StatelessWidget {
  final _StatisticData data;

  const _StatisticCard({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: const Color(0xFFE6DCEF),
        ),
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
            child: Icon(
              data.icon,
              color: const Color(0xFF72559A),
            ),
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

  const _AppointmentHistoryCard({
    required this.appointment,
  });

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
        border: Border.all(
          color: const Color(0xFFE5DBEF),
        ),
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
                      style: const TextStyle(
                        color: Color(0xFF756D79),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _AppointmentStatusBadge(
                status: appointment.status,
              ),
            ],
          ),
          if (appointment.type.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            _InformationRow(
              icon: Icons.video_call_outlined,
              value: appointment.type,
            ),
          ],
          if (appointment.notes != null &&
              appointment.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 11),
            _InformationRow(
              icon: Icons.notes_outlined,
              value: appointment.notes!,
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

  const _AppointmentStatusBadge({
    required this.status,
  });

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
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: foregroundColor,
          ),
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

  const _InformationRow({
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFF8063A4),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF625B68),
              height: 1.4,
            ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 52,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE5DBEF),
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.history_outlined,
            size: 64,
            color: Color(0xFF8063A4),
          ),
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
            style: TextStyle(
              color: Color(0xFF756D79),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 520,
        ),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFE5DBEF),
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              size: 58,
              color: Colors.redAccent,
            ),
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
            Text(
              message,
              textAlign: TextAlign.center,
            ),
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