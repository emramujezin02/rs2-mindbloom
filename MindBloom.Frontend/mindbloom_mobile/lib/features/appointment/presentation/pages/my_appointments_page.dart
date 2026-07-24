import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../data/models/appointment_model.dart';
import '../viewmodels/my_appointments_viewmodel.dart';

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
      appBar: AppBar(
        title: const Text('My appointments'),
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
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.error != null && _viewModel.appointments.isEmpty) {
      return _ErrorState(message: _viewModel.error!, onRetry: _refresh);
    }

    if (_viewModel.appointments.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 100),
            Icon(Icons.event_busy_outlined, size: 72),
            SizedBox(height: 18),
            Text(
              'You do not have appointments yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
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
            Icon(icon),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text('${appointments.length}'),
          ],
        ),

        const SizedBox(height: 12),

        if (appointments.isEmpty)
          Card(
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
                  const CircleAvatar(child: Icon(Icons.person_outline)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.therapistName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(dateFormat.format(appointment.startUtc.toLocal())),
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
    return Chip(visualDensity: VisualDensity.compact, label: Text(status));
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
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
