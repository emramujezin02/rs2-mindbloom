import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/validation/app_validators.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../therapist/data/models/therapist_model.dart';
import '../../../therapist/presentation/widgets/therapist_profile_image.dart';
import '../viewmodels/appointment_create_viewmodel.dart';

const _appointmentBackground = Color(0xFFFCFAFF);
const _appointmentSurface = Color(0xFFFFFFFF);
const _appointmentLavender = Color(0xFFF6F0FC);
const _appointmentBorder = Color(0xFFE7DDF1);
const _appointmentPrimary = Color(0xFF6D4F91);
const _appointmentText = Color(0xFF372D45);
const _appointmentMuted = Color(0xFF6C6278);
const _appointmentRadius = 20.0;

class AppointmentCreatePage extends StatefulWidget {
  final TherapistModel therapist;
  final DateTime? initialSlot;
  final bool returnResultOnSuccess;

  const AppointmentCreatePage({
    super.key,
    required this.therapist,
    this.initialSlot,
    this.returnResultOnSuccess = false,
  });

  @override
  State<AppointmentCreatePage> createState() => _AppointmentCreatePageState();
}

class _AppointmentCreatePageState extends State<AppointmentCreatePage> {
  final AppointmentCreateViewModel _viewModel =
      AppInjection.createAppointmentViewModel();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _notesController = TextEditingController();

  int _currentStep = 0;

  DateTime? _selectedDate;
  DateTime? _selectedSlot;

  late int _type;

  bool _isSubmitting = false;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();

    _type = widget.therapist.offersOnline ? 1 : 2;

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

    _selectedDate = initialDate;

    await _viewModel.loadAvailableSlots(
      therapistId: widget.therapist.id,
      date: initialDate,
    );

    if (!mounted) {
      return;
    }

    DateTime? matchingSlot;

    for (final slot in _viewModel.availableSlots) {
      if (_isSameSlot(slot, initialSlot)) {
        matchingSlot = slot;
        break;
      }
    }

    setState(() {
      _selectedSlot = matchingSlot;

      if (matchingSlot != null) {
        _currentStep = 2;
      }
    });
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _viewModel.dispose();

