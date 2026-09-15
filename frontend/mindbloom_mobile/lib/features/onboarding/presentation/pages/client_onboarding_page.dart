import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../therapy_approach/data/models/therapy_approach_model.dart';
import '../../data/models/save_client_onboarding_request.dart';
import '../viewmodels/client_onboarding_viewmodel.dart';
import '../../../../core/validation/app_validators.dart';

class ClientOnboardingPage extends StatefulWidget {
  final bool isRequired;
  final VoidCallback? onCompleted;

  const ClientOnboardingPage({
    super.key,
    this.isRequired = false,
    this.onCompleted,
  });

  @override
  State<ClientOnboardingPage> createState() => _ClientOnboardingPageState();
}

class _ClientOnboardingPageState extends State<ClientOnboardingPage> {
  static const List<String> _availableFocusAreas = [
    'Anxiety',
    'Stress',
    'Depression',
    'Relationships',
    'Self-esteem',
    'Grief and loss',
    'Trauma',
    'Sleep difficulties',
    'Work or study difficulties',
    'Personal growth',
  ];

  static const List<String> _availableLanguages = [
    'Bosnian',
    'Croatian',
    'Serbian',
    'English',
    'German',
  ];

  static const List<String> _dayNames = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  final ClientOnboardingViewModel _viewModel =
      AppInjection.createClientOnboardingViewModel();

  final TextEditingController _locationController = TextEditingController();

  final TextEditingController _minimumPriceController = TextEditingController();

  final TextEditingController _maximumPriceController = TextEditingController();

  int _currentStep = 0;
  bool _initializedValues = false;
  bool _acceptedSensitiveDataProcessing = false;

  final Set<String> _focusAreas = {};
  final Set<String> _languages = {};
  final Set<int> _therapyApproachIds = {};
  final Set<int> _preferredDays = {};

