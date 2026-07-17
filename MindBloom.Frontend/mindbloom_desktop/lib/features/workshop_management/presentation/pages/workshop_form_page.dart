import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../viewmodels/workshop_form_viewmodel.dart';

class WorkshopFormPage extends StatefulWidget {
  final int? workshopId;

  const WorkshopFormPage({super.key, this.workshopId});

  @override
  State<WorkshopFormPage> createState() => _WorkshopFormPageState();
}

class _WorkshopFormPageState extends State<WorkshopFormPage> {
  late final WorkshopFormViewModel _viewModel;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();

  final TextEditingController _onlineLinkController = TextEditingController();

  final TextEditingController _locationController = TextEditingController();

  final TextEditingController _capacityController = TextEditingController();

  final TextEditingController _priceController = TextEditingController();

  late DateTime _startDateTime;

  late DateTime _endDateTime;

  int _type = 1;

  int? _therapistId;

  bool _initialValuesApplied = false;

  bool get _isEditing {
    return widget.workshopId != null;
  }

  @override
  void initState() {
    super.initState();

    _startDateTime = DateTime.now().add(const Duration(days: 1));

    _endDateTime = _startDateTime.add(const Duration(hours: 2));

    _capacityController.text = '20';

    _priceController.text = '0';

    _viewModel = AppInjection.createWorkshopFormViewModel();

    _viewModel.addListener(_onViewModelChanged);

    _viewModel.initialize(widget.workshopId);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);

    _titleController.dispose();

    _descriptionController.dispose();

    _onlineLinkController.dispose();

    _locationController.dispose();

    _capacityController.dispose();

    _priceController.dispose();

