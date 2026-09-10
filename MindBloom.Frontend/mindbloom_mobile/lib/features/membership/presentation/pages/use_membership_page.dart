import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../appointment/data/models/appointment_model.dart';
import '../viewmodels/membership_viewmodel.dart';

const _useMembershipBackground = Color(0xFFFCFAFF);
const _useMembershipSurface = Color(0xFFFFFFFF);
const _useMembershipLavender = Color(0xFFF6F0FC);
const _useMembershipBorder = Color(0xFFE7DDF1);
const _useMembershipPrimary = Color(0xFF6D4F91);
const _useMembershipText = Color(0xFF372D45);
const _useMembershipMuted = Color(0xFF6C6278);
const _useMembershipRadius = 20.0;

class UseMembershipPage extends StatefulWidget {
  final AppointmentModel appointment;

  const UseMembershipPage({super.key, required this.appointment});

  @override
  State<UseMembershipPage> createState() => _UseMembershipPageState();
}

class _UseMembershipPageState extends State<UseMembershipPage> {
  final MembershipViewModel _viewModel =
      AppInjection.createMembershipViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_refresh);
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

  Future<void> _useMembership() async {
    if (_viewModel.isUsingMembership) {
      return;
    }

    final success = await _viewModel.useMembership(
      appointmentId: widget.appointment.id,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Membership used successfully.')),
      );

      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRouter.myAppointments, (route) => false);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_viewModel.error ?? 'Unable to use membership.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canUse = widget.appointment.status.toLowerCase() == 'accepted';

    return Scaffold(
      backgroundColor: _useMembershipBackground,
      appBar: AppBar(
        title: const Text('Use membership'),
        backgroundColor: _useMembershipBackground,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _UseMembershipPanel(
            therapistName: widget.appointment.therapistName,
            status: widget.appointment.status,
            price: '${widget.appointment.price.toStringAsFixed(2)} BAM',
          ),
          const SizedBox(height: 20),
          if (_viewModel.error != null)
            AppInlineError(
              title: 'Membership could not be used',
              error: _viewModel.error,
              onRetry: _useMembership,
              margin: const EdgeInsets.only(bottom: 12),
            ),
          _UseMembershipCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: canUse && !_viewModel.isUsingMembership
                      ? _useMembership
                      : null,
                  icon: _viewModel.isUsingMembership
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.card_membership),
                  label: Text(
                    _viewModel.isUsingMembership
                        ? 'Processing...'
                        : 'Use membership',
                  ),
                ),
                if (!canUse) ...[
                  const SizedBox(height: 12),
                  const _UseMembershipNotice(
                    icon: Icons.info_outline,
                    message:
                        'Membership can only be used for accepted appointments.',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UseMembershipPanel extends StatelessWidget {
  final String therapistName;
  final String status;
  final String price;

  const _UseMembershipPanel({
    required this.therapistName,
    required this.status,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return _UseMembershipCard(
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: _useMembershipLavender,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.card_membership,
              size: 38,
              color: _useMembershipPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            therapistName,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _useMembershipText,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'If you have an active membership for this therapist, one session will be used for this appointment.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _useMembershipMuted, height: 1.4),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _UseMembershipPill(icon: Icons.verified_outlined, label: status),
              _UseMembershipPill(icon: Icons.payments_outlined, label: price),
            ],
          ),
        ],
      ),
    );
  }
}

class _UseMembershipCard extends StatelessWidget {
  final Widget child;

  const _UseMembershipCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _useMembershipSurface,
        borderRadius: BorderRadius.circular(_useMembershipRadius),
        border: Border.all(color: _useMembershipBorder),
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

class _UseMembershipPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _UseMembershipPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _useMembershipLavender,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _useMembershipPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: _useMembershipText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _UseMembershipNotice extends StatelessWidget {
  final IconData icon;
  final String message;

  const _UseMembershipNotice({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colorScheme.error, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: colorScheme.error, height: 1.35),
          ),
        ),
      ],
    );
  }
}
