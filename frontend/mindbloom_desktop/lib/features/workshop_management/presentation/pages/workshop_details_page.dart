import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mindbloom_desktop/features/workshop_management/presentation/viewmodels/workshop_details_viewmodel.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/admin_status_badge.dart';
import '../../../../core/widgets/admin_table_state.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/app_responsive_dialog_content.dart';
import '../../data/models/workshop_model.dart';
import '../../data/models/workshop_registration_model.dart';

class WorkshopDetailsPage extends StatefulWidget {
  final int workshopId;

  const WorkshopDetailsPage({super.key, required this.workshopId});

  @override
  State<WorkshopDetailsPage> createState() => _WorkshopDetailsPageState();
}

class _WorkshopDetailsPageState extends State<WorkshopDetailsPage> {
  late final WorkshopDetailsViewModel _viewModel;

  @override
  void initState() {
    super.initState();

    _viewModel = AppInjection.createWorkshopDetailsViewModel();

    _viewModel.addListener(_onViewModelChanged);

    _viewModel.load(widget.workshopId);
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

  Future<void> _editWorkshop() async {
    final changed = await Navigator.of(
      context,
    ).pushNamed(AppRouter.workshopManagementForm, arguments: widget.workshopId);

    if (changed == true) {
      await _viewModel.refresh(widget.workshopId);
    }
  }

  Future<void> _cancelWorkshop() async {
    final reasonController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel workshop'),
          content: AppResponsiveDialogContent(
            preferredWidth: 480,
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: reasonController,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Cancellation reason',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  final reason = value?.trim() ?? '';

                  if (reason.isEmpty) {
                    return 'Cancellation reason is required.';
                  }

                  if (reason.length < 5) {
                    return 'Reason must contain at least 5 characters.';
                  }

                  return null;
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                Navigator.of(dialogContext).pop(reasonController.text.trim());
              },
              child: const Text('Confirm cancellation'),
            ),
          ],
        );
      },
    );

    reasonController.dispose();

    if (reason == null || !mounted) {
      return;
    }

    final success = await _viewModel.cancel(
      workshopId: widget.workshopId,
      reason: reason,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workshop cancelled successfully.')),
      );
    }
  }

  Future<void> _deactivateWorkshop() async {
    final workshop = _viewModel.workshop;

    if (workshop == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Deactivate workshop'),
          content: Text(
            'Deactivate "${workshop.title}"?\n\n'
            'The workshop will no longer be available for new registrations.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Back'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.pause_circle_outline),
              label: const Text('Deactivate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await _viewModel.deactivate(widget.workshopId);

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workshop deactivated successfully.')),
      );
    }
  }

  Future<void> _activateWorkshop() async {
    final workshop = _viewModel.workshop;

    if (workshop == null) {
      return;
    }

    if (!workshop.startUtc.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A past workshop cannot be activated again.'),
        ),
      );

      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Activate workshop'),
          content: Text(
            'Activate "${workshop.title}"?\n\n'
            'The workshop will become available again if all backend business rules are satisfied.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Back'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Activate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await _viewModel.activate(widget.workshopId);

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workshop activated successfully.')),
      );
    }
  }

  Future<void> _deleteWorkshop() async {
    final workshop = _viewModel.workshop;

    if (workshop == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete workshop'),
          content: Text(
            'Are you sure you want to delete "${workshop.title}"?\n\n'
            'Deletion is allowed only when there are no active registrations.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Back'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await _viewModel.delete(widget.workshopId);

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workshop deleted successfully.')),
      );

      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workshop details')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.workshop == null) {
      return const AdminTableLoadingState(
        message: 'Loading workshop details...',
      );
    }

    if (_viewModel.error != null && _viewModel.workshop == null) {
      return AdminTableErrorState(
        message: _viewModel.error!,
        onRetry: () {
          _viewModel.load(widget.workshopId);
        },
      );
    }

    final workshop = _viewModel.workshop;

    if (workshop == null) {
      return const AdminTableEmptyState(
        title: 'Workshop not found',
        message: 'The selected workshop could not be displayed.',
        icon: Icons.event_busy_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: () {
        return _viewModel.refresh(widget.workshopId);
      },
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _WorkshopDetailsCard(workshop: workshop),

          const SizedBox(height: 16),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (workshop.isScheduled)
                FilledButton.icon(
                  onPressed: _viewModel.isProcessing ? null : _editWorkshop,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit workshop'),
                ),

              if (workshop.isScheduled)
                OutlinedButton.icon(
                  onPressed: _viewModel.isProcessing
                      ? null
                      : _deactivateWorkshop,
                  icon: const Icon(Icons.pause_circle_outline),
                  label: const Text('Deactivate'),
                ),

              if (workshop.isInactive &&
                  workshop.startUtc.isAfter(DateTime.now()))
                FilledButton.icon(
                  onPressed: _viewModel.isProcessing ? null : _activateWorkshop,
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Activate'),
                ),

              if (workshop.isInactive &&
                  workshop.startUtc.isAfter(DateTime.now()))
                FilledButton.icon(
                  onPressed: _viewModel.isProcessing ? null : _editWorkshop,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit workshop'),
                ),

              if (workshop.isScheduled || workshop.isInactive)
                OutlinedButton.icon(
                  onPressed: _viewModel.isProcessing ? null : _cancelWorkshop,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel workshop'),
                ),

              if (workshop.registeredCount == 0)
                OutlinedButton.icon(
                  onPressed: _viewModel.isProcessing ? null : _deleteWorkshop,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete workshop'),
                ),
            ],
          ),

          if (_viewModel.error != null) ...[
            const SizedBox(height: 16),
            AppErrorBanner(message: _viewModel.error!),
          ],

          const SizedBox(height: 24),

          Text(
            'Registrations '
            '(${_viewModel.registrationTotalCount})',
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          _buildRegistrations(),

          const SizedBox(height: 12),

          _buildRegistrationPagination(),
        ],
      ),
    );
  }

  Widget _buildRegistrations() {
    if (_viewModel.isLoading && _viewModel.registrations.isEmpty) {
      return const AdminTableLoadingState(
        message: 'Loading workshop registrations...',
      );
    }

    if (_viewModel.registrations.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('This workshop does not have registrations yet.'),
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 28,
          horizontalMargin: 24,
          headingRowHeight: 54,
          dataRowMinHeight: 60,
          dataRowMaxHeight: 72,
          columns: const [
            DataColumn(label: Text('Participant')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Registered at')),
            DataColumn(label: Text('Cancelled at')),
          ],
          rows: _viewModel.registrations.map((registration) {
            return _buildRegistrationRow(registration);
          }).toList(),
        ),
      ),
    );
  }

  DataRow _buildRegistrationRow(WorkshopRegistrationModel registration) {
    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return DataRow(
      cells: [
        DataCell(
          SizedBox(
            width: 180,
            child: Text(
              registration.clientName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 220,
            child: Text(
              registration.clientEmail,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(
          AdminStatusBadge(
            label: registration.status,
            tone: _statusTone(registration.status),
            icon: _statusIcon(registration.status),
          ),
        ),
        DataCell(
          Text(formatter.format(registration.registeredAtUtc.toLocal())),
        ),
        DataCell(
          Text(
            registration.cancelledAtUtc == null
                ? '—'
                : formatter.format(registration.cancelledAtUtc!.toLocal()),
          ),
        ),
      ],
    );
  }

  Widget _buildRegistrationPagination() {
    final displayedTotalPages = _viewModel.registrationTotalPages < 1
        ? 1
        : _viewModel.registrationTotalPages;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          tooltip: 'Previous registrations page',
          onPressed:
              _viewModel.isLoading || _viewModel.registrationPageNumber <= 1
              ? null
              : () {
                  _viewModel.previousRegistrationsPage(widget.workshopId);
                },
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          'Page ${_viewModel.registrationPageNumber} '
          'of $displayedTotalPages',
        ),
        IconButton(
          tooltip: 'Next registrations page',
          onPressed:
              _viewModel.isLoading ||
                  _viewModel.registrationPageNumber >=
                      _viewModel.registrationTotalPages
              ? null
              : () {
                  _viewModel.nextRegistrationsPage(widget.workshopId);
                },
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _WorkshopDetailsCard extends StatelessWidget {
  final WorkshopModel workshop;

  const _WorkshopDetailsCard({required this.workshop});

  String _resolveImageUrl(String imageUrl) {
    final normalized = imageUrl.trim();

    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }

    final apiUri = Uri.parse(ApiConstants.apiBaseUrl);

    return apiUri
        .replace(
          path: normalized.startsWith('/') ? normalized : '/$normalized',
          query: null,
          fragment: null,
        )
        .toString();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;

    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0 && minutes > 0) {
      return '$hours h $minutes min';
    }

    if (hours > 0) {
      return '$hours h';
    }

    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (workshop.imageUrl != null &&
                workshop.imageUrl!.trim().isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  _resolveImageUrl(workshop.imageUrl!),
                  height: 320,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined, size: 48),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),
            ],
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  workshop.title,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AdminStatusBadge(
                  label: workshop.status,
                  tone: _statusTone(workshop.status),
                  icon: _statusIcon(workshop.status),
                ),
                AdminStatusBadge(
                  label: workshop.type,
                  tone: AdminStatusTone.info,
                  icon: workshop.isOnline
                      ? Icons.videocam_outlined
                      : Icons.location_on_outlined,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(workshop.description),
            const SizedBox(height: 20),
            _DetailsRow(
              label: 'Start',
              value: formatter.format(workshop.startUtc.toLocal()),
            ),
            _DetailsRow(
              label: 'End',
              value: formatter.format(workshop.endUtc.toLocal()),
            ),
            _DetailsRow(
              label: 'Duration',
              value: _formatDuration(workshop.duration),
            ),

            _DetailsRow(
              label: 'Registration deadline',
              value: formatter.format(
                workshop.registrationDeadlineUtc.toLocal(),
              ),
            ),
            _DetailsRow(label: 'Organizer', value: workshop.organizerName),
            _DetailsRow(label: 'Presenter', value: workshop.presenterName),
            _DetailsRow(label: 'Capacity', value: workshop.capacity.toString()),
            _DetailsRow(
              label: 'Active registrations',
              value: workshop.registeredCount.toString(),
            ),
            _DetailsRow(
              label: 'Available seats',
              value: workshop.availableSeats.toString(),
            ),
            _DetailsRow(
              label: 'Price',
              value: '${workshop.price.toStringAsFixed(2)} KM',
            ),
            if (workshop.location != null &&
                workshop.location!.trim().isNotEmpty)
              _DetailsRow(label: 'Location', value: workshop.location!),
            if (workshop.onlineLink != null &&
                workshop.onlineLink!.trim().isNotEmpty)
              _DetailsRow(label: 'Online link', value: workshop.onlineLink!),
            _DetailsRow(
              label: 'Created',
              value: formatter.format(workshop.createdAtUtc.toLocal()),
            ),
            if (workshop.updatedAtUtc != null)
              _DetailsRow(
                label: 'Last updated',
                value: formatter.format(workshop.updatedAtUtc!.toLocal()),
              ),
            if (workshop.statusChangeReason != null &&
                workshop.statusChangeReason!.trim().isNotEmpty)
              _DetailsRow(
                label: 'Status change reason',
                value: workshop.statusChangeReason!,
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailsRow extends StatelessWidget {
  final String label;

  final String value;

  const _DetailsRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;

        final labelWidget = Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        );

        final valueWidget = SelectableText(value);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
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
                    SizedBox(width: 190, child: labelWidget),
                    Expanded(child: valueWidget),
                  ],
                ),
        );
      },
    );
  }
}

AdminStatusTone _statusTone(String status) {
  final normalized = status.trim().toLowerCase();

  if (normalized == 'scheduled' ||
      normalized == 'active' ||
      normalized == 'registered') {
    return AdminStatusTone.success;
  }

  if (normalized == 'completed') {
    return AdminStatusTone.info;
  }

  if (normalized == 'cancelled' || normalized == 'inactive') {
    return AdminStatusTone.danger;
  }

  return AdminStatusTone.neutral;
}

IconData _statusIcon(String status) {
  final normalized = status.trim().toLowerCase();

  if (normalized == 'scheduled' ||
      normalized == 'active' ||
      normalized == 'registered') {
    return Icons.event_available;
  }

  if (normalized == 'completed') {
    return Icons.check_circle;
  }

  if (normalized == 'cancelled' || normalized == 'inactive') {
    return Icons.cancel;
  }

  return Icons.info_outline;
}
