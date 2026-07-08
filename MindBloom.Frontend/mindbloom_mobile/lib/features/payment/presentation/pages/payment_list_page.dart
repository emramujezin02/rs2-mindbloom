import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../viewmodels/payment_list_viewmodel.dart';

class PaymentListPage extends StatefulWidget {
  const PaymentListPage({super.key});

  @override
  State<PaymentListPage> createState() => _PaymentListPageState();
}

class _PaymentListPageState extends State<PaymentListPage> {
  final PaymentListViewModel _viewModel = AppInjection.createPaymentViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_refresh);

    _viewModel.loadPayments();
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

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd.MM.yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Payment history')),
      body: _viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _viewModel.payments.length,
              itemBuilder: (context, index) {
                final payment = _viewModel.payments[index];

                return Card(
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    leading: const Icon(Icons.payments),
                    title: Text(payment.therapistName),
                    subtitle: Text(
                      formatter.format(payment.createdAtUtc.toLocal()),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${payment.amount.toStringAsFixed(2)} KM'),
                        Text(payment.status),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
