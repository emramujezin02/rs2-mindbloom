import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../data/models/membership_receipt_model.dart';
import '../viewmodels/membership_viewmodel.dart';

class MembershipReceiptPage extends StatefulWidget {
  final int membershipId;

  const MembershipReceiptPage({super.key, required this.membershipId});

  @override
  State<MembershipReceiptPage> createState() => _MembershipReceiptPageState();
}

class _MembershipReceiptPageState extends State<MembershipReceiptPage> {
  final MembershipViewModel _viewModel =
      AppInjection.createMembershipViewModel();

  MembershipReceiptModel? _receipt;

  String? _error;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _loadReceipt();
  }

  Future<void> _loadReceipt() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final receipt = await _viewModel.getReceipt(widget.membershipId);

      if (!mounted) {
        return;
      }

      setState(() {
        _receipt = receipt;
      });
    } catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = exception.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Membership receipt')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadReceipt,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final receipt = _receipt;

    if (receipt == null) {
      return const Center(child: Text('Receipt could not be loaded.'));
    }

    final dateFormatter = DateFormat('dd.MM.yyyy. HH:mm');

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.receipt_long, size: 70),

        const SizedBox(height: 16),

        Text(
          receipt.invoiceNumber,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 20),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _ReceiptRow(label: 'Client', value: receipt.clientName),
                const Divider(),
                _ReceiptRow(label: 'Therapist', value: receipt.therapistName),
                const Divider(),
                _ReceiptRow(label: 'Package', value: receipt.planType),
                const Divider(),
                _ReceiptRow(
                  label: 'Sessions',
                  value: receipt.totalSessions.toString(),
                ),
                const Divider(),
                _ReceiptRow(
                  label: 'Amount',
                  value:
                      '${receipt.amount.toStringAsFixed(2)} '
                      '${receipt.currency}',
                ),
                const Divider(),
                _ReceiptRow(label: 'Status', value: receipt.paymentStatus),
                const Divider(),
                _ReceiptRow(
                  label: 'Paid at',
                  value: dateFormatter.format(receipt.paidAtUtc.toLocal()),
                ),
                if (receipt.expiresAtUtc != null) ...[
                  const Divider(),
                  _ReceiptRow(
                    label: 'Expires',
                    value: dateFormatter.format(
                      receipt.expiresAtUtc!.toLocal(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReceiptRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(child: Text(value, textAlign: TextAlign.right)),
      ],
    );
  }
}
