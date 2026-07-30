import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/admin_user_audit_model.dart';
import '../../data/models/admin_user_details_model.dart';

class UserDetailsDialog extends StatelessWidget {
  final AdminUserDetailsModel user;

  const UserDetailsDialog({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd.MM.yyyy.');

    return AlertDialog(
      title: const Text('User details'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _item('Full name', user.fullName),
              _item('Email', user.email),
              _item('Phone', user.phoneNumber ?? '-'),
              _item('Role', user.role),
              _item('Gender', user.gender),
              _item(
                'Date of birth',
                formatter.format(user.dateOfBirth.toLocal()),
              ),
              _item(
                'Registered',
                formatter.format(user.createdAtUtc.toLocal()),
              ),
              _item(
                'Last login',
                user.lastLoginAtUtc == null
                    ? 'Never'
                    : formatter.format(user.lastLoginAtUtc!.toLocal()),
              ),
              _item('Email verified', user.isEmailVerified ? 'Yes' : 'No'),
              _item(
                'Two factor',
                user.isTwoFactorEnabled ? 'Enabled' : 'Disabled',
              ),
              _item('Account', user.isBlocked ? 'Blocked' : 'Active'),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Audit history',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (user.auditHistory.isEmpty)
                const Text('No administrative changes have been recorded.')
              else
                ...user.auditHistory.map((audit) => _auditItem(context, audit)),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _item(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text(value),
        ],
      ),
    );
  }

  Widget _auditItem(BuildContext context, AdminUserAuditModel audit) {
    final dateFormatter = DateFormat('dd.MM.yyyy. HH:mm');

    final actorName = audit.changedByName.trim().isEmpty
        ? audit.changedByEmail
        : audit.changedByName;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatAuditAction(audit.action),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  dateFormatter.format(audit.changedAtUtc.toLocal()),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Changed by: $actorName'),
            if (audit.changedByEmail.isNotEmpty &&
                audit.changedByEmail != actorName) ...[
              const SizedBox(height: 3),
              Text(
                audit.changedByEmail,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (audit.reason != null && audit.reason!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Reason: ${audit.reason}'),
            ],
            if (audit.previousValues != null &&
                audit.previousValues!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: const Text('Previous values'),
                children: [SelectableText(audit.previousValues!)],
              ),
            ],
            if (audit.newValues != null && audit.newValues!.trim().isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: const Text('New values'),
                children: [SelectableText(audit.newValues!)],
              ),
          ],
        ),
      ),
    );
  }

  String _formatAuditAction(String action) {
    switch (action) {
      case 'BasicDataUpdated':
        return 'Basic information updated';

      case 'AccountBlocked':
        return 'Account blocked';

      case 'AccountUnblocked':
        return 'Account unblocked';

      case 'AccountActivated':
        return 'Account activated';

      case 'AccountDeactivated':
        return 'Account deactivated';

      case 'PasswordResetRequested':
        return 'Password reset requested';

      default:
        return action;
    }
  }
}
