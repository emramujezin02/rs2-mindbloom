import '../../../../core/time/appointment_time_zone.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/validation/app_validators.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../therapist/data/models/therapist_model.dart';
import '../widgets/booking_calendar.dart';
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
  final AppointmentCreateViewModel? viewModel;

  const AppointmentCreatePage({
    super.key,
    required this.therapist,
    this.initialSlot,
    this.returnResultOnSuccess = false,
    this.viewModel,
  });

  @override
  State<AppointmentCreatePage> createState() => _AppointmentCreatePageState();
}

class _AppointmentCreatePageState extends State<AppointmentCreatePage> {
  late final AppointmentCreateViewModel _viewModel;

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
    _viewModel = widget.viewModel ?? AppInjection.createAppointmentViewModel();
    _notesController.addListener(_onChanged);

    _type = widget.therapist.offersOnline ? 1 : 2;

    _viewModel.addListener(_onChanged);

    _initialize();
  }

  Future<void> _initialize() async {
    await _viewModel.loadBookingData(widget.therapist.id);

    if (!mounted) {
      return;
    }

    final initialSlot = widget.initialSlot == null
        ? null
        : AppointmentTimeZone.fromInstant(widget.initialSlot!);

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

  Future<void> _selectDate(DateTime date) async {
    if (_isSubmitting || !_viewModel.isDateSelectable(date)) return;
    setState(() {
      _selectedDate = date;
      _selectedSlot = null;
    });
    await _viewModel.loadAvailableSlots(
      therapistId: widget.therapist.id,
      date: date,
    );
  }

  Future<void> _continue() async {
    if (_isSubmitting || _viewModel.isLoadingSlots) {
      return;
    }

    final isValid = await _validateCurrentStep();

    if (!isValid || !mounted) {
      return;
    }

    if (_currentStep < 2) {
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
    if (_selectedDate == null || !_viewModel.isDateSelectable(_selectedDate!)) {
      _showMessage('Izaberite važeći datum termina.');
      return false;
    }
    if (_currentStep == 0) return true;
    if (_selectedSlot == null ||
        !_selectedSlot!.isAfter(_viewModel.now) ||
        !_viewModel.availableSlots.any(
          (slot) => _isSameSlot(slot, _selectedSlot!),
        )) {
      setState(() => _selectedSlot = null);
      _showMessage('Izaberite slobodan termin.');
      return false;
    }
    if (_currentStep == 1) return true;
    if ((_type == 1 && !widget.therapist.offersOnline) ||
        (_type == 2 &&
            (!widget.therapist.offersInPerson ||
                widget.therapist.address.trim().isEmpty))) {
      _showMessage('Odabrani tip seanse nije dostupan kod ovog terapeuta.');
      return false;
    }
    return _formKey.currentState?.validate() ?? false;
  }

  Future<void> _confirmAndSubmit() async {
    if (_isSubmitting || _selectedDate == null || _selectedSlot == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final selectedDate = _selectedDate!;
    final selectedSlot = _selectedSlot!;

    await _viewModel.loadAvailableSlots(
      therapistId: widget.therapist.id,
      date: selectedDate,
    );

    if (!mounted) {
      return;
    }

    if (_viewModel.error != null) {
      setState(() {
        _isSubmitting = false;
        _selectedSlot = null;
        _currentStep = 1;
      });
      _showMessage(_friendlyErrorMessage(_viewModel.error));
      return;
    }

    final slotStillAvailable = _viewModel.availableSlots.any(
      (slot) => _isSameSlot(slot, selectedSlot),
    );

    if (!slotStillAvailable) {
      setState(() {
        _selectedSlot = null;
        _currentStep = 1;
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
        _currentStep = 1;
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

    return _viewModel.errorStatusCode == 409 ||
        normalized.contains('already booked') ||
        normalized.contains('already occupied') ||
        normalized.contains('conflict') ||
        normalized.contains('409');
  }

  String _friendlyErrorMessage(String? error) {
    if (_isConflictError(error) && (error == null || error.trim().isEmpty)) {
      return 'The selected appointment time is no longer available. Please choose another time.';
    }

    if (error == null || error.trim().isEmpty) {
      return 'The appointment could not be created. Please try again.';
    }

    return error.replaceFirst('Exception: ', '').trim();
  }

  bool _isSameSlot(DateTime first, DateTime second) {
    return first.isAtSameMomentAs(second);
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
    if (_isSuccess) return _buildSuccessScreen();
    final busy = _isSubmitting || _viewModel.isLoadingSlots;
    return PopScope(
      canPop: _currentStep == 0 && !_isSubmitting,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: _appointmentBackground,
        appBar: AppBar(
          title: const Text('Zakaži termin'),
          backgroundColor: _appointmentBackground,
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _BookingProgressHeader(
                  currentStep: _currentStep,
                  therapistName: widget.therapist.fullName,
                  selectedSlot: _selectedSlot,
                  sessionType: _sessionTypeLabel,
                ),
                const SizedBox(height: 16),
                Text(
                  ['Izbor datuma', 'Izbor termina', 'Potvrda'][_currentStep],
                  key: const Key('booking-step-title'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _appointmentText,
                  ),
                ),
                const SizedBox(height: 12),
                if (_viewModel.isLoading && _viewModel.availabilities.isEmpty)
                  const AppInlineLoadingIndicator(
                    message: 'Učitavanje rasporeda...',
                  )
                else ...[
                  if (_viewModel.error != null) ...[
                    Text(
                      _viewModel.error!,
                      key: const Key('booking-error'),
                      style: const TextStyle(color: Colors.red),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () async {
                              if (_viewModel.availabilities.isEmpty) {
                                await _initialize();
                              } else if (_selectedDate != null) {
                                await _viewModel.loadAvailableSlots(
                                  therapistId: widget.therapist.id,
                                  date: _selectedDate!,
                                );
                              }
                            },
                      child: const Text('Pokušaj ponovo'),
                    ),
                  ],
                  if (_currentStep == 0) _buildDateStep(),
                  if (_currentStep == 1) _buildTimeStep(),
                  if (_currentStep == 2) _buildConfirmationStep(),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('booking-next'),
                    onPressed:
                        busy ||
                            _viewModel.isLoading ||
                            (_currentStep == 0 &&
                                (_selectedDate == null ||
                                    !_viewModel.isDateSelectable(
                                      _selectedDate!,
                                    ))) ||
                            (_currentStep > 0 && _selectedSlot == null)
                        ? null
                        : _continue,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(_currentStep == 2 ? 'DA' : 'Nastavi'),
                  ),
                  if (_currentStep > 0) ...[
                    const SizedBox(height: 10),
                    OutlinedButton(
                      key: const Key('booking-back'),
                      onPressed: _isSubmitting ? null : _goBack,
                      child: Text(_currentStep == 2 ? 'NE' : 'Nazad'),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateStep() {
    return _AppointmentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Datumi i vrijeme prikazani su u vremenskoj zoni Europe/Sarajevo.',
          ),
          if (_viewModel.availabilities.isEmpty)
            const Text('Terapeut još nije objavio raspored.'),
          BookingCalendar(
            today: _viewModel.today,
            lastDate: _viewModel.lastBookingDate,
            selectedDate: _selectedDate,
            isSelectable: _viewModel.isDateSelectable,
            onSelected: _selectDate,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeStep() {
    if (_viewModel.isLoadingSlots) {
      return const AppInlineLoadingIndicator(message: 'Učitavanje termina...');
    }
    if (_viewModel.bookingSlots.isEmpty) {
      return const AppInlineEmptyState(
        icon: Icons.event_busy_outlined,
        message:
            'Za odabrani datum nema ponuđenih termina. Izaberite drugi datum.',
      );
    }
    return _AppointmentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(DateFormat('dd.MM.yyyy.').format(_selectedDate!)),
          const Text('Europe/Sarajevo · 60 minuta'),
          if (_viewModel.availableSlots.isEmpty)
            const Text('Svi ponuđeni termini su zauzeti.'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _viewModel.bookingSlots.map((slot) {
              final selected =
                  _selectedSlot != null &&
                  _isSameSlot(_selectedSlot!, slot.start);
              final label =
                  '${DateFormat('HH:mm').format(slot.start)} – ${DateFormat('HH:mm').format(slot.end)}';
              return Semantics(
                selected: selected,
                child: OutlinedButton(
                  key: Key('slot-${slot.start.toUtc().toIso8601String()}'),
                  onPressed: slot.isAvailable && !_isSubmitting
                      ? () => setState(() => _selectedSlot = slot.start)
                      : null,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: selected
                        ? _appointmentPrimary
                        : _appointmentSurface,
                    foregroundColor: selected ? Colors.white : _appointmentText,
                    disabledBackgroundColor: const Color(0xFFD4CEDB),
                    disabledForegroundColor: const Color(0xFF47404F),
                  ),
                  child: Text(
                    slot.isOccupied ? '$label\nZauzeto' : label,
                    textAlign: TextAlign.center,
                  ),
                ),
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
        if (_isSubmitting || value == null) {
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
        key: const Key('booking-notes'),
        controller: _notesController,
        onChanged: (_) => _viewModel.fieldErrors.clear(),
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
            value: '${widget.therapist.hourlyRate.toStringAsFixed(2)} USD',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSessionTypeStep(),
        const SizedBox(height: 12),
        _buildNotesStep(),
        const SizedBox(height: 12),
        _buildReviewStep(),
        const SizedBox(height: 12),
        const Text(
          'Zahtjev se šalje terapeutu. Plaćanje ili korištenje članarine dostupno je nakon prihvatanja termina.',
        ),
      ],
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
    final progress = (currentStep + 1) / 3;
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
                      'Korak ${currentStep + 1} od 3',
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
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: _appointmentText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
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
      child: Material(type: MaterialType.transparency, child: child),
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
