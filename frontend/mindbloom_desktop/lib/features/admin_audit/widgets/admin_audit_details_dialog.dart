import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mindbloom_desktop/core/widgets/app_responsive_dialog_content.dart';
import 'package:mindbloom_desktop/features/admin_audit/data/models/admin_audit_log_model.dart';

class AdminAuditDetailsDialog extends StatelessWidget {
  final AdminAuditLogModel audit;

  const AdminAuditDetailsDialog({super.key, required this.audit});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd.MM.yyyy. HH:mm:ss');

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.manage_search),
          SizedBox(width: 10),
          Text('Detalji audit zapisa'),
        ],
      ),
      content: AppResponsiveDialogContent(
        preferredWidth: 760,
        child: SingleChildScrollView(
          child: SelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'Administrator', value: audit.adminName),
                _InfoRow(label: 'Email', value: audit.adminEmail),
                _InfoRow(label: 'Akcija', value: audit.action),
                _InfoRow(label: 'Entitet', value: audit.entityType),
                _InfoRow(label: 'ID entiteta', value: audit.entityId ?? '—'),
                _InfoRow(
                  label: 'Datum i vrijeme',
                  value: formatter.format(audit.occurredAtUtc.toLocal()),
                ),
                _InfoRow(label: 'HTTP metoda', value: audit.httpMethod),
                _InfoRow(label: 'Request path', value: audit.requestPath),
                _InfoRow(label: 'IP adresa', value: audit.ipAddress ?? '—'),
                _InfoRow(label: 'Correlation ID', value: audit.correlationId),
                _InfoRow(
                  label: 'HTTP status',
                  value: audit.statusCode.toString(),
                ),
                _InfoRow(
                  label: 'Rezultat',
                  value: audit.isSuccessful ? 'Uspješno' : 'Neuspješno',
                ),
                _InfoRow(
                  label: 'Poruka rezultata',
                  value: audit.resultMessage ?? '—',
                ),
                const Divider(height: 32),
                _JsonSection(
                  title: 'Prethodne vrijednosti',
                  value: audit.previousValues,
                ),
                const SizedBox(height: 20),
                _JsonSection(title: 'Nove vrijednosti', value: audit.newValues),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Zatvori'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;

        final labelWidget = Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        );

        final valueWidget = SelectableText(value);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    labelWidget,
                    const SizedBox(height: 4),
                    valueWidget,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 175, child: labelWidget),
                    Expanded(child: valueWidget),
                  ],
                ),
        );
      },
    );
  }
}

class _JsonSection extends StatelessWidget {
  final String title;
  final String? value;

  const _JsonSection({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final normalized = value?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            normalized.isEmpty ? 'Nema sačuvanih podataka.' : normalized,
            style: const TextStyle(fontFamily: 'monospace', height: 1.35),
          ),
        ),
      ],
    );
  }
}