    super.dispose();
  }

  void _onViewModelChanged() {
    if (!_viewModel.isLoading &&
        !_initialValuesApplied &&
        _viewModel.workshop != null) {
      _applyWorkshopValues();
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _applyWorkshopValues() {
    final workshop = _viewModel.workshop;

    if (workshop == null) {
      return;
    }

    _titleController.text = workshop.title;

    _descriptionController.text = workshop.description;

    _onlineLinkController.text = workshop.onlineLink ?? '';

    _locationController.text = workshop.location ?? '';

    _capacityController.text = workshop.capacity.toString();

    _priceController.text = workshop.price.toStringAsFixed(2);

    _startDateTime = workshop.startUtc.toLocal();

    _endDateTime = workshop.endUtc.toLocal();

    _type = workshop.isOnline ? 1 : 2;

    _therapistId = workshop.therapistId;

    _initialValuesApplied = true;
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startDateTime),
    );

    if (time == null) {
      return;
    }

    setState(() {
      _startDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );

      if (_endDateTime.isBefore(_startDateTime) ||
          _endDateTime.isAtSameMomentAs(_startDateTime)) {
        _endDateTime = _startDateTime.add(const Duration(hours: 2));
      }
    });
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDateTime,
      firstDate: _startDateTime,
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endDateTime),
    );

    if (time == null) {
      return;
    }

    setState(() {
      _endDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_endDateTime.isAfter(_startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Workshop end time must be after its start time.'),
        ),
      );

      return;
    }

    final capacity = int.tryParse(_capacityController.text.trim());

    final price = double.tryParse(
      _priceController.text.trim().replaceAll(',', '.'),
    );

    if (capacity == null || price == null) {
      return;
    }

    final success = await _viewModel.save(
      workshopId: widget.workshopId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      startUtc: _startDateTime,
      endUtc: _endDateTime,
      type: _type,
      onlineLink: _type == 1 ? _onlineLinkController.text.trim() : null,
      location: _type == 2 ? _locationController.text.trim() : null,
      capacity: capacity,
      price: price,
      therapistId: _therapistId,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Workshop updated successfully.'
                : 'Workshop created successfully.',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit workshop' : 'Create workshop'),
      ),
      body: _viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _viewModel.error != null &&
                _viewModel.workshop == null &&
                _isEditing
          ? _buildInitialError()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Form(
                    key: _formKey,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _titleController,
                              maxLength: 150,
                              decoration: const InputDecoration(
                                labelText: 'Title',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                final title = value?.trim() ?? '';

                                if (title.length < 3) {
                                  return 'Title must contain at least 3 characters.';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _descriptionController,
                              minLines: 5,
                              maxLines: 10,
                              maxLength: 2000,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                border: OutlineInputBorder(),
                                alignLabelWithHint: true,
                              ),
                              validator: (value) {
                                final description = value?.trim() ?? '';

                                if (description.length < 10) {
                                  return 'Description must contain at least 10 characters.';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              initialValue: _type,
                              decoration: const InputDecoration(
                                labelText: 'Workshop type',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 1,
                                  child: Text('Online'),
                                ),
                                DropdownMenuItem(
                                  value: 2,
                                  child: Text('In person'),
                                ),
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
                                controller: _onlineLinkController,
                                decoration: const InputDecoration(
                                  labelText: 'Online link',
                                  hintText: 'https://...',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.link),
                                ),
                                validator: (value) {
                                  final link = value?.trim() ?? '';

                                  if (link.isEmpty) {
                                    return 'Online link is required.';
                                  }

                                  final uri = Uri.tryParse(link);

                                  if (uri == null ||
                                      !uri.hasScheme ||
                                      (uri.scheme != 'http' &&
                                          uri.scheme != 'https')) {
                                    return 'Enter a valid HTTP or HTTPS URL.';
                                  }

                                  return null;
                                },
                              ),
                            if (_type == 2)
                              TextFormField(
                                controller: _locationController,
                                maxLength: 300,
                                decoration: const InputDecoration(
                                  labelText: 'Location',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.location_on_outlined),
                                ),
                                validator: (value) {
                                  if ((value?.trim() ?? '').isEmpty) {
                                    return 'Location is required.';
                                  }

                                  return null;
                                },
                              ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _selectStartDate,
                                  icon: const Icon(Icons.event_available),
                                  label: Text(
                                    'Start: ${formatter.format(_startDateTime)}',
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _selectEndDate,
                                  icon: const Icon(Icons.event_busy),
                                  label: Text(
                                    'End: ${formatter.format(_endDateTime)}',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _capacityController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Capacity',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      final capacity = int.tryParse(
                                        value?.trim() ?? '',
                                      );

                                      if (capacity == null) {
                                        return 'Enter a valid capacity.';
                                      }

                                      if (capacity < 1 || capacity > 10000) {
                                        return 'Capacity must be between 1 and 10000.';
                                      }

                                      final currentRegistered =
                                          _viewModel
                                              .workshop
                                              ?.registeredCount ??
                                          0;

                                      if (capacity < currentRegistered) {
                                        return 'Capacity cannot be lower than $currentRegistered registered participants.';
                                      }

                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _priceController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'Price',
                                      suffixText: 'KM',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      final price = double.tryParse(
                                        (value ?? '').trim().replaceAll(
                                          ',',
                                          '.',
                                        ),
                                      );

                                      if (price == null) {
                                        return 'Enter a valid price.';
                                      }

                                      if (price < 0) {
                                        return 'Price cannot be negative.';
                                      }

                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int?>(
                              initialValue: _therapistId,
                              decoration: const InputDecoration(
                                labelText: 'Therapist',
                                helperText:
                                    'Optional. Leave empty when the workshop is organized directly by the administrator.',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('No assigned therapist'),
                                ),
                                ..._viewModel.therapists.map((therapist) {
                                  return DropdownMenuItem<int?>(
                                    value: therapist.id,
                                    child: Text(
                                      '${therapist.fullName} — ${therapist.specialization}',
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _therapistId = value;
                                });
                              },
                            ),
                            if (_viewModel.error != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                _viewModel.error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: _viewModel.isSaving
                                      ? null
                                      : () {
                                          Navigator.of(context).pop(false);
                                        },
                                  child: const Text('Cancel'),
                                ),
                                const SizedBox(width: 12),
                                FilledButton.icon(
                                  onPressed: _viewModel.isSaving ? null : _save,
                                  icon: _viewModel.isSaving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.save_outlined),
                                  label: Text(
                                    _viewModel.isSaving
                                        ? 'Saving...'
                                        : _isEditing
                                        ? 'Save changes'
                                        : 'Create workshop',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildInitialError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _viewModel.error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                _viewModel.initialize(widget.workshopId);
              },
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
