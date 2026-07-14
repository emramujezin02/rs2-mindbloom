import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../therapist/data/models/therapist_model.dart';
import '../../data/models/membership_plan_model.dart';
import '../viewmodels/membership_viewmodel.dart';

class PurchaseMembershipPage extends StatefulWidget {
  final TherapistModel therapist;

  const PurchaseMembershipPage({super.key, required this.therapist});

  @override
  State<PurchaseMembershipPage> createState() => _PurchaseMembershipPageState();
}

class _PurchaseMembershipPageState extends State<PurchaseMembershipPage> {
  final MembershipViewModel _viewModel =
      AppInjection.createMembershipViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);

    _viewModel.loadPlans(widget.therapist.id);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _purchase(MembershipPlanModel plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm membership purchase'),
          content: Text(
            'You are purchasing ${plan.name} for '
            '${plan.price.toStringAsFixed(2)} KM.\n\n'
            'The price is calculated by the server. '
            'Your membership will become active only after Stripe confirms the payment.',
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

    final success = await _viewModel.purchaseMembership(
      therapistId: widget.therapist.id,

      planType: plan.planType,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Membership purchased and activated successfully.'),
        ),
      );

      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRouter.myMemberships, (route) => false);

      return;
    }

    if (_viewModel.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_viewModel.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Membership packages')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.plans.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.error != null && _viewModel.plans.isEmpty) {
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
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  _viewModel.loadPlans(widget.therapist.id);
                },
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_viewModel.plans.isEmpty) {
      return const Center(child: Text('No membership packages are available.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),

      itemCount: _viewModel.plans.length,

      separatorBuilder: (context, index) => const SizedBox(height: 12),

      itemBuilder: (context, index) {
        final plan = _viewModel.plans[index];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text('${plan.totalSessions} total sessions'),

                Text('${plan.freeSessions} free sessions included'),

                const SizedBox(height: 8),

                Text(
                  'Total price: '
                  '${plan.price.toStringAsFixed(2)} KM',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                Text(
                  'Price per session: '
                  '${plan.pricePerSession.toStringAsFixed(2)} KM',
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _viewModel.isPurchasing
                        ? null
                        : () {
                            _purchase(plan);
                          },
                    icon: _viewModel.isPurchasing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.payment),
                    label: Text(
                      _viewModel.isPurchasing
                          ? 'Processing payment...'
                          : 'Purchase with Stripe',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
