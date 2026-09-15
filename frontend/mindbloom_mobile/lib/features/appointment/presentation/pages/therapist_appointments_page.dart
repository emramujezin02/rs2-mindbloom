import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mindbloom_mobile/app/di/injection.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../data/models/appointment_model.dart';
import '../../data/models/therapist_appointment_status.dart';
import '../viewmodels/therapist_appointments_viewmodel.dart';

const _appointmentsBackground = Color(0xFFF7F3FB);
const _appointmentsSurface = Color(0xFFFFFFFF);
const _appointmentsLavender = Color(0xFFF6F0FC);
const _appointmentsMint = Color(0xFFEAF7F4);
const _appointmentsBorder = Color(0xFFE7DDF1);
const _appointmentsPrimary = Color(0xFF6D4F91);
const _appointmentsText = Color(0xFF372D45);
const _appointmentsMuted = Color(0xFF6C6278);
const _appointmentsDanger = Color(0xFFB13B3B);
const _appointmentsRadius = 22.0;

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
        final destructive =
            status == TherapistAppointmentStatus.rejected ||
            status == TherapistAppointmentStatus.cancelled;

        return AlertDialog(
          title: Text(_confirmationTitle(status)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_confirmationMessage(status)),
              const SizedBox(height: 14),
              _DialogAppointmentSummary(appointment: appointment),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Back'),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(backgroundColor: _appointmentsDanger)
                  : null,
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

  Future<void> _selectDate() async {
    final now = DateTime.now();

    final initialDate = viewModel.selectedDate ?? now;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 3),
      helpText: 'Select appointment date',
      cancelText: 'Cancel',
      confirmText: 'Select',
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    viewModel.selectCustomDate(selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _appointmentsBackground,
      appBar: AppBar(
        backgroundColor: _appointmentsBackground,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Therapist Appointments',
          style: TextStyle(
            color: _appointmentsText,
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
      return const AppLoadingWidget.skeleton(
        message: 'Loading appointments...',
        skeletonItemCount: 6,
      );
    }

    if (viewModel.errorMessage != null && viewModel.totalCount == 0) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 90),
          _ErrorState(
            message: viewModel.errorMessage!,
            onRetry: viewModel.loadAppointments,
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
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
                const SizedBox(height: 18),
                _FilterSection(
                  selectedStatusFilter: viewModel.selectedStatusFilter,
                  selectedDateFilter: viewModel.selectedDateFilter,
                  selectedDate: viewModel.selectedDate,
                  hasActiveFilters: viewModel.hasActiveFilters,
                  onStatusSelected: viewModel.selectStatusFilter,
                  onAllDatesSelected: viewModel.selectAllDates,
                  onTodaySelected: viewModel.selectToday,
                  onThisWeekSelected: viewModel.selectThisWeek,
                  onCustomDateSelected: _selectDate,
                  onClearFilters: viewModel.clearFilters,
                ),
                const SizedBox(height: 20),
                const _SectionHeader(
                  title: 'Schedule',
                  subtitle: 'Review appointments and manage status updates.',
                ),
                const SizedBox(height: 14),
                if (viewModel.appointments.isEmpty)
                  const _EmptyState()
                else
                  ...viewModel.appointments.map((appointment) {
                    final isUpdating =
                        viewModel.isUpdatingStatus &&
                        viewModel.updatingAppointmentId == appointment.id;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
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

    return _ResponsiveGrid(
      minItemWidth: 142,
      spacing: 12,
      children: items.map((item) => _SummaryCard(data: item)).toList(),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final _SummaryData data;

  const _SummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _appointmentsLavender,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(data.icon, color: _appointmentsPrimary, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _appointmentsText,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _appointmentsMuted,
                    fontSize: 12,
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

class _FilterSection extends StatelessWidget {
  final TherapistAppointmentStatus? selectedStatusFilter;

  final TherapistAppointmentDateFilter selectedDateFilter;

  final DateTime? selectedDate;

  final bool hasActiveFilters;

  final ValueChanged<TherapistAppointmentStatus?> onStatusSelected;

  final VoidCallback onAllDatesSelected;
  final VoidCallback onTodaySelected;
  final VoidCallback onThisWeekSelected;
  final VoidCallback onCustomDateSelected;
  final VoidCallback onClearFilters;

  const _FilterSection({
    required this.selectedStatusFilter,
    required this.selectedDateFilter,
    required this.selectedDate,
    required this.hasActiveFilters,
    required this.onStatusSelected,
    required this.onAllDatesSelected,
    required this.onTodaySelected,
    required this.onThisWeekSelected,
    required this.onCustomDateSelected,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionHeader(
                  title: 'Filters',
                  subtitle: 'Narrow the schedule by date or status.',
                ),
              ),
              if (hasActiveFilters)
                TextButton.icon(
                  onPressed: onClearFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const _FilterLabel('Date'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('All dates'),
                selected:
                    selectedDateFilter == TherapistAppointmentDateFilter.all,
                onSelected: (_) {
                  onAllDatesSelected();
                },
              ),
              FilterChip(
                avatar: const Icon(Icons.today_outlined, size: 18),
                label: const Text('Today'),
                selected:
                    selectedDateFilter == TherapistAppointmentDateFilter.today,
                onSelected: (_) {
                  onTodaySelected();
                },
              ),
              FilterChip(
                avatar: const Icon(Icons.date_range_outlined, size: 18),
                label: const Text('This week'),
                selected:
                    selectedDateFilter ==
                    TherapistAppointmentDateFilter.thisWeek,
                onSelected: (_) {
                  onThisWeekSelected();
                },
              ),
              FilterChip(
                avatar: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text(_customDateLabel()),
                selected:
                    selectedDateFilter == TherapistAppointmentDateFilter.custom,
                onSelected: (_) {
                  onCustomDateSelected();
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _FilterLabel('Status'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('All statuses'),
                selected: selectedStatusFilter == null,
                onSelected: (_) {
                  onStatusSelected(null);
                },
              ),
              ...TherapistAppointmentStatus.values.map((status) {
                return FilterChip(
                  label: Text(status.label),
                  selected: selectedStatusFilter == status,
                  onSelected: (_) {
                    onStatusSelected(status);
                  },
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  String _customDateLabel() {
    final date = selectedDate;

    if (selectedDateFilter != TherapistAppointmentDateFilter.custom ||
        date == null) {
      return 'Choose date';
    }

    return DateFormat('dd.MM.yyyy.').format(date);
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

    final hasStatusActions = canAccept || canReject || canComplete || canCancel;

    return Material(
      color: _appointmentsSurface,
      borderRadius: BorderRadius.circular(_appointmentsRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(_appointmentsRadius),
        onTap: isUpdating ? null : onDetails,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_appointmentsRadius),
            border: Border.all(color: _appointmentsBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _ClientIdentity(appointment: appointment),
                  _StatusBadge(status: appointment.status),
                ],
              ),
              const SizedBox(height: 16),
              _InformationTile(
                icon: Icons.calendar_today_outlined,
                label: 'Date',
                value: _formatDate(appointment.startUtc.toLocal()),
              ),
              const SizedBox(height: 10),
              _InformationTile(
                icon: Icons.schedule_outlined,
                label: 'Time',
                value:
                    '${_formatTime(appointment.startUtc.toLocal())} - '
                    '${_formatTime(appointment.endUtc.toLocal())}',
              ),
              if (appointment.type.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                _InformationTile(
                  icon: _typeIcon(appointment),
                  label: 'Type',
                  value: appointment.type,
                ),
              ],
              const SizedBox(height: 16),
              if (isUpdating)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
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
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _appointmentsDanger,
                        ),
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
                        style: TextButton.styleFrom(
                          foregroundColor: _appointmentsDanger,
                        ),
                        onPressed: onCancel,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel'),
                      ),
                  ],
                ),
                if (!hasStatusActions) ...[
                  const SizedBox(height: 10),
                  const _DisabledActionHint(
                    text:
                        'Status actions are unavailable for this appointment state.',
                  ),
                ],
              ],
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

  static IconData _typeIcon(AppointmentModel appointment) {
    final type = appointment.type.trim().toLowerCase();

    if (type.contains('chat')) {
      return Icons.chat_bubble_outline;
    }

    if (type.contains('call')) {
      return Icons.call_outlined;
    }

    if (appointment.isOnline || type.contains('video')) {
      return Icons.video_call_outlined;
    }

    return Icons.event_note_outlined;
  }
}

class _ClientIdentity extends StatelessWidget {
  final AppointmentModel appointment;

  const _ClientIdentity({required this.appointment});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 210, maxWidth: 430),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _appointmentsLavender,
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.person_outline,
              color: _appointmentsPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment.clientName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _appointmentsText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Appointment #${appointment.id}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _appointmentsMuted,
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

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final palette = _statusPalette(status);

    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(palette.icon, size: 15, color: palette.foreground),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              status.isEmpty ? 'Pending' : status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.foreground,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InformationTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InformationTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDE5F2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: _appointmentsPrimary),
          const SizedBox(width: 9),
          Text(
            label,
            style: const TextStyle(
              color: _appointmentsMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: _appointmentsText,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisabledActionHint extends StatelessWidget {
  final String text;

  const _DisabledActionHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2EEF5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_clock_outlined,
            size: 18,
            color: _appointmentsMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: _appointmentsMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: const Column(
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 62,
            color: _appointmentsPrimary,
          ),
          SizedBox(height: 16),
          Text(
            'No appointments found',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _appointmentsText,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'There are no appointments matching the selected filter.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _appointmentsMuted, height: 1.4),
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
    return _SurfaceCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 56, color: _appointmentsDanger),
          const SizedBox(height: 16),
          const Text(
            'Appointments could not be loaded',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _appointmentsText,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _appointmentsMuted, height: 1.4),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _DialogAppointmentSummary extends StatelessWidget {
  final AppointmentModel appointment;

  const _DialogAppointmentSummary({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final start = appointment.startUtc.toLocal();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _appointmentsLavender,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appointment.clientName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _appointmentsText,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Appointment #${appointment.id} • '
            '${DateFormat('dd.MM.yyyy. HH:mm').format(start)}',
            style: const TextStyle(color: _appointmentsMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: _appointmentsText,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: _appointmentsMuted,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _FilterLabel extends StatelessWidget {
  final String label;

  const _FilterLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _appointmentsText,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  const _ResponsiveGrid({
    required this.children,
    required this.minItemWidth,
    required this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / minItemWidth).floor().clamp(
          1,
          4,
        );

        final itemWidth =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _appointmentsSurface,
        borderRadius: BorderRadius.circular(_appointmentsRadius),
        border: Border.all(color: _appointmentsBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatusPalette {
  final Color background;
  final Color foreground;
  final IconData icon;

  const _StatusPalette({
    required this.background,
    required this.foreground,
    required this.icon,
  });
}

_StatusPalette _statusPalette(String status) {
  switch (status.trim().toLowerCase()) {
    case 'accepted':
      return const _StatusPalette(
        background: _appointmentsMint,
        foreground: Color(0xFF287A42),
        icon: Icons.check_circle_outline,
      );
    case 'rejected':
      return const _StatusPalette(
        background: Color(0xFFFCE8E8),
        foreground: _appointmentsDanger,
        icon: Icons.close,
      );
    case 'completed':
      return const _StatusPalette(
        background: Color(0xFFE8F0FE),
        foreground: Color(0xFF365EA5),
        icon: Icons.task_alt,
      );
    case 'cancelled':
      return const _StatusPalette(
        background: Color(0xFFF0ECEC),
        foreground: Color(0xFF696161),
        icon: Icons.cancel_outlined,
      );
    default:
      return const _StatusPalette(
        background: Color(0xFFFFF4D8),
        foreground: Color(0xFF9A6A00),
        icon: Icons.schedule_outlined,
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
