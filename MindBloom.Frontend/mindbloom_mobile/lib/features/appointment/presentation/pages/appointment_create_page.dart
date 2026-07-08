import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../therapist/data/models/therapist_model.dart';
import '../viewmodels/appointment_create_viewmodel.dart';

class AppointmentCreatePage extends StatefulWidget {
  final TherapistModel therapist;

  const AppointmentCreatePage({super.key, required this.therapist});

  @override
  State<AppointmentCreatePage> createState() => _AppointmentCreatePageState();
}

class _AppointmentCreatePageState extends State<AppointmentCreatePage> {
  final AppointmentCreateViewModel _viewModel =
      AppInjection.createAppointmentViewModel();

  final _formKey = GlobalKey<FormState>();

  final _meetingLinkController = TextEditingController();

  final _locationController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  int _type = 1;

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onChanged);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _meetingLinkController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _bookAppointment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      setState(() {
        _viewModel.error = 'Please choose appointment date.';
      });
      return;
    }

    if (_selectedTime == null) {
      setState(() {
        _viewModel.error = 'Please choose appointment time.';
      });
      return;
    }

    final startUtc = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    ).toUtc();

    final endUtc = startUtc.add(const Duration(hours: 1));

    final success = await _viewModel.createAppointment(
      therapistId: widget.therapist.id,
      startUtc: startUtc,
      endUtc: endUtc,
      type: _type,
      meetingLink: _type == 1 ? _meetingLinkController.text.trim() : null,
      location: _type == 2 ? _locationController.text.trim() : null,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment request sent successfully.')),
      );

      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRouter.myAppointments, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _selectedDate == null
        ? 'Choose date'
        : '${_selectedDate!.day}.${_selectedDate!.month}.${_selectedDate!.year}.';

    final timeText = _selectedTime == null
        ? 'Choose time'
        : _selectedTime!.format(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Book appointment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.therapist.fullName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                widget.therapist.specialization,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month),
                label: Text(dateText),
              ),

              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.access_time),
                label: Text(timeText),
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<int>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Appointment type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Online')),
                  DropdownMenuItem(value: 2, child: Text('In person')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _type = value;
                    });
                  }
                },
              ),

              const SizedBox(height: 12),

              if (_type == 1)
                TextFormField(
                  controller: _meetingLinkController,
                  decoration: const InputDecoration(
                    labelText: 'Meeting link',
                    hintText: 'https://meet.google.com/...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (_type == 1 && (value == null || value.trim().isEmpty)) {
                      return 'Meeting link is required for online appointments.';
                    }

                    return null;
                  },
                ),

              if (_type == 2)
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    hintText: 'Sarajevo office',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (_type == 2 && (value == null || value.trim().isEmpty)) {
                      return 'Location is required for in-person appointments.';
                    }

                    return null;
                  },
                ),

              const SizedBox(height: 16),

              if (_viewModel.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _viewModel.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              ElevatedButton.icon(
                onPressed: _viewModel.isLoading ? null : _bookAppointment,
                icon: const Icon(Icons.check),
                label: _viewModel.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Book appointment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
