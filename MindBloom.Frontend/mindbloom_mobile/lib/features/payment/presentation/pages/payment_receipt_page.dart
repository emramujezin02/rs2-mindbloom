import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../data/models/payment_receipt_model.dart';
import '../viewmodels/payment_list_viewmodel.dart';

class PaymentReceiptPage extends StatefulWidget {
  final int paymentId;

  const PaymentReceiptPage({super.key, required this.paymentId});

  @override
  State<PaymentReceiptPage> createState() => _PaymentReceiptPageState();
}

class _PaymentReceiptPageState extends State<PaymentReceiptPage> {
  final PaymentListViewModel viewModel = AppInjection.createPaymentViewModel();

  PaymentReceiptModel? receipt;

  @override
  void initState() {
    super.initState();

    load();
  }

  Future<void> load() async {
    receipt = await viewModel.loadReceipt(widget.paymentId);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (receipt == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final date = DateFormat("dd.MM.yyyy HH:mm");

    return Scaffold(
      appBar: AppBar(title: const Text("Receipt")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            receipt!.invoiceNumber,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),

          const SizedBox(height: 20),

          ListTile(
            title: const Text("Client"),
            subtitle: Text(receipt!.clientName),
          ),

          ListTile(
            title: const Text("Therapist"),
            subtitle: Text(receipt!.therapistName),
          ),

          ListTile(
            title: const Text("Amount"),
            subtitle: Text("${receipt!.amount.toStringAsFixed(2)} KM"),
          ),

          ListTile(
            title: const Text("Status"),
            subtitle: Text(receipt!.status),
          ),

          ListTile(
            title: const Text("Payment date"),
            subtitle: Text(date.format(receipt!.paymentDateUtc)),
          ),

          ListTile(
            title: const Text("Appointment"),
            subtitle: Text(
              "${date.format(receipt!.appointmentStartUtc)} - ${date.format(receipt!.appointmentEndUtc)}",
            ),
          ),

          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("PDF receipt is not available yet."),
                ),
              );
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text("Open PDF"),
          ),
        ],
      ),
    );
  }
}
