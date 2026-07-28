import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../appointment/data/models/appointment_model.dart';
import '../viewmodels/membership_viewmodel.dart';

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
      appBar: AppBar(title: const Text('Use membership')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 28),
          const Icon(Icons.card_membership, size: 68),
          const SizedBox(height: 18),
          Text(
            widget.appointment.therapistName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          const Text(
            'If you have an active membership for this '
            'therapist, one session will be used for this '
            'appointment.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (_viewModel.error != null)
            AppInlineError(
              title: 'Membership could not be used',
              error: _viewModel.error,
              onRetry: _useMembership,
              margin: const EdgeInsets.only(bottom: 12),
            ),
          ElevatedButton.icon(
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
              _viewModel.isUsingMembership ? 'Processing...' : 'Use membership',
            ),
          ),
          const SizedBox(height: 12),
          if (!canUse)
            const Text(
              'Membership can only be used for accepted '
              'appointments.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
        ],
      ),
    );
  }
}
