import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../therapist/data/models/therapist_model.dart';
import '../viewmodels/appointment_create_viewmodel.dart';

class AppointmentCreatePage extends StatefulWidget {
  final TherapistModel therapist;

  final DateTime? initialSlot;

  const AppointmentCreatePage({
    super.key,
    required this.therapist,
    this.initialSlot,
  });

  @override
  State<AppointmentCreatePage> createState() => _AppointmentCreatePageState();
}

class _AppointmentCreatePageState extends State<AppointmentCreatePage> {
  final AppointmentCreateViewModel _viewModel =
      AppInjection.createAppointmentViewModel();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _meetingLinkController = TextEditingController();

  final TextEditingController _locationController = TextEditingController();

  DateTime? _selectedDate;

  DateTime? _selectedSlot;

  int _type = 1;

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onChanged);

    _initialize();
  }

  Future<void> _initialize() async {
    await _viewModel.loadBookingData(widget.therapist.id);

    if (!mounted) {
      return;
    }

    final initialSlot = widget.initialSlot?.toLocal();

    if (initialSlot == null) {
      return;
    }

    final initialDate = DateTime(
      initialSlot.year,
      initialSlot.month,
      initialSlot.day,
    );

    if (!_viewModel.isDateSelectable(initialDate)) {
      return;
    }

    setState(() {
      _selectedDate = initialDate;
    });

    await _viewModel.loadAvailableSlots(
      therapistId: widget.therapist.id,
      date: initialDate,
    );

    if (!mounted) {
      return;
    }

DateTime? matchingSlot;

for (final slot
    in _viewModel.availableSlots) {
  if (slot.year == initialSlot.year &&
      slot.month == initialSlot.month &&
      slot.day == initialSlot.day &&
      slot.hour == initialSlot.hour &&
      slot.minute == initialSlot.minute) {
    matchingSlot = slot;
    break;
  }
}

    if (matchingSlot != null) {
      setState(() {
        _selectedSlot = matchingSlot;
      });
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _viewModel.dispose();

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
    if (_viewModel.availabilities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This therapist has not published availability.'),
        ),
      );

      return;
    }

    final now = DateTime.now();

    final firstDate = DateTime(now.year, now.month, now.day);

    final lastDate = firstDate.add(const Duration(days: 365));

    final initialDate = _findFirstSelectableDate(firstDate, lastDate);

    if (initialDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No available booking dates were found.')),
      );

      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: _viewModel.isDateSelectable,
      helpText: 'Choose an available date',
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDate = picked;
      _selectedSlot = null;
    });

    await _viewModel.loadAvailableSlots(
      therapistId: widget.therapist.id,
      date: picked,
    );
  }

  DateTime? _findFirstSelectableDate(DateTime firstDate, DateTime lastDate) {
    var currentDate = firstDate;

    while (!currentDate.isAfter(lastDate)) {
      if (_viewModel.isDateSelectable(currentDate)) {
        return currentDate;
      }

      currentDate = currentDate.add(const Duration(days: 1));
    }

    return null;
  }

  Future<void> _bookAppointment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose an appointment date.')),
      );

      return;
    }

    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose an available appointment time.'),
        ),
      );

      return;
    }

    final startUtc = _selectedSlot!.toUtc();

    final endUtc = _selectedSlot!
        .add(AppointmentCreateViewModel.appointmentDuration)
        .toUtc();

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
    } else if (_selectedDate != null) {
      await _viewModel.loadAvailableSlots(
        therapistId: widget.therapist.id,
        date: _selectedDate!,
      );

      _selectedSlot = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('dd.MM.yyyy.');

    return Scaffold(
      appBar: AppBar(title: const Text('Book appointment')),
      body: _viewModel.isLoading && _viewModel.availabilities.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                      onPressed: _viewModel.isLoading ? null : _pickDate,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        _selectedDate == null
                            ? 'Choose an available date'
                            : dateFormatter.format(_selectedDate!),
                      ),
                    ),

                    const SizedBox(height: 20),

                    if (_selectedDate != null) ...[
                      const Text(
                        'Available times',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      if (_viewModel.isLoadingSlots)
                        const Center(child: CircularProgressIndicator())
                      else if (_viewModel.availableSlots.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'There are no available times on this date.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _viewModel.availableSlots
                              .map(
                                (slot) => ChoiceChip(
                                  label: Text(DateFormat('HH:mm').format(slot)),
                                  selected: _selectedSlot == slot,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedSlot = selected ? slot : null;
                                    });
                                  },
                                ),
                              )
                              .toList(),
                        ),

                      const SizedBox(height: 20),
                    ],

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
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _type = value;
                        });
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
                          if (_type == 1 &&
                              (value == null || value.trim().isEmpty)) {
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
                          if (_type == 2 &&
                              (value == null || value.trim().isEmpty)) {
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
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),

                    ElevatedButton.icon(
                      onPressed:
                          _viewModel.isLoading || _viewModel.isLoadingSlots
                          ? null
                          : _bookAppointment,
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
