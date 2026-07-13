import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/workshop_model.dart';
import '../../../../app/di/injection.dart';
import '../viewmodels/workshop_viewmodel.dart';

class WorkshopDetailsPage extends StatefulWidget {
  final int workshopId;

  const WorkshopDetailsPage({super.key, required this.workshopId});

  @override
  State<WorkshopDetailsPage> createState() => _WorkshopDetailsPageState();
}

class _WorkshopDetailsPageState extends State<WorkshopDetailsPage> {
  final WorkshopViewModel _viewModel = AppInjection.createWorkshopViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);

    _viewModel.loadWorkshopDetails(widget.workshopId);
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

  Future<void> _reload() async {
    await _viewModel.loadWorkshopDetails(widget.workshopId);
  }

  Future<void> _register() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Register for workshop'),
          content: const Text(
            'Are you sure you want to register for this workshop?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Register'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final success = await _viewModel.register(widget.workshopId);

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have successfully registered for the workshop.'),
        ),
      );
    }
  }

  Future<void> _cancelRegistration() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel registration'),
          content: const Text(
            'Are you sure you want to cancel your workshop registration?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Keep registration'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Cancel registration'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final success = await _viewModel.cancelRegistration(widget.workshopId);

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workshop registration cancelled.')),
      );
    }
  }

  Future<void> _joinWorkshop(String link) async {
    final uri = Uri.tryParse(link);

    if (uri == null) {
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!mounted) {
      return;
    }

    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The workshop link could not be opened.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final workshop = _viewModel.selectedWorkshop;

    return Scaffold(
      appBar: AppBar(title: const Text('Workshop details')),
      body: _viewModel.isLoadingDetails && workshop == null
          ? const Center(child: CircularProgressIndicator())
          : workshop == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _viewModel.error ?? 'Workshop could not be loaded.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _reload,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : _buildWorkshop(workshop),
    );
  }

  Widget _buildWorkshop(WorkshopModel workshop) {
    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    final canRegister =
        workshop.isScheduled &&
        !workshop.isRegistered &&
        !workshop.isFull &&
        workshop.startUtc.isAfter(DateTime.now());

    final canCancel =
        workshop.isRegistered && workshop.startUtc.isAfter(DateTime.now());

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            workshop.title,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            workshop.description,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _InfoRow(label: 'Organizer', value: workshop.organizerName),
                  const Divider(),
                  _InfoRow(
                    label: 'Starts',
                    value: formatter.format(workshop.startUtc.toLocal()),
                  ),
                  const Divider(),
                  _InfoRow(
                    label: 'Ends',
                    value: formatter.format(workshop.endUtc.toLocal()),
                  ),
                  const Divider(),
                  _InfoRow(label: 'Type', value: workshop.type),
                  const Divider(),
                  _InfoRow(label: 'Status', value: workshop.status),
                  const Divider(),
                  _InfoRow(
                    label: 'Price',
                    value: '${workshop.price.toStringAsFixed(2)} KM',
                  ),
                  const Divider(),
                  _InfoRow(
                    label: 'Available seats',
                    value: workshop.availableSeats.toString(),
                  ),
                ],
              ),
            ),
          ),
          if (!workshop.isOnline &&
              workshop.location != null &&
              workshop.location!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text('Location'),
                subtitle: Text(workshop.location!),
              ),
            ),
          ],
          if (workshop.isRegistered) ...[
            const SizedBox(height: 16),
            const Card(
              child: ListTile(
                leading: Icon(Icons.check_circle),
                title: Text('You are registered'),
              ),
            ),
          ],
          if (workshop.hasJoinLink) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                _joinWorkshop(workshop.onlineLink!);
              },
              icon: const Icon(Icons.video_call),
              label: const Text('Join online workshop'),
            ),
          ] else if (workshop.isOnline && workshop.isRegistered) ...[
            const SizedBox(height: 16),
            const Card(
              child: ListTile(
                leading: Icon(Icons.schedule),
                title: Text('Workshop link is not available yet'),
                subtitle: Text(
                  'The link becomes available shortly before the workshop starts.',
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (!workshop.isRegistered)
            ElevatedButton.icon(
              onPressed: canRegister && !_viewModel.isSaving ? _register : null,
              icon: const Icon(Icons.app_registration),
              label: Text(
                workshop.isFull
                    ? 'Workshop is full'
                    : canRegister
                    ? 'Register'
                    : 'Registration unavailable',
              ),
            ),
          if (workshop.isRegistered)
            OutlinedButton.icon(
              onPressed: canCancel && !_viewModel.isSaving
                  ? _cancelRegistration
                  : null,
              icon: const Icon(Icons.cancel_outlined),
              label: Text(
                canCancel
                    ? 'Cancel registration'
                    : 'Registration cannot be cancelled',
              ),
            ),
          if (_viewModel.error != null) ...[
            const SizedBox(height: 12),
            Text(
              _viewModel.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(child: Text(value, textAlign: TextAlign.right)),
      ],
    );
  }
}
