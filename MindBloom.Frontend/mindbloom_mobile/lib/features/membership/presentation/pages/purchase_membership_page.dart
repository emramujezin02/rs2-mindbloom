import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../therapist/data/models/therapist_model.dart';
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
    _viewModel.addListener(_refresh);
    _viewModel.loadPlans(widget.therapist.id);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _purchase(int planType) async {
    final success = await _viewModel.purchaseMembership(
      therapistId: widget.therapist.id,
      planType: planType,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Membership purchased successfully.')),
      );

      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRouter.myMemberships, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Membership packages')),
      body: _viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _viewModel.error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _viewModel.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            )
          : ListView.separated(
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
                          'Total price: ${plan.price.toStringAsFixed(2)} KM',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Price per session: ${plan.pricePerSession.toStringAsFixed(2)} KM',
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _viewModel.isLoading
                              ? null
                              : () => _purchase(plan.planType),
                          child: const Text('Purchase package'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
