import 'package:flutter/material.dart';
import 'package:mindbloom_mobile/app/di/injection.dart';

import '../../../../app/router/app_router.dart';
import '../../data/models/appointment_model.dart';
import '../../data/models/therapist_appointment_status.dart';
import '../viewmodels/therapist_appointments_viewmodel.dart';

class TherapistAppointmentsPage extends StatefulWidget {
  const TherapistAppointmentsPage({super.key});

  @override
  State<TherapistAppointmentsPage> createState() =>
      _TherapistAppointmentsPageState();
}

class _TherapistAppointmentsPageState extends State<TherapistAppointmentsPage> {
  late final TherapistAppointmentsViewModel viewModel;

  @override
  void initState() {
    super.initState();

    viewModel = AppInjection.createTherapistAppointmentsViewModel();

    viewModel.addListener(_onViewModelChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      viewModel.loadAppointments();
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

  Future<void> _changeStatus(
    AppointmentModel appointment,
    TherapistAppointmentStatus status,
  ) async {
    final confirmed = await _showStatusConfirmation(
      appointment: appointment,
      status: status,
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await viewModel.updateStatus(
      appointment: appointment,
      status: status,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appointment marked as ${status.label.toLowerCase()}.'),
        ),
      );
    } else {
      _showErrorMessage();
    }
  }

  Future<bool?> _showStatusConfirmation({
    required AppointmentModel appointment,
    required TherapistAppointmentStatus status,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_confirmationTitle(status)),
          content: Text(
            '${_confirmationMessage(status)}\n\n'
            'Appointment #${appointment.id}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(_actionLabel(status)),
            ),
          ],
        );
      },
    );
  }

  String _confirmationTitle(TherapistAppointmentStatus status) {
    switch (status) {
      case TherapistAppointmentStatus.accepted:
        return 'Accept appointment?';

      case TherapistAppointmentStatus.rejected:
        return 'Reject appointment?';

      case TherapistAppointmentStatus.completed:
        return 'Complete appointment?';

      case TherapistAppointmentStatus.cancelled:
        return 'Cancel appointment?';

      case TherapistAppointmentStatus.pending:
        return 'Change appointment status?';
    }
  }

  String _confirmationMessage(TherapistAppointmentStatus status) {
    switch (status) {
      case TherapistAppointmentStatus.accepted:
        return 'The client will be notified that the appointment was accepted.';

      case TherapistAppointmentStatus.rejected:
        return 'The client will be notified that the appointment was rejected.';

      case TherapistAppointmentStatus.completed:
        return 'Mark this appointment as successfully completed.';

      case TherapistAppointmentStatus.cancelled:
        return 'The appointment will be cancelled and can no longer be changed.';

      case TherapistAppointmentStatus.pending:
        return 'The appointment will be moved back to pending.';
    }
  }

  String _actionLabel(TherapistAppointmentStatus status) {
    switch (status) {
      case TherapistAppointmentStatus.accepted:
        return 'Accept';

      case TherapistAppointmentStatus.rejected:
        return 'Reject';

      case TherapistAppointmentStatus.completed:
        return 'Complete';

      case TherapistAppointmentStatus.cancelled:
        return 'Cancel appointment';

      case TherapistAppointmentStatus.pending:
        return 'Confirm';
    }
  }

  void _showErrorMessage() {
    final message =
        viewModel.errorMessage ?? 'Appointment status could not be updated.';

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openDetails(AppointmentModel appointment) async {
    await Navigator.of(
      context,
    ).pushNamed(AppRouter.therapistAppointmentDetails, arguments: appointment);

    if (mounted) {
      await viewModel.loadAppointments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Therapist Appointments',
          style: TextStyle(
            color: Color(0xFF40334D),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: viewModel.isLoading ? null : viewModel.loadAppointments,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: viewModel.loadAppointments,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (viewModel.isLoading && viewModel.totalCount == 0) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 240),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (viewModel.errorMessage != null && viewModel.totalCount == 0) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 130),
          _ErrorState(
            message: viewModel.errorMessage!,
            onRetry: viewModel.loadAppointments,
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
                _SummarySection(
                  total: viewModel.totalCount,
                  pending: viewModel.countByStatus(
                    TherapistAppointmentStatus.pending,
                  ),
                  accepted: viewModel.countByStatus(
                    TherapistAppointmentStatus.accepted,
                  ),
                  completed: viewModel.countByStatus(
                    TherapistAppointmentStatus.completed,
                  ),
                ),
                const SizedBox(height: 25),
                _FilterSection(
                  selectedFilter: viewModel.selectedFilter,
                  onSelected: viewModel.selectFilter,
                ),
                const SizedBox(height: 22),
                if (viewModel.appointments.isEmpty)
                  const _EmptyState()
                else
                  ...viewModel.appointments.map((appointment) {
                    final isUpdating =
                        viewModel.isUpdatingStatus &&
                        viewModel.updatingAppointmentId == appointment.id;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: _AppointmentCard(
                        appointment: appointment,
                        isUpdating: isUpdating,
                        onDetails: () {
                          _openDetails(appointment);
                        },
                        onAccept: () {
                          _changeStatus(
                            appointment,
                            TherapistAppointmentStatus.accepted,
                          );
                        },
                        onReject: () {
                          _changeStatus(
                            appointment,
                            TherapistAppointmentStatus.rejected,
                          );
                        },
                        onComplete: () {
                          _changeStatus(
                            appointment,
                            TherapistAppointmentStatus.completed,
                          );
                        },
                        onCancel: () {
                          _changeStatus(
                            appointment,
                            TherapistAppointmentStatus.cancelled,
                          );
                        },
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummarySection extends StatelessWidget {
  final int total;
  final int pending;
  final int accepted;
  final int completed;

  const _SummarySection({
    required this.total,
    required this.pending,
    required this.accepted,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _SummaryData(
        label: 'All',
        value: total,
        icon: Icons.calendar_month_outlined,
      ),
      _SummaryData(
        label: 'Pending',
        value: pending,
        icon: Icons.schedule_outlined,
      ),
      _SummaryData(
        label: 'Accepted',
        value: accepted,
        icon: Icons.check_circle_outline,
      ),
      _SummaryData(
        label: 'Completed',
        value: completed,
        icon: Icons.task_alt_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 750 ? 4 : 2;

        const spacing = 12.0;

        final width =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items.map((item) {
            return SizedBox(
              width: width,
              child: _SummaryCard(data: item),
            );
          }).toList(),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final _SummaryData data;

  const _SummaryCard({required this.data});

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
          Icon(data.icon, color: const Color(0xFF72559A)),
          const SizedBox(width: 11),
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
                Text(
                  data.label,
                  style: const TextStyle(color: Color(0xFF756D79)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  final TherapistAppointmentStatus? selectedFilter;

  final ValueChanged<TherapistAppointmentStatus?> onSelected;

  const _FilterSection({
    required this.selectedFilter,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filter by status',
          style: TextStyle(
            color: Color(0xFF40334D),
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: const Text('All'),
                  selected: selectedFilter == null,
                  onSelected: (_) {
                    onSelected(null);
                  },
                ),
              ),
              ...TherapistAppointmentStatus.values.map((status) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(status.label),
                    selected: selectedFilter == status,
                    onSelected: (_) {
                      onSelected(status);
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;
  final bool isUpdating;

  final VoidCallback onDetails;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  const _AppointmentCard({
    required this.appointment,
    required this.isUpdating,
    required this.onDetails,
    required this.onAccept,
    required this.onReject,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = appointment.status.trim().toLowerCase();

    final canAccept = normalizedStatus == 'pending';

    final canReject = normalizedStatus == 'pending';

    final canComplete = normalizedStatus == 'accepted';

    final canCancel =
        normalizedStatus == 'pending' || normalizedStatus == 'accepted';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5DBEF)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: isUpdating ? null : onDetails,
        child: Padding(
          padding: const EdgeInsets.all(21),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 51,
                    height: 51,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE5FA),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Color(0xFF72559A),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.clientName,
                          style: const TextStyle(
                            color: Color(0xFF40334D),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Appointment #${appointment.id}',
                          style: const TextStyle(color: Color(0xFF766F7A)),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(status: appointment.status),
                ],
              ),
              const SizedBox(height: 18),
              _InformationRow(
                icon: Icons.calendar_today_outlined,
                value: _formatDate(appointment.startUtc.toLocal()),
              ),
              const SizedBox(height: 10),
              _InformationRow(
                icon: Icons.schedule_outlined,
                value:
                    '${_formatTime(appointment.startUtc.toLocal())}'
                    ' – '
                    '${_formatTime(appointment.endUtc.toLocal())}',
              ),
              if (appointment.type.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                _InformationRow(
                  icon: Icons.video_call_outlined,
                  value: appointment.type,
                ),
              ],
              const SizedBox(height: 19),
              if (isUpdating)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onDetails,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Details'),
                    ),
                    if (canAccept)
                      FilledButton.icon(
                        onPressed: onAccept,
                        icon: const Icon(Icons.check),
                        label: const Text('Accept'),
                      ),
                    if (canReject)
                      OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close),
                        label: const Text('Reject'),
                      ),
                    if (canComplete)
                      FilledButton.icon(
                        onPressed: onComplete,
                        icon: const Icon(Icons.task_alt),
                        label: const Text('Complete'),
                      ),
                    if (canCancel)
                      TextButton.icon(
                        onPressed: onCancel,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel'),
                      ),
                  ],
                ),
            ],
          ),
        ),
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

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

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
            status.isEmpty ? 'Pending' : status,
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
      children: [
        Icon(icon, size: 20, color: const Color(0xFF8063A4)),
        const SizedBox(width: 9),
        Expanded(
          child: Text(value, style: const TextStyle(color: Color(0xFF625B68))),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 55),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 65,
            color: Color(0xFF8063A4),
          ),
          SizedBox(height: 17),
          Text(
            'No appointments found',
            style: TextStyle(
              color: Color(0xFF40334D),
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'There are no appointments matching the selected filter.',
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
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 58, color: Colors.redAccent),
            const SizedBox(height: 17),
            const Text(
              'Appointments could not be loaded',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
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

class _SummaryData {
  final String label;
  final int value;
  final IconData icon;

  const _SummaryData({
    required this.label,
    required this.value,
    required this.icon,
  });
}
