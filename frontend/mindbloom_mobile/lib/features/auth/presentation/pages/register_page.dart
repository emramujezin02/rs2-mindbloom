import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/validation/app_validators.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../../data/models/register_therapist_request.dart';
import '../../../therapist/data/models/therapist_location_model.dart';
import '../../../therapist/data/services/therapist_api_service.dart';
import '../../../therapist/presentation/widgets/therapist_location_dropdown.dart';

class RegisterPage extends StatefulWidget {
  final AuthViewModel? viewModel;
  final String initialRole;

  const RegisterPage({super.key, this.viewModel, this.initialRole = 'Client'});

  static String normalizeRole(Object? value) =>
      value is String && value.toLowerCase() == 'therapist'
      ? 'Therapist'
      : 'Client';

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  late final AuthViewModel _viewModel =
      widget.viewModel ?? AppInjection.createAuthViewModel();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _firstNameController = TextEditingController();

  final TextEditingController _lastNameController = TextEditingController();

  final TextEditingController _usernameController = TextEditingController();

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();
  final _biography = TextEditingController();
  final _hourlyRate = TextEditingController();
  final _experience = TextEditingController();
  final _country = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  late String _role;
  String _gender = 'Other';
  String? _specialization;
  bool _offersOnline = true;
  bool _offersInPerson = false;
  TherapistLocationModel? _registrationLocation;
  bool _worksWithChildren = false;
  bool get _isTherapist => _role == 'Therapist';

  DateTime? _dateOfBirth;
  bool _obscurePassword = true;
  String? _localError;
  bool _acceptedPrivacyPolicy = false;
  bool _acceptedTermsOfService = false;