  String _gender = 'Any';
  String _sessionType = 'Any';

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);

    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);

    _locationController.dispose();
    _minimumPriceController.dispose();
    _maximumPriceController.dispose();

    _viewModel.dispose();

    super.dispose();
  }

  void _onViewModelChanged() {
    if (!_initializedValues && _viewModel.onboarding != null) {
      _applyExistingValues();
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _applyExistingValues() {
    final onboarding = _viewModel.onboarding;

    if (onboarding == null) {
      return;
    }

    _initializedValues = true;

    _focusAreas
      ..clear()
      ..addAll(onboarding.assessmentFocusAreas);

    _languages
      ..clear()
      ..addAll(onboarding.preferredLanguages);

    _therapyApproachIds
      ..clear()
      ..addAll(onboarding.preferredTherapyApproachIds);

    _preferredDays
      ..clear()
      ..addAll(onboarding.preferredDays);

    _gender = onboarding.preferredTherapistGender ?? 'Any';

    _sessionType = onboarding.preferredSessionType ?? 'Any';

    _locationController.text = onboarding.location ?? '';

    _minimumPriceController.text = onboarding.minimumPricePerSession == null
        ? ''
        : onboarding.minimumPricePerSession!.toStringAsFixed(2);

    _maximumPriceController.text = onboarding.maximumPricePerSession == null
        ? ''
        : onboarding.maximumPricePerSession!.toStringAsFixed(2);
  }

  bool _validateCurrentStep() {
    String? message;

    switch (_currentStep) {
      case 1:
        if (_focusAreas.isEmpty) {
          message = 'Odaberite najmanje jedno područje podrške.';
        }
        break;

      case 2:
        if (_sessionType.trim().isEmpty) {
          message = 'Odaberite željeni tip terapijske sesije.';
        }
        break;

      case 3:
        if (_languages.isEmpty) {
          message = 'Odaberite najmanje jedan željeni jezik.';
        }
        break;

      case 5:
        if (_therapyApproachIds.isEmpty) {
          message = 'Odaberite najmanje jedan terapijski pristup.';
        }
        break;

      case 6:
        final hasAssessmentData = _focusAreas.isNotEmpty;

        final alreadyAccepted =
            _viewModel.hasAcceptedCurrentSensitiveDataConsent;

        if (hasAssessmentData &&
            !alreadyAccepted &&
            !_acceptedSensitiveDataProcessing) {
          message =
              'Morate dati saglasnost za obradu assessment podataka prije spremanja.';
        }

        break;
    }

    if (message == null) {
      return true;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));

    return false;
  }

  void _continue() {
    if (_viewModel.isSaving) {
      return;
    }

    if (!_validateCurrentStep()) {
      return;
    }

    if (_currentStep < 6) {
      setState(() {
        _currentStep++;
      });

      return;
    }

    _save();
  }

  Future<void> _save() async {
    if (_viewModel.isSaving) {
      return;
    }

    final minimumPriceError =
        _viewModel.fieldError('MinimumPricePerSession') ??
        AppValidators.price(
          _minimumPriceController.text,
          fieldName: 'Minimalna cijena',
        );

    if (minimumPriceError != null) {
      _showValidationMessage(minimumPriceError);

      setState(() {
        _currentStep = 4;
      });

      return;
    }

    final maximumPriceError =
        _viewModel.fieldError('MaximumPricePerSession') ??
        AppValidators.price(
          _maximumPriceController.text,
          fieldName: 'Maksimalna cijena',
        );

    if (maximumPriceError != null) {
      _showValidationMessage(maximumPriceError);

      setState(() {
        _currentStep = 4;
      });

      return;
    }

    final locationError =
        _viewModel.fieldError('Location') ??
        AppValidators.location(_locationController.text);

    if (locationError != null) {
      _showValidationMessage(locationError);

      setState(() {
        _currentStep = 4;
      });

      return;
    }

    final rangeError = AppValidators.priceRange(
      minimumValue: _minimumPriceController.text,
      maximumValue: _maximumPriceController.text,
    );

    if (rangeError != null) {
      _showValidationMessage(rangeError);

      setState(() {
        _currentStep = 4;
      });

      return;
    }

    final minimumPrice = AppValidators.parseDecimal(
      _minimumPriceController.text,
    );

    final maximumPrice = AppValidators.parseDecimal(
      _maximumPriceController.text,
    );

    final alreadyAcceptedCurrentConsent =
        _viewModel.hasAcceptedCurrentSensitiveDataConsent;

    final currentConsentVersion = _viewModel
        .currentSensitiveDataProcessingVersion
        .trim();

    if (_focusAreas.isNotEmpty &&
        !alreadyAcceptedCurrentConsent &&
        currentConsentVersion.isEmpty) {
      _showValidationMessage(
        'Verzija saglasnosti za obradu podataka nije dostupna. Pokušajte ponovo.',
      );

      return;
    }

    final success = await _viewModel.save(
      SaveClientOnboardingRequest(
        assessmentFocusAreas: _focusAreas.toList(),

        preferredTherapistGender: _gender,

        preferredSessionType: _sessionType,

        preferredLanguages: _languages.toList(),

        minimumPricePerSession: minimumPrice,

        maximumPricePerSession: maximumPrice,

        location: _locationController.text.trim(),

        preferredDays: _preferredDays.toList(),

        preferredTherapyApproachIds: _therapyApproachIds.toList(),

        acceptSensitiveDataProcessing: alreadyAcceptedCurrentConsent
            ? false
            : _acceptedSensitiveDataProcessing,

        sensitiveDataProcessingVersion: alreadyAcceptedCurrentConsent
            ? ''
            : currentConsentVersion,
      ),
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      _showValidationMessage(
        _viewModel.error ?? 'Preference nije moguće sačuvati.',
      );

      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preference su uspješno sačuvane.')),
    );

    if (widget.onCompleted != null) {
      widget.onCompleted!();
      return;
    }

    Navigator.of(context).pop(true);
  }

  void _showValidationMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_viewModel.isLoading && _viewModel.onboarding == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_viewModel.error != null && _viewModel.onboarding == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Therapy preferences')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_viewModel.error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _viewModel.load,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: !widget.isRequired,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.isRequired,
          title: const Text('Your preferences'),
        ),
        body: Stepper(
          currentStep: _currentStep,
          onStepTapped: (step) {
            if (step <= _currentStep) {
              setState(() {
                _currentStep = step;
              });
            }
          },
          onStepContinue: _viewModel.isSaving ? null : _continue,
          onStepCancel: _currentStep == 0
              ? null
              : () {
                  setState(() {
                    _currentStep--;
                  });
                },
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: details.onStepContinue,
                    child: _viewModel.isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _currentStep == 6 ? 'Save preferences' : 'Continue',
                          ),
                  ),
                  if (_currentStep > 0) ...[
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text('Back'),
                    ),
                  ],
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text('About this assessment'),
              isActive: _currentStep >= 0,
              content: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'These questions help MindBloom personalize your experience and recommend therapists whose services may better match your preferences.',
                  ),
                  SizedBox(height: 12),
                  Text(
                    'This assessment is not a medical or psychological diagnosis and does not replace advice from a qualified healthcare professional.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Your answers are stored with your account and used for therapist recommendations. You can change them later from your profile.',
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('Areas of support'),
              isActive: _currentStep >= 1,
              content: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableFocusAreas
                    .map(
                      (area) => FilterChip(
                        label: Text(area),
                        selected: _focusAreas.contains(area),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _focusAreas.add(area);
                            } else {
                              _focusAreas.remove(area);
                            }
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
            Step(
              title: const Text('Therapy preferences'),
              isActive: _currentStep >= 2,
              content: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: const InputDecoration(
                      labelText: 'Preferred therapist gender',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Any',
                        child: Text('No preference'),
                      ),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _gender = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _sessionType,
                    decoration: const InputDecoration(
                      labelText: 'Preferred session type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Any',
                        child: Text('No preference'),
                      ),
                      DropdownMenuItem(value: 'Online', child: Text('Online')),
                      DropdownMenuItem(
                        value: 'InPerson',
                        child: Text('In person'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _sessionType = value;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('Language'),
              isActive: _currentStep >= 3,
              content: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableLanguages
                    .map(
                      (language) => FilterChip(
                        label: Text(language),
                        selected: _languages.contains(language),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _languages.add(language);
                            } else {
                              _languages.remove(language);
                            }
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
            Step(
              title: const Text('Budget and location'),
              isActive: _currentStep >= 4,
              content: Column(
                children: [
                  TextFormField(
                    controller: _locationController,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Location (optional)',
                      hintText: 'City or location',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _minimumPriceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Minimum',
                            suffixText: 'BAM',
                            border: OutlineInputBorder(),
                          ),
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
                            labelText: 'Maximum',
                            suffixText: 'BAM',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Preferred days (optional)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: List.generate(
                      7,
                      (day) => FilterChip(
                        label: Text(_dayNames[day]),
                        selected: _preferredDays.contains(day),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _preferredDays.add(day);
                            } else {
                              _preferredDays.remove(day);
                            }
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('Therapy approaches'),
              isActive: _currentStep >= 5,
              content: _buildApproaches(),
            ),
            Step(
              title: const Text('Review and save'),
              isActive: _currentStep >= 6,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Areas: ${_focusAreas.join(", ")}'),

                  const SizedBox(height: 8),

                  Text('Therapist gender: $_gender'),

                  const SizedBox(height: 8),

                  Text('Session type: $_sessionType'),

                  const SizedBox(height: 8),

                  Text('Languages: ${_languages.join(", ")}'),

                  const SizedBox(height: 20),

                  const Divider(),

                  const SizedBox(height: 12),

                  const Text(
                    'Privacy and assessment data',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    _viewModel.sensitiveDataUsageExplanation.trim().isNotEmpty
                        ? _viewModel.sensitiveDataUsageExplanation
                        : 'Assessment information is used to personalize your onboarding and therapist recommendations.',
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'The assessment does not represent a medical or psychological diagnosis.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),

                  const SizedBox(height: 16),

                  if (_viewModel.hasAcceptedCurrentSensitiveDataConsent)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.verified_user_outlined),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Text(
                              'You have already accepted the current sensitive data processing consent '
                              '(version ${_viewModel.currentSensitiveDataProcessingVersion}).',
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    CheckboxListTile(
                      value: _acceptedSensitiveDataProcessing,

                      onChanged: _viewModel.isSaving
                          ? null
                          : (value) {
                              setState(() {
                                _acceptedSensitiveDataProcessing =
                                    value ?? false;
                              });
                            },

                      controlAffinity: ListTileControlAffinity.leading,

                      contentPadding: EdgeInsets.zero,

                      title: const Text(
                        'I consent to the processing of my assessment information for the purposes described above.',
                      ),

                      subtitle: Text(
                        'Consent version: '
                        '${_viewModel.currentSensitiveDataProcessingVersion}',
                      ),
                    ),

                  const SizedBox(height: 12),

                  const Text(
                    'By saving, these answers will be used to personalize therapist recommendations.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApproaches() {
    if (_viewModel.therapyApproaches.isEmpty) {
      return const Text('No therapy approaches are currently available.');
    }

    return Column(
      children: _viewModel.therapyApproaches.map(_buildApproachTile).toList(),
    );
  }

  Widget _buildApproachTile(TherapyApproachModel approach) {
    return CheckboxListTile(
      value: _therapyApproachIds.contains(approach.id),
      title: Text(approach.name),
      subtitle: approach.description.isEmpty
          ? null
          : Text(approach.description),
      onChanged: (selected) {
        setState(() {
          if (selected == true) {
            _therapyApproachIds.add(approach.id);
          } else {
            _therapyApproachIds.remove(approach.id);
          }
        });
      },
    );
  }
}
