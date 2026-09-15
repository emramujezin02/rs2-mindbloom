import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mindbloom_mobile/app/di/injection.dart';

import '../../../../app/router/app_router.dart';
import '../../data/models/appointment_model.dart';
import '../../data/models/therapist_appointment_status.dart';
import '../viewmodels/therapist_appointments_viewmodel.dart';

const _detailsBackground = Color(0xFFF7F3FB);
const _detailsSurface = Color(0xFFFFFFFF);
const _detailsLavender = Color(0xFFF6F0FC);
const _detailsMint = Color(0xFFEAF7F4);
const _detailsBorder = Color(0xFFE7DDF1);
const _detailsPrimary = Color(0xFF6D4F91);
const _detailsText = Color(0xFF372D45);
const _detailsMuted = Color(0xFF6C6278);
const _detailsDanger = Color(0xFFB13B3B);
const _detailsRadius = 22.0;

class TherapistAppointmentDetailsPage extends StatefulWidget {
  final AppointmentModel appointment;

  const TherapistAppointmentDetailsPage({super.key, required this.appointment});

  @override
  State<TherapistAppointmentDetailsPage> createState() =>
      _TherapistAppointmentDetailsPageState();
}

class _TherapistAppointmentDetailsPageState
    extends State<TherapistAppointmentDetailsPage> {
  late final TherapistAppointmentsViewModel viewModel;

  late AppointmentModel appointment;

  @override
  void initState() {
    super.initState();

    appointment = widget.appointment;

    viewModel = AppInjection.createTherapistAppointmentsViewModel();

    viewModel.addListener(_onViewModelChanged);
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

  Future<void> _changeStatus(TherapistAppointmentStatus status) async {
    final confirmed = await showDialog<bool>(
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
                  ? FilledButton.styleFrom(backgroundColor: _detailsDanger)
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
      setState(() {
        appointment = appointment.copyWith(status: status.label);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Appointment marked as '
            '${status.label.toLowerCase()}.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            viewModel.errorMessage ?? 'Status could not be updated.',
          ),
        ),
      );
    }
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

  void _openChat() {
    Navigator.of(
      context,
    ).pushNamed(AppRouter.chatDetails, arguments: appointment.id);
  }

  @override
  Widget build(BuildContext context) {
    final status = appointment.status.trim().toLowerCase();

    final canAccept = status == 'pending';
    final canReject = status == 'pending';

    final canComplete = status == 'accepted';

    final canCancel = status == 'pending' || status == 'accepted';

    final hasStatusActions = canAccept || canReject || canComplete || canCancel;

    final start = appointment.startUtc.toLocal();
    final end = appointment.endUtc.toLocal();

    final duration = appointment.endUtc.difference(appointment.startUtc);

    final durationText = duration.inMinutes >= 60
        ? '${duration.inHours} h ${duration.inMinutes.remainder(60)} min'
        : '${duration.inMinutes} min';

    return Scaffold(
      backgroundColor: _detailsBackground,
      appBar: AppBar(
        backgroundColor: _detailsBackground,
        surfaceTintColor: Colors.transparent,
        title: const Text('Appointment details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeaderCard(appointment: appointment),
                const SizedBox(height: 16),
                _DetailsSection(
                  title: 'Appointment summary',
                  icon: Icons.event_note_outlined,
                  child: Column(
                    children: [
                      _DetailsRow(label: 'Status', value: appointment.status),
                      const _DetailsDivider(),
                      _DetailsRow(
                        label: 'Type',
                        value: appointment.type.isEmpty
                            ? 'Not specified'
                            : appointment.type,
                      ),
                      const _DetailsDivider(),
                      _DetailsRow(
                        label: 'Date',
                        value: DateFormat('dd.MM.yyyy.').format(start),
                      ),
                      const _DetailsDivider(),
                      _DetailsRow(
                        label: 'Time',
                        value:
                            '${DateFormat('HH:mm').format(start)} - '
                            '${DateFormat('HH:mm').format(end)}',
                      ),
                      const _DetailsDivider(),
                      _DetailsRow(label: 'Duration', value: durationText),
                      const _DetailsDivider(),
                      _DetailsRow(
                        label: 'Price',
                        value: '${appointment.price.toStringAsFixed(2)} BAM',
                      ),
                      if (appointment.paymentId != null) ...[
                        const _DetailsDivider(),
                        _DetailsRow(
                          label: 'Payment',
                          value: '#${appointment.paymentId}',
                        ),
                      ],
                    ],
                  ),
                ),
                if (appointment.notes != null &&
                    appointment.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _TextInformationCard(
                    icon: Icons.notes_outlined,
                    title: 'Appointment note',
                    value: appointment.notes!,
                  ),
                ],
                if (appointment.meetingLink != null &&
                    appointment.meetingLink!.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _TextInformationCard(
                    icon: Icons.video_call_outlined,
                    title: 'Meeting link',
                    value: appointment.meetingLink!,
                  ),
                ],
                if (appointment.type.trim().toLowerCase() == 'online') ...[
                  const SizedBox(height: 16),
                  _SessionAccessCard(appointment: appointment),
                ],
                if (appointment.location != null &&
                    appointment.location!.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _TextInformationCard(
                    icon: Icons.location_on_outlined,
                    title: 'Location',
                    value: appointment.location!,
                  ),
                ],
                const SizedBox(height: 16),
                _DetailsSection(
                  title: 'Actions',
                  icon: Icons.touch_app_outlined,
                  child: viewModel.isUpdatingStatus
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (hasStatusActions)
                              Wrap(
                                spacing: 9,
                                runSpacing: 9,
                                children: [
                                  if (canAccept)
                                    FilledButton.icon(
                                      onPressed: () {
                                        _changeStatus(
                                          TherapistAppointmentStatus.accepted,
                                        );
                                      },
                                      icon: const Icon(Icons.check),
                                      label: const Text('Accept'),
                                    ),
                                  if (canReject)
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _detailsDanger,
                                      ),
                                      onPressed: () {
                                        _changeStatus(
                                          TherapistAppointmentStatus.rejected,
                                        );
                                      },
                                      icon: const Icon(Icons.close),
                                      label: const Text('Reject'),
                                    ),
                                  if (canComplete)
                                    FilledButton.icon(
                                      onPressed: () {
                                        _changeStatus(
                                          TherapistAppointmentStatus.completed,
                                        );
                                      },
                                      icon: const Icon(Icons.task_alt),
                                      label: const Text('Complete'),
                                    ),
                                  if (canCancel)
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _detailsDanger,
                                      ),
                                      onPressed: () {
                                        _changeStatus(
                                          TherapistAppointmentStatus.cancelled,
                                        );
                                      },
                                      icon: const Icon(Icons.cancel_outlined),
                                      label: const Text('Cancel'),
                                    ),
                                ],
                              )
                            else
                              const _DisabledActionHint(
                                text:
                                    'Status actions are unavailable for this appointment state.',
                              ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _openChat,
                                icon: const Icon(Icons.chat_bubble_outline),
                                label: const Text('Open chat'),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final AppointmentModel appointment;

  const _HeaderCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final start = appointment.startUtc.toLocal();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_detailsPrimary, Color(0xFF8063A4)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _detailsPrimary.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: const Icon(
                  Icons.person_outline,
                  size: 30,
                  color: Colors.white,
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
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Appointment #${appointment.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFFEFE9F6)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              _HeroPill(
                icon: Icons.calendar_today_outlined,
                label: DateFormat('dd.MM.yyyy.').format(start),
              ),
              _HeroPill(
                icon: Icons.schedule_outlined,
                label: DateFormat('HH:mm').format(start),
              ),
              _DetailsStatusBadge(status: appointment.status),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _DetailsSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _detailsPrimary, size: 22),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _detailsText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _DetailsRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailsRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _detailsMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            value.isEmpty ? 'Not specified' : value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: _detailsText,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _TextInformationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _TextInformationCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return _DetailsSection(
      title: title,
      icon: icon,
      child: SelectableText(
        value,
        style: const TextStyle(color: _detailsText, height: 1.45),
      ),
    );
  }
}

class _SessionAccessCard extends StatelessWidget {
  final AppointmentModel appointment;

  const _SessionAccessCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final available = appointment.canAccessSession;

    return _SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            available ? Icons.video_call : Icons.lock_clock_outlined,
            color: available ? const Color(0xFF287A42) : _detailsMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  available
                      ? 'Online session available'
                      : 'Online session unavailable',
                  style: const TextStyle(
                    color: _detailsText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  available
                      ? 'Session access is currently available.'
                      : appointment.sessionAccessMessage ??
                            'The online session is not currently available.',
                  style: const TextStyle(color: _detailsMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsStatusBadge extends StatelessWidget {
  final String status;

  const _DetailsStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final palette = _statusPalette(status);

    return Container(
      constraints: const BoxConstraints(maxWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(palette.icon, size: 16, color: palette.foreground),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              status.isEmpty ? 'Pending' : status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_clock_outlined, size: 18, color: _detailsMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: _detailsMuted, fontSize: 12),
            ),
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
        color: _detailsLavender,
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
              color: _detailsText,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Appointment #${appointment.id} • '
            '${DateFormat('dd.MM.yyyy. HH:mm').format(start)}',
            style: const TextStyle(color: _detailsMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;

  const _SurfaceCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _detailsSurface,
        borderRadius: BorderRadius.circular(_detailsRadius),
        border: Border.all(color: _detailsBorder),
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

class _DetailsDivider extends StatelessWidget {
  const _DetailsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 27, color: Color(0xFFECE4F2));
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
        background: _detailsMint,
        foreground: Color(0xFF287A42),
        icon: Icons.check_circle_outline,
      );
    case 'rejected':
      return const _StatusPalette(
        background: Color(0xFFFCE8E8),
        foreground: _detailsDanger,
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
