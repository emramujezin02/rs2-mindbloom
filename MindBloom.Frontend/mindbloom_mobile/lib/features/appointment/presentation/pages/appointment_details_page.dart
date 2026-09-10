import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/validation/app_validators.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../payment/presentation/pages/payment_receipt_page.dart';
import '../../../payment/presentation/viewmodels/appointment_payment_viewmodel.dart';
import '../../data/models/appointment_model.dart';
import '../viewmodels/appointment_details_viewmodel.dart';

const _detailsBackground = Color(0xFFFCFAFF);
const _detailsSurface = Color(0xFFFFFFFF);
const _detailsLavender = Color(0xFFF6F0FC);
const _detailsBorder = Color(0xFFE7DDF1);
const _detailsPrimary = Color(0xFF6D4F91);
const _detailsText = Color(0xFF372D45);
const _detailsMuted = Color(0xFF6C6278);
const _detailsRadius = 20.0;

class AppointmentDetailsPage extends StatefulWidget {
  final AppointmentModel appointment;

  const AppointmentDetailsPage({super.key, required this.appointment});

  @override
  State<AppointmentDetailsPage> createState() => _AppointmentDetailsPageState();
}

class _AppointmentDetailsPageState extends State<AppointmentDetailsPage> {
  late final AppointmentDetailsViewModel _viewModel;

  late final AppointmentPaymentViewModel _paymentViewModel;

  @override
  void initState() {
    super.initState();

    _viewModel = AppInjection.createAppointmentDetailsViewModel(
      widget.appointment,
    );

    _paymentViewModel = AppInjection.createAppointmentPaymentViewModel();

    _viewModel.addListener(_onViewModelChanged);

    _paymentViewModel.addListener(_onViewModelChanged);

    _paymentViewModel.loadPaymentStatus(widget.appointment.id);

    _viewModel.loadDetails();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);

