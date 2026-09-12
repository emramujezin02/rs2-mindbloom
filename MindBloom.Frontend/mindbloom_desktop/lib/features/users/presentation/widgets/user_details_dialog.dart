import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/admin_status_badge.dart';
import '../../data/models/admin_user_audit_model.dart';
import '../../data/models/admin_user_details_model.dart';
import '../../../../core/widgets/app_responsive_dialog_content.dart';

class UserDetailsDialog extends StatelessWidget {
  final AdminUserDetailsModel user;

  const UserDetailsDialog({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd.MM.yyyy.');
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.onPrimaryContainer,
            child: Text(
              user.fullName.trim().isEmpty
                  ? '?'
                  : user.fullName.trim()[0].toUpperCase(),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('User details')),
        ],
      ),
      content: AppResponsiveDialogContent(
        preferredWidth: 680,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Wrap(
                  spacing: 18,
                  runSpacing: 14,
                  children: [
                    _item(context, 'Full name', user.fullName),
                    _item(context, 'Email', user.email),
                    _item(context, 'Phone', user.phoneNumber ?? '-'),
                    _item(context, 'Gender', user.gender),
                    _item(
                      context,
                      'Date of birth',
                      formatter.format(user.dateOfBirth.toLocal()),
                    ),
                    _item(
                      context,
                      'Registered',
                      formatter.format(user.createdAtUtc.toLocal()),
                    ),
                    _item(
                      context,
                      'Last login',
                      user.lastLoginAtUtc == null
                          ? 'Never'
                          : formatter.format(user.lastLoginAtUtc!.toLocal()),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    AdminStatusBadge(
                      label: user.role,
                      tone: user.role == 'Admin'
                          ? AdminStatusTone.info
                          : user.role == 'Therapist'
                          ? AdminStatusTone.success
                          : AdminStatusTone.neutral,
                    ),
                    AdminStatusBadge(
                      label: user.isEmailVerified
                          ? 'Email verified'
                          : 'Email unverified',
                      tone: user.isEmailVerified
                          ? AdminStatusTone.success
                          : AdminStatusTone.warning,
                      icon: user.isEmailVerified
                          ? Icons.verified_outlined
                          : Icons.warning_amber_outlined,
                    ),
                    AdminStatusBadge(
                      label: user.isTwoFactorEnabled
                          ? 'Two factor enabled'
                          : 'Two factor disabled',
                      tone: user.isTwoFactorEnabled
                          ? AdminStatusTone.success
                          : AdminStatusTone.neutral,
                    ),
                    AdminStatusBadge(
                      label: user.isBlocked ? 'Blocked' : 'Active',
                      tone: user.isBlocked
                          ? AdminStatusTone.danger
                          : AdminStatusTone.success,
                      icon: user.isBlocked
                          ? Icons.block
                          : Icons.check_circle_outline,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
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

  Widget _item(BuildContext context, String title, String value) {
    return SizedBox(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(value.isEmpty ? '-' : value),
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
