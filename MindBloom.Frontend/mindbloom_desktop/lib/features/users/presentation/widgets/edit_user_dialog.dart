import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/admin_user_details_model.dart';
import '../../data/models/update_admin_user_request.dart';

class EditUserDialog extends StatefulWidget {
  final AdminUserDetailsModel user;
  final bool isSaving;
  final Future<bool> Function(UpdateAdminUserRequest request) onSave;

  const EditUserDialog({
    super.key,
    required this.user,
    required this.isSaving,
    required this.onSave,
  });

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;

  DateTime? _dateOfBirth;
  String? _selectedGender;

  bool _isSubmitting = false;
  String? _errorMessage;

  static const List<String> _genders = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();

    _firstNameController = TextEditingController(text: widget.user.firstName);

    _lastNameController = TextEditingController(text: widget.user.lastName);

    _phoneController = TextEditingController(
      text: widget.user.phoneNumber ?? '',
    );

    _dateOfBirth = widget.user.dateOfBirth.toLocal();

    final currentGender = widget.user.gender.trim();

    _selectedGender = _genders.contains(currentGender) ? currentGender : null;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();

    super.dispose();
  }

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();

    final initialDate = _dateOfBirth ?? DateTime(now.year - 18);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now)
          ? DateTime(now.year - 18)
          : initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _dateOfBirth = picked;
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_dateOfBirth == null) {
      setState(() {
        _errorMessage = 'Date of birth is required.';
      });

      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final request = UpdateAdminUserRequest(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phoneNumber: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      dateOfBirth: DateTime(
        _dateOfBirth!.year,
        _dateOfBirth!.month,
        _dateOfBirth!.day,
      ),
      gender: _selectedGender,
    );

    final success = await widget.onSave(request);

    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSubmitting = false;
      _errorMessage = 'User could not be updated.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isSubmitting || widget.isSaving;

    return AlertDialog(
      title: const Text('Edit user'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _firstNameController,
                  enabled: !isBusy,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'First name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final normalized = value?.trim() ?? '';

                    if (normalized.isEmpty) {
                      return 'First name is required.';
                    }

                    if (normalized.length > 100) {
                      return 'First name may contain at most 100 characters.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _lastNameController,
                  enabled: !isBusy,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Last name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final normalized = value?.trim() ?? '';

                    if (normalized.isEmpty) {
                      return 'Last name is required.';
                    }

                    if (normalized.length > 100) {
                      return 'Last name may contain at most 100 characters.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  enabled: !isBusy,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final normalized = value?.trim() ?? '';

                    if (normalized.isEmpty) {
                      return null;
                    }

                    if (normalized.length > 30) {
                      return 'Phone number is too long.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    border: OutlineInputBorder(),
                  ),
                  items: _genders
                      .map(
                        (gender) => DropdownMenuItem<String>(
                          value: gender,
                          child: Text(gender),
                        ),
                      )
                      .toList(),
                  onChanged: isBusy
                      ? null
                      : (value) {
                          setState(() {
                            _selectedGender = value;
                          });
                        },
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: isBusy ? null : _selectDateOfBirth,
                  borderRadius: BorderRadius.circular(4),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date of birth',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      _dateOfBirth == null
                          ? 'Select date'
                          : DateFormat('dd.MM.yyyy.').format(_dateOfBirth!),
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isBusy
              ? null
              : () {
                  Navigator.of(context).pop(false);
                },
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: isBusy ? null : _save,
          icon: isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(isBusy ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}