  @override
  void initState() {
    super.initState();
    _role = RegisterPage.normalizeRole(widget.initialRole);

    _viewModel.addListener(_onChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _viewModel.loadCurrentConsentVersions();
      if (_isTherapist) _viewModel.loadRegistrationSpecializations();
    });
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _viewModel.dispose();

    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    for (final controller in [
      _biography,
      _hourlyRate,
      _experience,
      _country,
      _city,
      _address,
    ]) {
      controller.dispose();
    }

    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickDate() async {
    if (_viewModel.isLoading) {
      return;
    }

    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18),
      firstDate: _isTherapist
          ? DateTime(1)
          : DateTime(now.year - 120, now.month, now.day),
      lastDate: _isTherapist
          ? DateTime(
              now.year,
              now.month,
              now.day,
            ).subtract(const Duration(days: 1))
          : now,
    );

    if (picked != null && mounted) {
      setState(() {
        _dateOfBirth = picked;
        _localError = null;
      });
    }
  }

  Future<void> _register() async {
    if (_viewModel.isLoading || !_formKey.currentState!.validate()) {
      return;
    }

    if (_dateOfBirth == null) {
      setState(() {
        _localError = 'Date of birth is required.';
      });
      return;
    }

    if (!_acceptedPrivacyPolicy || !_acceptedTermsOfService) {
      setState(() {
        _localError =
            'You must accept the Privacy Policy and Terms of Service.';
      });

      return;
    }

    if (!_viewModel.hasRegistrationConsentVersions) {
      setState(() {
        _localError =
            'Privacy documents are not available. Please refresh and try again.';
      });

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _localError = null;
    });

    final email = _emailController.text.trim();

    final success = await _viewModel.register(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      username: _usernameController.text.trim(),
      email: email,
      password: _passwordController.text,
      gender: _gender,
      therapistDetails: _isTherapist
          ? TherapistRegistrationDetails(
              locationId: _registrationLocation?.id,
              worksWithChildren: _worksWithChildren,
              specialization: _specialization!,
              biography: _biography.text.trim(),
              country: _country.text.trim(),
              city: _city.text.trim(),
              address: _address.text.trim(),
              hourlyRate: double.parse(
                _hourlyRate.text.trim().replaceAll(',', '.'),
              ),
              experienceYears: int.parse(_experience.text.trim()),
              offersOnline: _offersOnline,
              offersInPerson: _offersInPerson,
            )
          : null,
      dateOfBirth: _dateOfBirth!,
      acceptPrivacyPolicy: _acceptedPrivacyPolicy,
      acceptTermsOfService: _acceptedTermsOfService,
    );

    if (!mounted || !success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isTherapist
              ? 'Registracija psihoterapeuta je zaprimljena. Potvrdite email, prijavite se i pošaljite dokumentaciju iz profila. Profil čeka verifikaciju.'
              : 'Registration successful. Enter the code sent to your email.',
        ),
      ),
    );

    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.verifyEmail,
      (route) => false,
      arguments: email,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _dateOfBirth == null
        ? 'Choose date of birth'
        : '${_dateOfBirth!.day}.'
              '${_dateOfBirth!.month}.'
              '${_dateOfBirth!.year}.';

    final error = _localError ?? _viewModel.errorMessage;

    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    key: const ValueKey('registration-role'),
                    initialValue: _role,
                    decoration: const InputDecoration(
                      labelText: 'Tip naloga',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Client', child: Text('Klijent')),
                      DropdownMenuItem(
                        value: 'Therapist',
                        child: Text('Psihoterapeut'),
                      ),
                    ],
                    onChanged: _viewModel.isLoading
                        ? null
                        : (value) {
                            setState(() {
                              _role = value!;
                              _localError = null;
                            });
                            if (_isTherapist &&
                                _viewModel
                                    .registrationSpecializations
                                    .isEmpty) {
                              _viewModel.loadRegistrationSpecializations();
                            }
                          },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Create MindBloom account',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _firstNameController,
                    enabled: !_viewModel.isLoading,
                    decoration: const InputDecoration(
                      labelText: 'First name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'First name is required.';
                      }
                      return _validateName(value);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _lastNameController,
                    enabled: !_viewModel.isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Last name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Last name is required.';
                      }
                      return _validateName(value);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _usernameController,
                    enabled: !_viewModel.isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Username is required.';
                      }
                      final username = value.trim();
                      if (username.length < 3 ||
                          username.length > (_isTherapist ? 100 : 50)) {
                        return 'Korisničko ime mora imati 3–${_isTherapist ? 100 : 50} znakova.';
                      }
                      if (!RegExp(
                        _isTherapist
                            ? r'^[a-zA-Z0-9._@+\-]+$'
                            : r'^[a-zA-Z0-9._\-]+$',
                      ).hasMatch(username)) {
                        return 'Korisničko ime sadrži nedozvoljene znakove.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailController,
                    enabled: !_viewModel.isLoading,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';

                      if (email.isEmpty) {
                        return 'Email is required.';
                      }

                      if (!email.contains('@')) {
                        return 'Enter a valid email address.';
                      }
                      if (email.length > (_isTherapist ? 256 : 254)) {
                        return 'Email adresa je preduga.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    enabled: !_viewModel.isLoading,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      errorMaxLines: 4,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: _viewModel.isLoading
                            ? null
                            : () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: AppValidators.password,
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _viewModel.isLoading ? null : _pickDate,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(dateText),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: const InputDecoration(
                      labelText: 'Spol',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Male', child: Text('Muški')),
                      DropdownMenuItem(value: 'Female', child: Text('Ženski')),
                      DropdownMenuItem(value: 'Other', child: Text('Drugo')),
                    ],
                    onChanged: _viewModel.isLoading
                        ? null
                        : (value) => setState(() => _gender = value!),
                  ),
                  if (_isTherapist) ..._therapistFields(),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    AppInlineError(
                      title: 'Registration could not be completed',
                      error: error,
                      onRetry: _register,
                    ),
                  ],
                  const SizedBox(height: 20),

                  if (_viewModel.isLoadingConsentVersions)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_viewModel.consentVersionsError != null) ...[
                    AppInlineError(
                      title: 'Privacy documents could not be loaded',
                      error: _viewModel.consentVersionsError,
                      onRetry: _viewModel.loadCurrentConsentVersions,
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    CheckboxListTile(
                      value: _acceptedPrivacyPolicy,
                      onChanged: _viewModel.isLoading
                          ? null
                          : (value) {
                              setState(() {
                                _acceptedPrivacyPolicy = value ?? false;

                                _localError = null;
                              });
                            },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('I accept the Privacy Policy'),
                      subtitle: Text(
                        'Version ${_viewModel.currentConsentVersions?.privacyPolicyVersion ?? ''}',
                      ),
                    ),

                    CheckboxListTile(
                      value: _acceptedTermsOfService,
                      onChanged: _viewModel.isLoading
                          ? null
                          : (value) {
                              setState(() {
                                _acceptedTermsOfService = value ?? false;

                                _localError = null;
                              });
                            },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('I accept the Terms of Service'),
                      subtitle: Text(
                        'Version ${_viewModel.currentConsentVersions?.termsOfServiceVersion ?? ''}',
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed:
                        _viewModel.isLoading ||
                            _viewModel.isLoadingConsentVersions ||
                            !_viewModel.hasRegistrationConsentVersions
                        ? null
                        : _register,
                    child: _viewModel.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Register'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _viewModel.isLoading
                        ? null
                        : () {
                            Navigator.of(
                              context,
                            ).pushReplacementNamed(AppRouter.login);
                          },
                    child: const Text('Already have an account? Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _validateName(String value) {
    if (value.trim().length > 100) return 'Ime može imati najviše 100 znakova.';
    if (!_isTherapist &&
        !RegExp(
          r"^[\p{L}\p{M}][\p{L}\p{M}' -]*$",
          unicode: true,
        ).hasMatch(value.trim())) {
      return 'Ime sadrži nedozvoljene znakove.';
    }
    return null;
  }

  Widget _professionalText(
    String label,
    TextEditingController controller,
    int limit, {
    int lines = 1,
    String? Function(String?)? validator,
    bool numeric = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: TextFormField(
      controller: controller,
      enabled: !_viewModel.isLoading,
      maxLines: lines,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        errorMaxLines: 3,
      ),
      validator:
          validator ??
          (value) => AppValidators.textLength(
            value,
            fieldName: label,
            maximumLength: limit,
          ),
    ),
  );

  List<Widget> _therapistFields() => [
    const SizedBox(height: 14),
    if (_viewModel.isLoadingSpecializations) const LinearProgressIndicator(),
    if (_viewModel.specializationsError != null) ...[
      Text(_viewModel.specializationsError!),
      TextButton(
        onPressed: _viewModel.isLoading
            ? null
            : _viewModel.loadRegistrationSpecializations,
        child: const Text('Ponovo učitaj specijalizacije'),
      ),
    ],
    DropdownButtonFormField<String>(
      initialValue: _specialization,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Specijalizacija',
        border: OutlineInputBorder(),
      ),
      items: _viewModel.registrationSpecializations
          .toSet()
          .map((name) => DropdownMenuItem(value: name, child: Text(name)))
          .toList(),
      onChanged: _viewModel.isLoading
          ? null
          : (value) => setState(() => _specialization = value),
      validator: (value) => value == null ? 'Odaberite specijalizaciju.' : null,
    ),
    _professionalText('Biografija', _biography, 3000, lines: 4),
    _professionalText(
      'Cijena termina (KM)',
      _hourlyRate,
      30,
      numeric: true,
      validator: (value) {
        final price = double.tryParse(value?.trim().replaceAll(',', '.') ?? '');
        return price == null || !price.isFinite || price <= 0
            ? 'Unesite cijenu veću od nule.'
            : null;
      },
    ),
    _professionalText(
      'Godine iskustva',
      _experience,
      2,
      numeric: true,
      validator: (value) {
        final years = int.tryParse(value?.trim() ?? '');
        return years == null || years < 0 || years > 70
            ? 'Unesite cijeli broj od 0 do 70.'
            : null;
      },
    ),
    const SizedBox(height: 14),
    TherapistLocationDropdown(
      value: _registrationLocation?.id,
      requiredSelection: true,
      enabled: !_viewModel.isLoading,
      service: TherapistApiService(
        apiClient: _viewModel.authRepository.authApiService.apiClient,
      ),
      onChanged: (location) => setState(() {
        _registrationLocation = location;
        _country.text = location?.country ?? '';
        _city.text = location?.name ?? '';
      }),
    ),
    CheckboxListTile(
      title: const Text('Radim s djecom'),
      value: _worksWithChildren,
      onChanged: _viewModel.isLoading
          ? null
          : (value) => setState(() => _worksWithChildren = value ?? false),
    ),
    _professionalText('Adresa', _address, 300),
    CheckboxListTile(
      value: _offersOnline,
      title: const Text('Online termini'),
      onChanged: _viewModel.isLoading
          ? null
          : (value) => setState(() => _offersOnline = value!),
    ),
    FormField<bool>(
      validator: (_) => !_offersOnline && !_offersInPerson
          ? 'Odaberite barem jedan način rada.'
          : null,
      builder: (field) => Column(
        children: [
          CheckboxListTile(
            value: _offersInPerson,
            title: const Text('Termini uživo'),
            onChanged: _viewModel.isLoading
                ? null
                : (value) => setState(() => _offersInPerson = value!),
          ),
          if (field.hasError)
            Text(
              field.errorText!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
  ];
}
