import 'package:flutter/material.dart';

Future<bool?> showAppointmentRejectionDialog(
  BuildContext context, {
  required Future<String?> Function(String reason) onReject,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => AppointmentRejectionDialog(onReject: onReject),
);

class AppointmentRejectionDialog extends StatefulWidget {
  final Future<String?> Function(String reason) onReject;
  const AppointmentRejectionDialog({super.key, required this.onReject});

  @override
  State<AppointmentRejectionDialog> createState() =>
      _AppointmentRejectionDialogState();
}

class _AppointmentRejectionDialogState
    extends State<AppointmentRejectionDialog> {
  final _controller = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _reject() async {
    if (_sending || !_form.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    String? error;
    try {
      error = await widget.onReject(_controller.text.trim());
    } catch (_) {
      error = 'The appointment could not be rejected. Please try again.';
    }
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _sending = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sending,
    child: AlertDialog(
      title: const Text('Reject appointment?'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _controller,
              enabled: !_sending,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Reason for rejection',
              ),
              validator: (value) {
                final reason = value?.trim() ?? '';
                if (reason.length < 5) {
                  return 'Enter a reason with at least 5 characters.';
                }
                if (reason.length > 500) {
                  return 'The reason may contain at most 500 characters.';
                }
                return null;
              },
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: _sending ? null : _reject,
          child: _sending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Reject'),
        ),
      ],
    ),
  );
}
