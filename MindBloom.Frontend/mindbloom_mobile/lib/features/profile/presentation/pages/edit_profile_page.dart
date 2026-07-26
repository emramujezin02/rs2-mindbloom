import 'package:flutter/material.dart';
import '../../../../core/validation/app_validators.dart';
import '../../../../app/di/injection.dart';
import '../../data/models/profile_model.dart';
import '../viewmodels/profile_viewmodel.dart';

class EditProfilePage extends StatefulWidget {
  final ProfileModel profile;

  const EditProfilePage({super.key, required this.profile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final ProfileViewModel _viewModel = AppInjection.createProfileViewModel();

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;

  late final TextEditingController _lastNameController;

  late final TextEditingController _phoneController;

  late final TextEditingController _locationController;

  late final TextEditingController _minimumPriceController;

  late final TextEditingController _maximumPriceController;

  late final TextEditingController _languagesController;

  late DateTime _dateOfBirth;

  late String _preferredTherapistGender;

  late String _preferredSessionType;

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_refresh);

    _firstNameController = TextEditingController(
      text: widget.profile.firstName,
    );

    _lastNameController = TextEditingController(text: widget.profile.lastName);

    _phoneController = TextEditingController(text: widget.profile.phoneNumber);

    _locationController = TextEditingController(
      text: widget.profile.location ?? '',
    );

    _minimumPriceController = TextEditingController(
      text: widget.profile.minimumPricePerSession == null
          ? ''
          : widget.profile.minimumPricePerSession!.toStringAsFixed(2),
    );

    _maximumPriceController = TextEditingController(
      text: widget.profile.maximumPricePerSession == null
          ? ''
          : widget.profile.maximumPricePerSession!.toStringAsFixed(2),
    );

    _languagesController = TextEditingController(
      text: widget.profile.preferredLanguages.join(', '),
    );

    _dateOfBirth =
        widget.profile.dateOfBirth ?? DateTime(DateTime.now().year - 18);

    _preferredTherapistGender = _normalizeGender(
      widget.profile.preferredTherapistGender,
    );

    _preferredSessionType = _normalizeSessionType(
      widget.profile.preferredSessionType,
    );
  }

  @override
  void dispose() {
    _viewModel.removeListener(_refresh);

    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _minimumPriceController.dispose();
    _maximumPriceController.dispose();
    _languagesController.dispose();

    _viewModel.dispose();

    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  String _normalizeGender(String? value) {
    const allowedValues = {'Any', 'Female', 'Male'};

    return allowedValues.contains(value) ? value! : 'Any';
  }

  String _normalizeSessionType(String? value) {
    const allowedValues = {'Any', 'Online', 'InPerson'};

    return allowedValues.contains(value) ? value! : 'Any';
  }

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth,
      firstDate: DateTime(now.year - 120, now.month, now.day),
      lastDate: DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 1)),
      helpText: 'Select date of birth',
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _dateOfBirth = selectedDate;
    });
  }

  Future<void> _save() async {
    if (_viewModel.isLoading) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final dateError = AppValidators.dateOfBirth(_dateOfBirth);

    if (dateError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(dateError)));

      return;
    }

    final rangeError = AppValidators.priceRange(
      minimumValue: _minimumPriceController.text,
      maximumValue: _maximumPriceController.text,
    );

    if (rangeError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(rangeError)));

      return;
    }

    final minimumPrice = AppValidators.parseDecimal(
      _minimumPriceController.text,
    );

    final maximumPrice = AppValidators.parseDecimal(
      _maximumPriceController.text,
    );

    final languages = _languagesController.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    final success = await _viewModel.updateProfile(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      dateOfBirth: _dateOfBirth,
      location: _locationController.text.trim(),
      preferredTherapistGender: _preferredTherapistGender,
      preferredSessionType: _preferredSessionType,
      minimumPricePerSession: minimumPrice,
      maximumPricePerSession: maximumPrice,
      preferredLanguages: languages,
    );

    if (!success && mounted) {
      _formKey.currentState?.validate();
    }

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil je uspješno izmijenjen.')),
      );

      Navigator.of(context).pop(true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_viewModel.error ?? 'Profil nije moguće izmijeniti.'),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _firstNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'First name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  return _viewModel.fieldError('FirstName') ??
                      AppValidators.textLength(
                        value,
                        fieldName: 'Ime',
                        minimumLength: 2,
                        maximumLength: 50,
                      );
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _lastNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Last name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  return _viewModel.fieldError('LastName') ??
                      AppValidators.textLength(
                        value,
                        fieldName: 'Prezime',
                        minimumLength: 2,
                        maximumLength: 50,
                      );
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                initialValue: widget.profile.email,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  helperText: 'Email cannot be changed here.',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  return _viewModel.fieldError('PhoneNumber') ??
                      AppValidators.phone(value);
                },
              ),

              OutlinedButton.icon(
                onPressed: _selectDateOfBirth,
                icon: const Icon(Icons.cake),
                label: Text(
                  'Date of birth: '
                  '${_formatDate(_dateOfBirth)}',
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _locationController,
                maxLength: 200,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'City or location',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  return _viewModel.fieldError('Location') ??
                      AppValidators.location(value);
                },
              ),

              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                initialValue: _preferredTherapistGender,
                decoration: const InputDecoration(
                  labelText: 'Preferred therapist gender',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Any', child: Text('No preference')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _preferredTherapistGender = value;
                  });
                },
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _preferredSessionType,
                decoration: const InputDecoration(
                  labelText: 'Preferred session type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Any', child: Text('No preference')),
                  DropdownMenuItem(value: 'Online', child: Text('Online')),
                  DropdownMenuItem(value: 'InPerson', child: Text('In person')),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _preferredSessionType = value;
                  });
                },
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minimumPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Minimum price',
                        suffixText: 'BAM',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        return _viewModel.fieldError(
                              'MinimumPricePerSession',
                            ) ??
                            AppValidators.price(
                              value,
                              fieldName: 'Minimalna cijena',
                            );
                      },
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: TextFormField(
                      controller: _maximumPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Maximum price',
                        suffixText: 'BAM',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        return _viewModel.fieldError(
                              'MaximumPricePerSession',
                            ) ??
                            AppValidators.price(
                              value,
                              fieldName: 'Maksimalna cijena',
                            );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _languagesController,
                maxLines: 2,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Preferred languages',
                  hintText: 'Bosnian, English, German',
                  helperText: 'Separate languages with commas.',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final languages =
                      value
                          ?.split(',')
                          .map((language) => language.trim())
                          .where((language) => language.isNotEmpty)
                          .toList() ??
                      [];

                  if (languages.length > 10) {
                    return 'You may add at most 10 languages.';
                  }

                  if (languages.any((language) => language.length > 50)) {
                    return 'Each language may contain at most 50 characters.';
                  }

                  return null;
                },
              ),

              if (_viewModel.error != null) ...[
                const SizedBox(height: 4),
                Text(
                  _viewModel.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],

              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: _viewModel.isLoading ? null : _save,
                icon: _viewModel.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _viewModel.isLoading ? 'Saving...' : 'Save changes',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
