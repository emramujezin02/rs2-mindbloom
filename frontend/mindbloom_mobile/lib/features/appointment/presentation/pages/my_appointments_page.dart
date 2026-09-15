import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../data/models/appointment_model.dart';
import '../viewmodels/my_appointments_viewmodel.dart';

const _appointmentsBackground = Color(0xFFFCFAFF);
const _appointmentsSurface = Color(0xFFFFFFFF);
const _appointmentsLavender = Color(0xFFF6F0FC);
const _appointmentsBorder = Color(0xFFE7DDF1);
const _appointmentsPrimary = Color(0xFF6D4F91);
const _appointmentsText = Color(0xFF372D45);
const _appointmentsMuted = Color(0xFF6C6278);
const _appointmentsRadius = 20.0;

class MyAppointmentsPage extends StatefulWidget {
  const MyAppointmentsPage({super.key});

  @override
  State<MyAppointmentsPage> createState() => _MyAppointmentsPageState();
}

class _MyAppointmentsPageState extends State<MyAppointmentsPage> {
  final MyAppointmentsViewModel _viewModel =
      AppInjection.createMyAppointmentsViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onChanged);

    _viewModel.loadAppointments();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);

    _viewModel.dispose();

    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refresh() async {
    await _viewModel.loadAppointments();
  }

  Future<void> _pickFilterDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _viewModel.selectedDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: 'Filter appointments by date',
    );

    if (picked == null) {
      return;
    }

    _viewModel.setDateFilter(picked);
  }

  Future<void> _openAppointment(AppointmentModel appointment) async {
    await Navigator.of(
      context,
    ).pushNamed(AppRouter.appointmentDetails, arguments: appointment);

    if (!mounted) {
      return;
    }

    await _viewModel.loadAppointments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _appointmentsBackground,
      appBar: AppBar(
        title: const Text('My appointments'),
        backgroundColor: _appointmentsBackground,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _viewModel.isLoading ? null : _refresh,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.appointments.isEmpty) {
      return const AppLoadingWidget.skeleton(
        message: 'Loading appointments...',
        skeletonItemCount: 5,
      );
    }

    if (_viewModel.error != null && _viewModel.appointments.isEmpty) {
      return AppErrorWidget(
        title: 'Appointments could not be loaded',
        error: _viewModel.error,
        onRetry: _refresh,
      );
    }

    if (_viewModel.appointments.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: const AppEmptyStateWidget(
          title: 'No appointments yet',
          message: 'Your scheduled sessions will appear here.',
          icon: Icons.event_busy_outlined,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _buildFilters(),

          const SizedBox(height: 20),

          if (_viewModel.error != null)
            _InlineError(message: _viewModel.error!),

          if (_viewModel.filteredListIsEmpty)
            _buildFilteredEmptyState()
          else ...[
            _buildSection(
              title: 'Upcoming appointments',
              icon: Icons.upcoming_outlined,
              appointments: _viewModel.visibleUpcomingAppointments,
              emptyMessage:
                  'There are no upcoming appointments matching the selected filters.',
              hasMore: _viewModel.hasMoreUpcoming,
              onLoadMore: _viewModel.loadMoreUpcoming,
            ),

            const SizedBox(height: 26),

            _buildSection(
              title: 'Past appointments',
              icon: Icons.history,
              appointments: _viewModel.visiblePastAppointments,
              emptyMessage:
                  'There are no past appointments matching the selected filters.',
              hasMore: _viewModel.hasMorePast,
              onLoadMore: _viewModel.loadMorePast,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final dateFormatter = DateFormat('dd.MM.yyyy.');

    return Card(
      color: _appointmentsSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_appointmentsRadius),
        side: const BorderSide(color: _appointmentsBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.filter_alt_outlined),
                SizedBox(width: 8),
                Text(
                  'Filters',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String?>(
              initialValue: _viewModel.selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All statuses'),
                ),
                ..._viewModel.statusOptions.map(
                  (status) => DropdownMenuItem<String?>(
                    value: status,
                    child: Text(status),
                  ),
                ),
              ],
              onChanged: _viewModel.setStatusFilter,
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _pickFilterDate,
              icon: const Icon(Icons.calendar_month),
              label: Text(
                _viewModel.selectedDate == null
                    ? 'Filter by date'
                    : dateFormatter.format(_viewModel.selectedDate!),
              ),
            ),

            if (_viewModel.hasActiveFilters) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _viewModel.clearFilters,
                icon: const Icon(Icons.clear),
                label: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.search_off, size: 54),
            const SizedBox(height: 12),
            const Text(
              'No appointments match the selected filters.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _viewModel.clearFilters,
              child: const Text('Clear filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<AppointmentModel> appointments,
    required String emptyMessage,
    required bool hasMore,
    required VoidCallback onLoadMore,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: _appointmentsPrimary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: _appointmentsText,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '${appointments.length}',
              style: const TextStyle(
                color: _appointmentsMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (appointments.isEmpty)
          Card(
            color: _appointmentsSurface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_appointmentsRadius),
              side: const BorderSide(color: _appointmentsBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(emptyMessage, textAlign: TextAlign.center),
            ),
          )
        else
          ...appointments.map(
            (appointment) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AppointmentCard(
                appointment: appointment,
                onTap: () => _openAppointment(appointment),
              ),
            ),
          ),

        if (hasMore)
          OutlinedButton.icon(
            onPressed: onLoadMore,
            icon: const Icon(Icons.expand_more),
            label: const Text('Load more'),
          ),
      ],
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;
  final VoidCallback onTap;

  const _AppointmentCard({required this.appointment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy. HH:mm');

    return Card(
      color: _appointmentsSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_appointmentsRadius),
        side: const BorderSide(color: _appointmentsBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    backgroundColor: _appointmentsLavender,
                    child: Icon(
                      Icons.person_outline,
                      color: _appointmentsPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.therapistName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _appointmentsText,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(appointment.startUtc.toLocal()),
                          style: const TextStyle(color: _appointmentsMuted),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(status: appointment.status),
                ],
              ),

              const Divider(height: 28),

              _CardRow(
                icon: appointment.isOnline
                    ? Icons.video_call_outlined
                    : Icons.location_on_outlined,
                value: appointment.type,
              ),

              const SizedBox(height: 8),

              _CardRow(
                icon: Icons.payments_outlined,
                value: '${appointment.price.toStringAsFixed(2)} BAM',
              ),

              const SizedBox(height: 8),

              _CardRow(
                icon: appointment.isOnline ? Icons.link : Icons.place_outlined,
                value: appointment.isOnline
                    ? appointment.meetingLink?.trim().isNotEmpty == true
                          ? 'Online link available'
                          : 'Online link not available yet'
                    : appointment.location?.trim().isNotEmpty == true
                    ? appointment.location!
                    : 'Location not specified',
              ),

              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('View details'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  final IconData icon;
  final String value;

  const _CardRow({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19),
        const SizedBox(width: 9),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 118),
      child: Chip(
        visualDensity: VisualDensity.compact,
        label: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.error_outline),
          title: const Text('Refresh failed'),
          subtitle: Text(message),
        ),
      ),
    );
  }
}
