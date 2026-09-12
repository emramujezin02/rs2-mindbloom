import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/validation/app_validators.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../data/models/admin_user_details_model.dart';
import '../../data/models/update_admin_user_request.dart';
import '../../../../core/widgets/app_responsive_dialog_content.dart';

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

  bool get _isBusy => _isSubmitting || widget.isSaving;

  @override
  void initState() {
    super.initState();

    _firstNameController = TextEditingController(text: widget.user.firstName);

    _lastNameController = TextEditingController(text: widget.user.lastName);

    _phoneController = TextEditingController(
      text: widget.user.phoneNumber ?? '',
    );

    _firstNameController.addListener(_clearError);

    _lastNameController.addListener(_clearError);

    _phoneController.addListener(_clearError);

    _dateOfBirth = widget.user.dateOfBirth.toLocal();

    final currentGender = widget.user.gender.trim();

    _selectedGender = _genders.contains(currentGender) ? currentGender : null;
  }

  void _clearError() {
    if (_errorMessage == null || !mounted) {
      return;
    }

    setState(() {
      _errorMessage = null;
    });
  }

  @override
  void dispose() {
    _firstNameController.removeListener(_clearError);

    _lastNameController.removeListener(_clearError);

    _phoneController.removeListener(_clearError);

    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();

    super.dispose();
  }

  Future<void> _selectDateOfBirth() async {
    if (_isBusy) {
      return;
    }

    final now = DateTime.now();

    final initialDate = _dateOfBirth ?? DateTime(now.year - 18);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now)
          ? DateTime(now.year - 18)
          : initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Odaberite datum rođenja',
      cancelText: 'Odustani',
      confirmText: 'Odaberi',
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _dateOfBirth = picked;
      _errorMessage = null;
    });
  }

  String _genderLabel(String value) {
    switch (value) {
      case 'Male':
        return 'Muško';
      case 'Female':
        return 'Žensko';
      case 'Other':
        return 'Drugo';
      default:
        return value;
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (_isBusy) {
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_dateOfBirth == null) {
      setState(() {
        _errorMessage = 'Datum rođenja je obavezan.';
      });

      return;
    }

    if (_dateOfBirth!.isAfter(DateTime.now())) {
      setState(() {
        _errorMessage = 'Datum rođenja ne može biti u budućnosti.';
      });

      return;
    }

    setState(() {
      _isSubmitting = true;
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

      _errorMessage =
          'Podatke korisnika nije moguće spremiti. Provjerite unesene podatke i pokušajte ponovo.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Uredi korisnika'),
      content: AppResponsiveDialogContent(
        preferredWidth: 620,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.user.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _firstNameController,
                enabled: !_isBusy,
                textInputAction: TextInputAction.next,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Ime',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => AppValidators.textLength(
                  value,
                  fieldName: 'Ime',
                  maxLength: 100,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _lastNameController,
                enabled: !_isBusy,
                textInputAction: TextInputAction.next,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Prezime',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => AppValidators.textLength(
                  value,
                  fieldName: 'Prezime',
                  maxLength: 100,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                enabled: !_isBusy,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: 'Broj telefona',
                  hintText: 'npr. +387 61 123 456',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    AppValidators.phone(value, required: false),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Spol',
                  border: OutlineInputBorder(),
                ),
                items: _genders.map((gender) {
                  return DropdownMenuItem<String>(
                    value: gender,
                    child: Text(_genderLabel(gender)),
                  );
                }).toList(),
                onChanged: _isBusy
                    ? null
                    : (value) {
                        setState(() {
                          _selectedGender = value;

                          _errorMessage = null;
                        });
                      },
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _isBusy ? null : _selectDateOfBirth,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Datum rođenja',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    _dateOfBirth == null
                        ? 'Odaberite datum'
                        : DateFormat('dd.MM.yyyy.').format(_dateOfBirth!),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                AppErrorBanner(message: _errorMessage!, onDismiss: _clearError),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isBusy
              ? null
              : () {
                  Navigator.of(context).pop(false);
                },
          child: const Text('Odustani'),
        ),
        FilledButton.icon(
          onPressed: _isBusy ? null : _save,
          icon: _isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_isBusy ? 'Spremanje...' : 'Spremi'),
        ),
      ],
    );
  }
}