    _paymentViewModel.removeListener(_onViewModelChanged);

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _joinSession() async {
    final accessGranted = await _viewModel.refreshSessionAccess();

    if (!mounted) {
      return;
    }

    final appointment = _viewModel.currentAppointment;

    if (!accessGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appointment.sessionAccessMessage ??
                'The online session is not available.',
          ),
        ),
      );

      return;
    }

    final link = appointment.meetingLink;

    if (link == null || link.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meeting link is not available.')),
      );

      return;
    }

    final uri = Uri.tryParse(link.trim());

    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Meeting link is invalid.')));

      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!mounted) {
      return;
    }

    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open meeting link.')),
      );
    }
  }

  Future<void> _payAppointment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm payment'),
          content: Text(
            'Purpose:\n'
            'Therapy appointment with '
            '${_viewModel.currentAppointment.therapistName}\n\n'
            'Amount:\n'
            '${_viewModel.currentAppointment.price.toStringAsFixed(2)} BAM',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Continue to payment'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await _paymentViewModel.payForAppointment(
      _viewModel.currentAppointment.id,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment completed successfully.')),
      );
    }

    if (success) {
      await _viewModel.loadDetails();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment was confirmed successfully by the server.'),
        ),
      );

      return;
    }

    final message =
        _paymentViewModel.errorMessage ?? 'Payment could not be completed.';

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openReceipt() {
    final paymentId = _paymentViewModel.paymentId;

    if (paymentId == null || paymentId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt is not available for this appointment.'),
        ),
      );

      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentReceiptPage(paymentId: paymentId),
      ),
    );
  }

  Future<void> _showCancellationDialog() async {
    if (_paymentViewModel.isRefundPending || _paymentViewModel.isRefunded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _paymentViewModel.isRefundPending
                ? 'A refund is already being processed.'
                : 'This payment has already been refunded.',
          ),
        ),
      );

      return;
    }

    final reasonController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel appointment'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_paymentViewModel.isPaid)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'This appointment has already been paid. '
                      'After cancellation, MindBloom will automatically '
                      'send a refund request to Stripe. '
                      'The refund may remain pending until Stripe finishes processing it.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                TextFormField(
                  controller: reasonController,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Cancellation reason',
                    hintText: 'Explain why you are cancelling the appointment.',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    return _viewModel.fieldError('Reason') ??
                        AppValidators.cancellationReason(value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                Navigator.of(dialogContext).pop(reasonController.text.trim());
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    reasonController.dispose();

    if (reason == null || !mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm cancellation'),
          content: Text(
            _paymentViewModel.isPaid
                ? 'Are you sure you want to cancel this paid appointment? '
                      'The appointment will be cancelled and a Stripe refund will be initiated automatically.'
                : 'Are you sure you want to cancel this appointment?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(
                _paymentViewModel.isPaid
                    ? 'Cancel and request refund'
                    : 'Yes, cancel',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final wasPaid = _paymentViewModel.isPaid;

    final success = await _viewModel.cancelAppointment(reason);

    if (!success && mounted) {
      formKey.currentState?.validate();
    }

    if (!mounted) {
      return;
    }

    if (!success) {
      final message = _viewModel.errorMessage ?? 'Termin nije moguće otkazati.';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));

      return;
    }

    await _paymentViewModel.loadPaymentStatus(_viewModel.currentAppointment.id);

    if (!mounted) {
      return;
    }

    String message;

    if (_paymentViewModel.isRefunded) {
      message =
          'Appointment cancelled successfully. '
          'The payment has been refunded.';
    } else if (_paymentViewModel.isRefundPending) {
      message =
          'Appointment cancelled successfully. '
          'Your refund request is being processed by Stripe.';
    } else if (_paymentViewModel.isRefundFailed) {
      message =
          'Appointment was cancelled, but the refund could not be completed. '
          'Please contact support.';
    } else if (wasPaid) {
      message =
          'Appointment cancelled successfully. '
          'The refund request has been submitted.';
    } else {
      message = 'Appointment cancelled successfully.';
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildPaymentStatusCard() {
    if (_paymentViewModel.isCheckingPayment) {
      return const _DetailsCard(
        child: AppInlineLoadingIndicator(message: 'Checking payment status...'),
      );
    }

    if (_paymentViewModel.isRefundPending) {
      return const _StatusNotice(
        icon: Icons.hourglass_top,
        title: 'Refund pending',
        message:
            'Stripe is currently processing your refund. A second refund request cannot be submitted.',
      );
    }

    if (_paymentViewModel.isRefunded) {
      return const _StatusNotice(
        icon: Icons.replay_circle_filled,
        title: 'Payment refunded',
        message:
            'The paid amount has been refunded. No additional refund request is required.',
      );
    }

    if (_paymentViewModel.isRefundFailed) {
      return const _StatusNotice(
        icon: Icons.error_outline,
        title: 'Refund failed',
        message:
            'The refund could not be completed. Please contact support before trying again.',
      );
    }

    if (_paymentViewModel.isPaid) {
      return const _StatusNotice(
        icon: Icons.check_circle,
        title: 'Appointment paid',
        message:
            'If you cancel this appointment, a Stripe refund will be initiated automatically.',
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final appointment = _viewModel.currentAppointment;

    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    final duration = appointment.endUtc.difference(appointment.startUtc);

    final durationText = duration.inMinutes >= 60
        ? '${duration.inHours} h '
              '${duration.inMinutes.remainder(60)} min'
        : '${duration.inMinutes} min';

    final normalizedStatus = appointment.status.trim().toLowerCase();

    final appointmentAllowsCancel =
        normalizedStatus == 'pending' || normalizedStatus == 'accepted';

    final refundBlocksCancellation =
        _paymentViewModel.isRefundPending ||
        _paymentViewModel.isRefunded ||
        _paymentViewModel.isRefundFailed;

    final canCancel = appointmentAllowsCancel && !refundBlocksCancellation;

    final canPay =
        normalizedStatus == 'accepted' &&
        !_paymentViewModel.isPaid &&
        !_paymentViewModel.hasRefundProcess;

    final canOpenReceipt =
        _paymentViewModel.paymentId != null &&
        (_paymentViewModel.isPaid || _paymentViewModel.hasRefundProcess);

    final canJoinSession =
        appointment.type.trim().toLowerCase() == 'online' &&
        appointment.canAccessSession &&
        appointment.meetingLink != null &&
        appointment.meetingLink!.trim().isNotEmpty &&
        normalizedStatus == 'accepted';

    final canReview = normalizedStatus == 'completed';

    final canOpenChat =
        normalizedStatus == 'accepted' || normalizedStatus == 'completed';

    return Scaffold(
      backgroundColor: _detailsBackground,
      appBar: AppBar(
        title: const Text('Appointment details'),
        backgroundColor: _detailsBackground,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AppointmentHero(
              therapistName: appointment.therapistName,
              status: appointment.status,
              type: appointment.type,
              startsAt: formatter.format(appointment.startUtc.toLocal()),
              price: '${appointment.price.toStringAsFixed(2)} BAM',
            ),

            const SizedBox(height: 16),

            _DetailsSection(
              title: 'Appointment summary',
              icon: Icons.event_note_outlined,
              child: Column(
                children: [
                  _RowItem(label: 'Status', value: appointment.status),
                  const _DetailsDivider(),
                  _RowItem(label: 'Type', value: appointment.type),
                  const _DetailsDivider(),
                  _RowItem(
                    label: 'Start',
                    value: formatter.format(appointment.startUtc.toLocal()),
                  ),
                  const _DetailsDivider(),
                  _RowItem(
                    label: 'End',
                    value: formatter.format(appointment.endUtc.toLocal()),
                  ),
                  const _DetailsDivider(),
                  _RowItem(label: 'Duration', value: durationText),
                  const _DetailsDivider(),
                  _RowItem(
                    label: 'Price',
                    value: '${appointment.price.toStringAsFixed(2)} BAM',
                  ),
                ],
              ),
            ),

            if (appointment.notes != null &&
                appointment.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),

              _DetailsSection(
                title: 'Appointment note',
                icon: Icons.notes_outlined,
                child: Text(
                  appointment.notes!,
                  style: const TextStyle(color: _detailsText, height: 1.45),
                ),
              ),
            ],

            const SizedBox(height: 16),

            _buildPaymentStatusCard(),

            if (appointment.type.trim().toLowerCase() == 'online') ...[
              const SizedBox(height: 16),

              _StatusNotice(
                icon: appointment.canAccessSession
                    ? Icons.video_call
                    : Icons.lock_clock_outlined,
                title: appointment.canAccessSession
                    ? 'Online session available'
                    : 'Online session unavailable',
                message: appointment.canAccessSession
                    ? 'You can now securely join the online session.'
                    : appointment.sessionAccessMessage ??
                          'The online session is not currently available.',
              ),
            ],

            if (appointment.location != null &&
                appointment.location!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              _DetailsSection(
                title: 'Location',
                icon: Icons.location_on_outlined,
                child: Text(
                  appointment.location!,
                  style: const TextStyle(color: _detailsText, height: 1.45),
                ),
              ),
            ],

            const SizedBox(height: 18),

            _DetailsSection(
              title: 'Actions',
              icon: Icons.touch_app_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (canPay) ...[
                    FilledButton.icon(
                      onPressed: _paymentViewModel.isPaying
                          ? null
                          : _payAppointment,
                      icon: _paymentViewModel.isPaying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.payment),
                      label: Text(
                        _paymentViewModel.isPaying
                            ? 'Processing payment...'
                            : 'Pay appointment',
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (canOpenReceipt) ...[
                    OutlinedButton.icon(
                      onPressed: _openReceipt,
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('View receipt'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (appointment.type.trim().toLowerCase() == 'online') ...[
                    FilledButton.tonalIcon(
                      onPressed: _viewModel.isRefreshingSession
                          ? null
                          : _joinSession,
                      icon: _viewModel.isRefreshingSession
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              canJoinSession
                                  ? Icons.video_call
                                  : Icons.lock_clock_outlined,
                            ),
                      label: Text(
                        _viewModel.isRefreshingSession
                            ? 'Checking session access...'
                            : canJoinSession
                            ? 'Join session'
                            : 'Check session access',
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  OutlinedButton.icon(
                    onPressed: canOpenChat
                        ? () {
                            Navigator.of(context).pushNamed(
                              AppRouter.chatDetails,
                              arguments: appointment.id,
                            );
                          }
                        : null,
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: Text(
                      canOpenChat
                          ? 'Open chat'
                          : 'Chat available after acceptance',
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed(AppRouter.myPayments);
                    },
                    icon: const Icon(Icons.payments),
                    label: const Text('Payment history'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed:
                        appointmentAllowsCancel &&
                            !_paymentViewModel.isPaid &&
                            !_paymentViewModel.hasRefundProcess
                        ? () {
                            Navigator.of(context).pushNamed(
                              AppRouter.useMembership,
                              arguments: appointment,
                            );
                          }
                        : null,
                    icon: const Icon(Icons.card_membership),
                    label: Text(
                      _paymentViewModel.isPaid
                          ? 'Appointment already paid'
                          : _paymentViewModel.hasRefundProcess
                          ? 'Refund already processed'
                          : 'Use membership',
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: canReview
                        ? () {
                            Navigator.of(context).pushNamed(
                              AppRouter.createReview,
                              arguments: appointment,
                            );
                          }
                        : null,
                    icon: const Icon(Icons.star_border),
                    label: Text(
                      canReview
                          ? 'Leave review'
                          : 'Review available after completion',
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: canCancel && !_viewModel.isLoading
                        ? _showCancellationDialog
                        : null,
                    icon: _viewModel.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel_outlined),
                    label: Text(
                      refundBlocksCancellation
                          ? 'Refund already requested'
                          : appointmentAllowsCancel
                          ? _paymentViewModel.isPaid
                                ? 'Cancel and request refund'
                                : 'Cancel appointment'
                          : 'Cancellation unavailable',
                    ),
                  ),
                ],
              ),
            ),

            if (_paymentViewModel.errorMessage != null) ...[
              const SizedBox(height: 12),
              _InlineMessage(
                message: _paymentViewModel.errorMessage!,
                icon: Icons.error_outline,
              ),
            ],

            if (_viewModel.errorMessage != null) ...[
              const SizedBox(height: 12),
              _InlineMessage(
                message: _viewModel.errorMessage!,
                icon: Icons.error_outline,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  final String label;
  final String value;

  const _RowItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(
                color: _detailsMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: _detailsText,
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

class _AppointmentHero extends StatelessWidget {
  final String therapistName;
  final String status;
  final String type;
  final String startsAt;
  final String price;

  const _AppointmentHero({
    required this.therapistName,
    required this.status,
    required this.type,
    required this.startsAt,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return _DetailsCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: _detailsLavender,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.calendar_month_outlined,
              size: 38,
              color: _detailsPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _StatusChip(status: status),
          const SizedBox(height: 12),
          Text(
            therapistName,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _detailsText,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(icon: Icons.schedule_outlined, label: startsAt),
              _InfoPill(icon: Icons.spa_outlined, label: type),
              _InfoPill(icon: Icons.payments_outlined, label: price),
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
    return _DetailsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _detailsLavender,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _detailsPrimary, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _detailsText,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _DetailsCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _detailsSurface,
        borderRadius: BorderRadius.circular(_detailsRadius),
        border: Border.all(color: _detailsBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatusNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _StatusNotice({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return _DetailsCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _detailsLavender,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _detailsPrimary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _detailsText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: const TextStyle(color: _detailsMuted, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _detailsLavender,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _detailsBorder),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: _detailsPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _detailsLavender,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _detailsPrimary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: _detailsText,
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

class _InlineMessage extends StatelessWidget {
  final String message;
  final IconData icon;

  const _InlineMessage({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.onErrorContainer, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsDivider extends StatelessWidget {
  const _DetailsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 18, color: _detailsBorder);
  }
}