    _notesController.dispose();

    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickDate() async {
    if (_viewModel.availabilities.isEmpty) {
      _showMessage('This therapist has not published availability.');

      return;
    }

    final now = DateTime.now();

    final firstDate = DateTime(now.year, now.month, now.day);

    final lastDate = firstDate.add(const Duration(days: 365));

    final initialDate = _findFirstSelectableDate(firstDate, lastDate);

    if (initialDate == null) {
      _showMessage('No available booking dates were found.');

      return;
    }

    final currentlySelected = _selectedDate;

    final validInitialDate =
        currentlySelected != null &&
            _viewModel.isDateSelectable(currentlySelected)
        ? currentlySelected
        : initialDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: validInitialDate,
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

  Future<void> _continue() async {
    if (_isSubmitting || _viewModel.isLoadingSlots) {
      return;
    }

    final isValid = await _validateCurrentStep();

    if (!isValid || !mounted) {
      return;
    }

    if (_currentStep < 6) {
      setState(() {
        _currentStep++;
      });

      return;
    }

    await _confirmAndSubmit();
  }

  void _goBack() {
    if (_isSubmitting || _currentStep == 0) {
      return;
    }

    setState(() {
      _currentStep--;
    });
  }

  Future<bool> _validateCurrentStep() async {
    switch (_currentStep) {
      case 0:
        return true;

      case 1:
        if (_selectedDate == null) {
          _showMessage('Please choose an appointment date.');

          return false;
        }

        return true;

      case 2:
        if (_selectedSlot == null) {
          _showMessage('Please choose an available appointment time.');

          return false;
        }

        final stillAvailable = _viewModel.availableSlots.any(
          (slot) => _isSameSlot(slot, _selectedSlot!),
        );

        if (!stillAvailable) {
          _selectedSlot = null;

          _showMessage('The selected appointment time is no longer available.');

          return false;
        }

        return true;

      case 3:
        if (_type == 1 && !widget.therapist.offersOnline) {
          _showMessage('This therapist does not offer online sessions.');

          return false;
        }

        if (_type == 2 && !widget.therapist.offersInPerson) {
          _showMessage('This therapist does not offer in-person sessions.');

          return false;
        }

        if (_type == 2 && widget.therapist.address.trim().isEmpty) {
          _showMessage('The therapist has not provided an office address.');

          return false;
        }

        return true;

      case 4:
        return _formKey.currentState?.validate() ?? false;

      case 5:
        return true;

      case 6:
        return true;

      default:
        return false;
    }
  }

  Future<void> _confirmAndSubmit() async {
    if (_isSubmitting || _selectedDate == null || _selectedSlot == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm appointment'),
          content: const Text(
            'Are you sure you want to send this appointment request?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final selectedDate = _selectedDate!;

    await _viewModel.loadAvailableSlots(
      therapistId: widget.therapist.id,
      date: selectedDate,
    );

    if (!mounted) {
      return;
    }

    final selectedSlot = _selectedSlot!;

    final slotStillAvailable = _viewModel.availableSlots.any(
      (slot) => _isSameSlot(slot, selectedSlot),
    );

    if (!slotStillAvailable) {
      setState(() {
        _selectedSlot = null;
        _currentStep = 2;
        _isSubmitting = false;
      });

      _showMessage(
        'This appointment time has just been booked. Please choose another available time.',
      );

      return;
    }

    final startUtc = selectedSlot.toUtc();

    final endUtc = selectedSlot
        .add(AppointmentCreateViewModel.appointmentDuration)
        .toUtc();

    final notes = _notesController.text.trim();

    final success = await _viewModel.createAppointment(
      therapistId: widget.therapist.id,
      startUtc: startUtc,
      endUtc: endUtc,
      type: _type,
      meetingLink: null,
      location: _type == 2 ? widget.therapist.address.trim() : null,
      notes: notes.isEmpty ? null : notes,
    );

    if (!success && mounted) {
      _formKey.currentState?.validate();
    }

    if (!mounted) {
      return;
    }

    if (success) {
      setState(() {
        _isSubmitting = false;
        _isSuccess = true;
      });

      return;
    }

    final errorMessage = _friendlyErrorMessage(_viewModel.error);

    final isConflict = _isConflictError(_viewModel.error);

    if (isConflict) {
      await _viewModel.loadAvailableSlots(
        therapistId: widget.therapist.id,
        date: selectedDate,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedSlot = null;
        _currentStep = 2;
        _isSubmitting = false;
      });
    } else {
      setState(() {
        _isSubmitting = false;
      });
    }

    _showMessage(errorMessage);
  }

  bool _isConflictError(String? error) {
    final normalized = error?.toLowerCase() ?? '';

    return normalized.contains('already booked') ||
        normalized.contains('already occupied') ||
        normalized.contains('conflict') ||
        normalized.contains('409');
  }

  String _friendlyErrorMessage(String? error) {
    if (_isConflictError(error)) {
      return 'The selected appointment time is no longer available. Please choose another time.';
    }

    if (error == null || error.trim().isEmpty) {
      return 'The appointment could not be created. Please try again.';
    }

    return error.replaceFirst('Exception: ', '').trim();
  }

  bool _isSameSlot(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day &&
        first.hour == second.hour &&
        first.minute == second.minute;
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) {
      return _buildSuccessScreen();
    }

    if (_viewModel.isLoading && _viewModel.availabilities.isEmpty) {
      return Scaffold(
        backgroundColor: _appointmentBackground,
        appBar: AppBar(
          title: const Text('Book appointment'),
          backgroundColor: _appointmentBackground,
          surfaceTintColor: Colors.transparent,
        ),
        body: const AppLoadingWidget(message: 'Loading available times...'),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _appointmentBackground,
      appBar: AppBar(
        title: const Text('Book appointment'),
        backgroundColor: _appointmentBackground,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Theme(
            data: theme.copyWith(
              canvasColor: _appointmentBackground,
              colorScheme: theme.colorScheme.copyWith(
                primary: _appointmentPrimary,
                surface: _appointmentSurface,
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: _BookingProgressHeader(
                    currentStep: _currentStep,
                    therapistName: widget.therapist.fullName,
                    selectedSlot: _selectedSlot,
                    sessionType: _sessionTypeLabel,
                  ),
                ),
                Expanded(
                  child: Stepper(
                    currentStep: _currentStep,
                    type: StepperType.vertical,
                    physics: const ClampingScrollPhysics(),
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    onStepContinue: _continue,
                    onStepCancel: _goBack,
                    onStepTapped: (step) {
                      if (_isSubmitting) {
                        return;
                      }

                      if (step <= _currentStep) {
                        setState(() {
                          _currentStep = step;
                        });
                      }
                    },
                    controlsBuilder: (context, details) {
                      final isFinalStep = _currentStep == 6;

                      return Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final stackButtons = constraints.maxWidth < 340;
                            final primaryButton = FilledButton.icon(
                              onPressed:
                                  _isSubmitting || _viewModel.isLoadingSlots
                                  ? null
                                  : details.onStepContinue,
                              icon: _isSubmitting && isFinalStep
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      isFinalStep
                                          ? Icons.check_circle_outline
                                          : Icons.arrow_forward,
                                    ),
                              label: Text(
                                isFinalStep ? 'Confirm booking' : 'Next',
                              ),
                            );

                            if (_currentStep == 0) {
                              return SizedBox(
                                width: double.infinity,
                                child: primaryButton,
                              );
                            }

                            final secondaryButton = OutlinedButton.icon(
                              onPressed: _isSubmitting
                                  ? null
                                  : details.onStepCancel,
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Back'),
                            );

                            if (stackButtons) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  primaryButton,
                                  const SizedBox(height: 10),
                                  secondaryButton,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: primaryButton),
                                const SizedBox(width: 12),
                                Expanded(child: secondaryButton),
                              ],
                            );
                          },
                        ),
                      );
                    },
                    steps: [
                      Step(
                        title: const Text('Therapist'),
                        subtitle: Text(
                          widget.therapist.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isActive: _currentStep >= 0,
                        state: _stepState(0),
                        content: _buildTherapistStep(),
                      ),
                      Step(
                        title: const Text('Date'),
                        subtitle: Text(
                          _selectedDate == null
                              ? 'Choose a date'
                              : DateFormat(
                                  'dd.MM.yyyy.',
                                ).format(_selectedDate!),
                        ),
                        isActive: _currentStep >= 1,
                        state: _stepState(1),
                        content: _buildDateStep(),
                      ),
                      Step(
                        title: const Text('Available time'),
                        subtitle: Text(
                          _selectedSlot == null
                              ? 'Choose a time'
                              : DateFormat('HH:mm').format(_selectedSlot!),
                        ),
                        isActive: _currentStep >= 2,
                        state: _stepState(2),
                        content: _buildTimeStep(),
                      ),
                      Step(
                        title: const Text('Session type'),
                        subtitle: Text(_sessionTypeLabel),
                        isActive: _currentStep >= 3,
                        state: _stepState(3),
                        content: _buildSessionTypeStep(),
                      ),
                      Step(
                        title: const Text('Notes'),
                        subtitle: const Text('Additional information'),
                        isActive: _currentStep >= 4,
                        state: _stepState(4),
                        content: _buildNotesStep(),
                      ),
                      Step(
                        title: const Text('Review'),
                        subtitle: const Text('Check appointment details'),
                        isActive: _currentStep >= 5,
                        state: _stepState(5),
                        content: _buildReviewStep(),
                      ),
                      Step(
                        title: const Text('Confirmation'),
                        subtitle: const Text('Send appointment request'),
                        isActive: _currentStep >= 6,
                        state: _stepState(6),
                        content: _buildConfirmationStep(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  StepState _stepState(int step) {
    if (_currentStep > step) {
      return StepState.complete;
    }

    if (_currentStep == step) {
      return StepState.editing;
    }

    return StepState.indexed;
  }

  Widget _buildTherapistStep() {
    return _AppointmentCard(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: _appointmentLavender,
              shape: BoxShape.circle,
            ),
            child: TherapistProfileImage(
              fullName: widget.therapist.fullName,
              profileImageUrl: widget.therapist.profileImageUrl,
              radius: 46,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.therapist.fullName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _appointmentText,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.therapist.specialization,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _appointmentMuted, height: 1.35),
          ),
          const SizedBox(height: 16),
          _SummaryRow(
            icon: Icons.payments_outlined,
            label: 'Session price',
            value: '${widget.therapist.hourlyRate.toStringAsFixed(2)} BAM',
          ),
          const _SoftDivider(),
          _SummaryRow(
            icon: Icons.schedule,
            label: 'Duration',
            value: '60 minutes',
          ),
          const _SoftDivider(),
          _SummaryRow(
            icon: Icons.video_call_outlined,
            label: 'Available options',
            value: _availableModesLabel,
          ),
        ],
      ),
    );
  }

  Widget _buildDateStep() {
    return _AppointmentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepIntro(
            icon: Icons.calendar_month_outlined,
            title: 'Choose an appointment date',
            message: 'Only days with published availability can be selected.',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _viewModel.isLoading ? null : _pickDate,
            icon: const Icon(Icons.calendar_month),
            label: Text(
              _selectedDate == null
                  ? 'Choose an available date'
                  : DateFormat('EEEE, dd.MM.yyyy.').format(_selectedDate!),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeStep() {
    if (_selectedDate == null) {
      return const _AppointmentCard(
        child: _StepIntro(
          icon: Icons.event_available_outlined,
          title: 'Date first',
          message: 'Choose a date before selecting an appointment time.',
        ),
      );
    }

    if (_viewModel.isLoadingSlots) {
      return const _AppointmentCard(
        child: AppInlineLoadingIndicator(message: 'Loading available times...'),
      );
    }

    if (_viewModel.availableSlots.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppInlineEmptyState(
            icon: Icons.event_busy_outlined,
            message: 'There are no available times on this date.',
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month),
            label: const Text('Choose another date'),
          ),
        ],
      );
    }

    return _AppointmentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIntro(
            icon: Icons.schedule_outlined,
            title: DateFormat('EEEE, dd.MM.yyyy.').format(_selectedDate!),
            message: 'Select the time that works best for you.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _viewModel.availableSlots.map((slot) {
              final selected =
                  _selectedSlot != null && _isSameSlot(_selectedSlot!, slot);

              return ChoiceChip(
                label: Text(DateFormat('HH:mm').format(slot)),
                selected: selected,
                showCheckmark: false,
                avatar: Icon(
                  Icons.schedule,
                  size: 17,
                  color: selected ? Colors.white : _appointmentPrimary,
                ),
                selectedColor: _appointmentPrimary,
                backgroundColor: _appointmentSurface,
                side: BorderSide(
                  color: selected ? _appointmentPrimary : _appointmentBorder,
                ),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : _appointmentText,
                  fontWeight: FontWeight.w700,
                ),
                onSelected: (isSelected) {
                  setState(() {
                    _selectedSlot = isSelected ? slot : null;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTypeStep() {
    return RadioGroup<int>(
      groupValue: _type,
      onChanged: (value) {
        if (value == null) {
          return;
        }
        setState(() {
          _type = value;
        });
      },
      child: Column(
        children: [
          if (widget.therapist.offersOnline)
            const _SessionTypeOption(
              value: 1,
              icon: Icons.video_call_outlined,
              title: 'Online session',
              subtitle:
                  'The therapist will provide the meeting link after accepting the appointment.',
            ),
          if (widget.therapist.offersOnline && widget.therapist.offersInPerson)
            const SizedBox(height: 10),
          if (widget.therapist.offersInPerson)
            _SessionTypeOption(
              value: 2,
              icon: Icons.location_on_outlined,
              title: 'In-person session',
              subtitle: widget.therapist.address.trim().isEmpty
                  ? 'Office address is not specified.'
                  : widget.therapist.address,
            ),
        ],
      ),
    );
  }

  Widget _buildNotesStep() {
    return _AppointmentCard(
      child: TextFormField(
        controller: _notesController,
        minLines: 4,
        maxLines: 7,
        maxLength: 2000,
        enabled: !_isSubmitting,
        decoration: InputDecoration(
          labelText: 'Note for therapist',
          hintText:
              'Briefly describe what you would like to discuss or add important context.',
          alignLabelWithHint: true,
          filled: true,
          fillColor: _appointmentBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _appointmentBorder),
          ),
        ),
        validator: (value) {
          return _viewModel.fieldError('Notes') ??
              AppValidators.appointmentNotes(value);
        },
      ),
    );
  }

  Widget _buildReviewStep() {
    return _AppointmentCard(
      child: Column(
        children: [
          _SummaryRow(
            icon: Icons.person_outline,
            label: 'Therapist',
            value: widget.therapist.fullName,
          ),
          const _SoftDivider(),
          _SummaryRow(
            icon: Icons.calendar_today_outlined,
            label: 'Date',
            value: _selectedDate == null
                ? 'Not selected'
                : DateFormat('dd.MM.yyyy.').format(_selectedDate!),
          ),
          const _SoftDivider(),
          _SummaryRow(
            icon: Icons.schedule,
            label: 'Time',
            value: _selectedSlot == null
                ? 'Not selected'
                : '${DateFormat('HH:mm').format(_selectedSlot!)} - '
                      '${DateFormat('HH:mm').format(_selectedSlot!.add(AppointmentCreateViewModel.appointmentDuration))}',
          ),
          const _SoftDivider(),
          _SummaryRow(
            icon: Icons.video_call_outlined,
            label: 'Session type',
            value: _sessionTypeLabel,
          ),
          const _SoftDivider(),
          _SummaryRow(
            icon: Icons.location_on_outlined,
            label: _type == 1 ? 'Session location' : 'Office location',
            value: _type == 1 ? 'Online' : widget.therapist.address,
          ),
          const _SoftDivider(),
          _SummaryRow(
            icon: Icons.payments_outlined,
            label: 'Price',
            value: '${widget.therapist.hourlyRate.toStringAsFixed(2)} BAM',
          ),
          const _SoftDivider(),
          _SummaryRow(
            icon: Icons.notes_outlined,
            label: 'Notes',
            value: _notesController.text.trim().isEmpty
                ? 'No additional notes'
                : _notesController.text.trim(),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationStep() {
    return const _AppointmentCard(
      child: Column(
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 42,
            color: _appointmentPrimary,
          ),
          SizedBox(height: 12),
          Text(
            'The appointment will only be created after you press "Confirm booking" and confirm the dialog.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _appointmentMuted, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: _appointmentBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Appointment created'),
        backgroundColor: _appointmentBackground,
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _AppointmentCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: const BoxDecoration(
                    color: _appointmentLavender,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 56,
                    color: _appointmentPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Appointment request sent successfully',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _appointmentText,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${widget.therapist.fullName}\n'
                  '${_selectedSlot == null ? '' : DateFormat('dd.MM.yyyy. HH:mm').format(_selectedSlot!)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _appointmentMuted),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      if (widget.returnResultOnSuccess) {
                        Navigator.of(context).pop(true);

                        return;
                      }

                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRouter.myAppointments,
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.event_note_outlined),
                    label: Text(
                      widget.returnResultOnSuccess
                          ? 'Return to therapist'
                          : 'View my appointments',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _sessionTypeLabel {
    return _type == 1 ? 'Online' : 'In person';
  }

  String get _availableModesLabel {
    if (widget.therapist.offersOnline && widget.therapist.offersInPerson) {
      return 'Online and in person';
    }

    if (widget.therapist.offersOnline) {
      return 'Online';
    }

    if (widget.therapist.offersInPerson) {
      return 'In person';
    }

    return 'Not specified';
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _appointmentLavender,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: _appointmentPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _appointmentMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: _appointmentText,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingProgressHeader extends StatelessWidget {
  final int currentStep;
  final String therapistName;
  final DateTime? selectedSlot;
  final String sessionType;

  const _BookingProgressHeader({
    required this.currentStep,
    required this.therapistName,
    required this.selectedSlot,
    required this.sessionType,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (currentStep + 1) / 7;
    final slotLabel = selectedSlot == null
        ? 'Choose date and time'
        : DateFormat('dd.MM.yyyy. HH:mm').format(selectedSlot!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _appointmentSurface,
        borderRadius: BorderRadius.circular(_appointmentRadius),
        border: Border.all(color: _appointmentBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: _appointmentLavender,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_available_outlined,
                  color: _appointmentPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step ${currentStep + 1} of 7',
                      style: const TextStyle(
                        color: _appointmentPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      therapistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _appointmentText,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: _appointmentLavender,
              color: _appointmentPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniPill(icon: Icons.schedule_outlined, label: slotLabel),
              _MiniPill(icon: Icons.spa_outlined, label: sessionType),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _appointmentLavender,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _appointmentBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _appointmentPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: _appointmentText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _AppointmentCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _appointmentSurface,
        borderRadius: BorderRadius.circular(_appointmentRadius),
        border: Border.all(color: _appointmentBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StepIntro extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _StepIntro({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _appointmentLavender,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: _appointmentPrimary, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _appointmentText,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: const TextStyle(color: _appointmentMuted, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SessionTypeOption extends StatelessWidget {
  final int value;
  final IconData icon;
  final String title;
  final String subtitle;

  const _SessionTypeOption({
    required this.value,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return _AppointmentCard(
      padding: EdgeInsets.zero,
      child: RadioListTile<int>(
        value: value,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        secondary: Icon(icon, color: _appointmentPrimary),
        title: Text(
          title,
          style: const TextStyle(
            color: _appointmentText,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: _appointmentMuted, height: 1.3),
        ),
      ),
    );
  }
}

class _SoftDivider extends StatelessWidget {
  const _SoftDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 18, color: _appointmentBorder);
  }
}
