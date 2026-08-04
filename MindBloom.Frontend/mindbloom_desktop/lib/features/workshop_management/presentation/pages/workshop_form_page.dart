import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/validation/app_validators.dart';
import '../../../../core/validation/file_validation.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../viewmodels/workshop_form_viewmodel.dart';
import '../../../../core/widgets/app_error_panel.dart';
import '../../../../core/widgets/app_loading_overlay.dart';
import '../../../../core/widgets/app_loading_state.dart';

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

  final TextEditingController _imageUrlController = TextEditingController();

  final TextEditingController _onlineLinkController = TextEditingController();

  final TextEditingController _locationController = TextEditingController();

  final TextEditingController _capacityController = TextEditingController();

  final TextEditingController _priceController = TextEditingController();

  late DateTime _startDateTime;
  late DateTime _endDateTime;

  int _type = 1;
  int? _therapistId;

  bool _initialValuesApplied = false;

  DateTime? _registrationDeadline;

  String? _dateError;

  bool get _isEditing => widget.workshopId != null;

  bool get _isBusy => _viewModel.isSaving || _viewModel.isUploadingImage;

  @override
  void initState() {
    super.initState();

    _startDateTime = DateTime.now().add(const Duration(days: 1));

    _endDateTime = _startDateTime.add(const Duration(hours: 2));

    if (widget.workshopId == null) {
      _registrationDeadline = _startDateTime.subtract(const Duration(hours: 1));
    }

    _capacityController.text = '20';

    _priceController.text = '0';

    _viewModel = AppInjection.createWorkshopFormViewModel();

    _viewModel.addListener(_onViewModelChanged);

    _titleController.addListener(_onFieldChanged);

    _descriptionController.addListener(_onFieldChanged);

    _onlineLinkController.addListener(_onFieldChanged);

    _locationController.addListener(_onFieldChanged);

    _capacityController.addListener(_onFieldChanged);

    _priceController.addListener(_onFieldChanged);

    _viewModel.initialize(widget.workshopId);
  }

  void _onFieldChanged() {
    _viewModel.clearError();

    if (_dateError != null && mounted) {
      setState(() {
        _dateError = null;
      });
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);

    _titleController.removeListener(_onFieldChanged);

    _descriptionController.removeListener(_onFieldChanged);

    _onlineLinkController.removeListener(_onFieldChanged);

    _locationController.removeListener(_onFieldChanged);

    _capacityController.removeListener(_onFieldChanged);

    _priceController.removeListener(_onFieldChanged);

    _titleController.dispose();
    _descriptionController.dispose();
    _onlineLinkController.dispose();
    _locationController.dispose();
    _capacityController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();

    _viewModel.dispose();

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

    _imageUrlController.text = workshop.imageUrl ?? '';

    _registrationDeadline = workshop.registrationDeadlineUtc.toLocal();

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

  Future<void> _pickRegistrationDeadline() async {
    if (_isBusy) {
      return;
    }

    final current =
        _registrationDeadline ?? DateTime.now().add(const Duration(days: 1));

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );

    if (selectedTime == null || !mounted) {
      return;
    }

    setState(() {
      _registrationDeadline = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      _dateError = null;
    });

    _viewModel.clearError();
  }

  Future<void> _pickAndUploadImage() async {
    if (_viewModel.isUploadingImage || _viewModel.isSaving) {
      return;
    }

    _viewModel.clearError();

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: FileValidation.allowedImageExtensions,
      allowMultiple: false,
      withData: false,
    );

    if (result == null || result.files.isEmpty || !mounted) {
      return;
    }

    final selectedFile = result.files.single;

    final validationMessage = FileValidation.validateImage(
      filePath: selectedFile.path,
      extension: selectedFile.extension ?? '',
      sizeInBytes: selectedFile.size,
    );

    if (validationMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationMessage)));

      return;
    }

    final imageUrl = await _viewModel.uploadImage(selectedFile.path!);

    if (!mounted) {
      return;
    }

    if (imageUrl == null) {
      return;
    }

    _imageUrlController.text = imageUrl;

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Slika radionice je uspješno učitana.')),
    );
  }

  String _resolveImageUrl(String imageUrl) {
    final normalized = imageUrl.trim();

    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }

    final apiUri = Uri.parse(ApiConstants.apiBaseUrl);

    return apiUri
        .replace(
          path: normalized.startsWith('/') ? normalized : '/$normalized',
          query: null,
          fragment: null,
        )
        .toString();
  }

  Future<void> _selectStartDate() async {
    if (_isBusy) {
      return;
    }

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

      if (!_endDateTime.isAfter(_startDateTime)) {
        _endDateTime = _startDateTime.add(const Duration(hours: 2));
      }

      _dateError = null;
    });

    _viewModel.clearError();
  }

  Future<void> _selectEndDate() async {
    if (_isBusy) {
      return;
    }

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

      _dateError = null;
    });

    _viewModel.clearError();
  }

  String? _validateCapacity(String? value) {
    final baseError = AppValidators.integerRange(
      value,
      fieldName: 'Broj mjesta',
      minimum: 1,
      maximum: 10000,
    );

    if (baseError != null) {
      return baseError;
    }

    final capacity = AppValidators.parseInteger(value)!;

    final registered = _viewModel.workshop?.registeredCount ?? 0;

    if (capacity < registered) {
      return 'Broj mjesta ne može biti manji od broja već prijavljenih učesnika ($registered).';
    }

    return null;
  }

  String? _validateDates() {
    final endError = AppValidators.endAfterStart(
      start: _startDateTime,
      end: _endDateTime,
      startName: 'Početak radionice',
      endName: 'Završetak radionice',
    );

    if (endError != null) {
      return endError;
    }

    if (!_startDateTime.isAfter(DateTime.now())) {
      return 'Početak radionice mora biti u budućnosti.';
    }

    final deadline = _registrationDeadline;

    if (deadline == null) {
      return 'Rok za prijavu je obavezan.';
    }

    if (!deadline.isAfter(DateTime.now())) {
      return 'Rok za prijavu mora biti u budućnosti.';
    }

    if (deadline.isAfter(_startDateTime)) {
      return 'Rok za prijavu ne može biti nakon početka radionice.';
    }

    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (_viewModel.isSaving) {
      return;
    }

    _viewModel.clearError();

    setState(() {
      _dateError = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final dateError = _validateDates();

    if (dateError != null) {
      setState(() {
        _dateError = dateError;
      });

      return;
    }

    final capacity = AppValidators.parseInteger(_capacityController.text);

    final price = AppValidators.parseDecimal(_priceController.text);

    if (capacity == null || price == null || _registrationDeadline == null) {
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
      imageUrl: _imageUrlController.text.trim().isEmpty
          ? null
          : _imageUrlController.text.trim(),
      registrationDeadlineUtc: _registrationDeadline!,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Radionica je uspješno izmijenjena.'
                : 'Radionica je uspješno kreirana.',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    if (_viewModel.isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Uredi radionicu' : 'Kreiraj radionicu'),
        ),
        body: const AppLoadingState(
          message: 'Učitavanje podataka radionice...',
        ),
      );
    }

    if (_viewModel.error != null && _viewModel.workshop == null && _isEditing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Uredi radionicu')),
        body: _buildInitialError(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Uredi radionicu' : 'Kreiraj radionicu'),
      ),
      body: AppLoadingOverlay(
        isLoading: _isBusy,
        message: _viewModel.isUploadingImage
            ? 'Učitavanje slike...'
            : 'Spremanje radionice...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _titleController,
                          enabled: !_isBusy,
                          maxLength: 150,
                          decoration: const InputDecoration(
                            labelText: 'Naziv',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => AppValidators.textLength(
                            value,
                            fieldName: 'Naziv',
                            minLength: 3,
                            maxLength: 150,
                          ),
                        ),

                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _descriptionController,
                          enabled: !_isBusy,
                          minLines: 5,
                          maxLines: 10,
                          maxLength: 2000,
                          decoration: const InputDecoration(
                            labelText: 'Opis',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          validator: (value) => AppValidators.textLength(
                            value,
                            fieldName: 'Opis',
                            minLength: 10,
                            maxLength: 2000,
                          ),
                        ),

                        const SizedBox(height: 16),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _imageUrlController.text.trim().isEmpty
                                        ? 'Naslovna slika nije učitana.'
                                        : 'Naslovna slika je učitana.',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: _isBusy
                                      ? null
                                      : _pickAndUploadImage,
                                  icon: const Icon(Icons.upload_file),
                                  label: Text(
                                    _imageUrlController.text.trim().isEmpty
                                        ? 'Učitaj sliku'
                                        : 'Zamijeni sliku',
                                  ),
                                ),
                              ],
                            ),
                            if (_imageUrlController.text.trim().isNotEmpty) ...[
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  _resolveImageUrl(_imageUrlController.text),
                                  height: 240,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 180,
                                      alignment: Alignment.center,
                                      child: const Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.broken_image_outlined,
                                            size: 48,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Pregled slike nije moguće učitati.',
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 16),

                        DropdownButtonFormField<int>(
                          initialValue: _type,
                          decoration: const InputDecoration(
                            labelText: 'Tip radionice',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('Online')),
                            DropdownMenuItem(value: 2, child: Text('Uživo')),
                          ],
                          onChanged: _isBusy
                              ? null
                              : (value) {
                                  if (value == null) {
                                    return;
                                  }

                                  _viewModel.clearError();

                                  setState(() {
                                    _type = value;
                                  });

                                  _formKey.currentState?.validate();
                                },
                        ),

                        const SizedBox(height: 12),

                        if (_type == 1)
                          TextFormField(
                            controller: _onlineLinkController,
                            enabled: !_isBusy,
                            maxLength: 1000,
                            decoration: const InputDecoration(
                              labelText: 'Link za online radionicu',
                              hintText: 'https://...',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.link),
                            ),
                            validator: (value) => AppValidators.httpUrl(
                              value,
                              fieldName: 'Online link',
                              required: true,
                              maxLength: 1000,
                            ),
                          ),

                        if (_type == 2)
                          TextFormField(
                            controller: _locationController,
                            enabled: !_isBusy,
                            maxLength: 300,
                            decoration: const InputDecoration(
                              labelText: 'Lokacija',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                            validator: (value) => AppValidators.textLength(
                              value,
                              fieldName: 'Lokacija',
                              maxLength: 300,
                            ),
                          ),

                        const SizedBox(height: 12),

                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _isBusy ? null : _selectStartDate,
                              icon: const Icon(Icons.event_available),
                              label: Text(
                                'Početak: ${formatter.format(_startDateTime)}',
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _isBusy ? null : _selectEndDate,
                              icon: const Icon(Icons.event_busy),
                              label: Text(
                                'Završetak: ${formatter.format(_endDateTime)}',
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        InkWell(
                          onTap: _isBusy ? null : _pickRegistrationDeadline,
                          borderRadius: BorderRadius.circular(8),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Rok za prijavu',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.event_busy),
                            ),
                            child: Text(
                              _registrationDeadline == null
                                  ? 'Odaberite rok za prijavu'
                                  : formatter.format(_registrationDeadline!),
                            ),
                          ),
                        ),

                        if (_dateError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _dateError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _capacityController,
                                enabled: !_isBusy,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Broj mjesta',
                                  border: OutlineInputBorder(),
                                ),
                                validator: _validateCapacity,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _priceController,
                                enabled: !_isBusy,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Cijena',
                                  suffixText: 'KM',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) => AppValidators.price(
                                  value,
                                  fieldName: 'Cijena',
                                  allowZero: true,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        DropdownButtonFormField<int?>(
                          initialValue: _therapistId,
                          decoration: const InputDecoration(
                            labelText: 'Terapeut',
                            helperText:
                                'Opcionalno. Ostavite prazno ako radionicu organizuje administrator.',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Bez dodijeljenog terapeuta'),
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
                          onChanged: _isBusy
                              ? null
                              : (value) {
                                  _viewModel.clearError();

                                  setState(() {
                                    _therapistId = value;
                                  });
                                },
                        ),

                        if (_viewModel.error != null) ...[
                          const SizedBox(height: 16),
                          AppErrorBanner(
                            message: _viewModel.error!,
                            onDismiss: _viewModel.clearError,
                          ),
                        ],

                        const SizedBox(height: 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _isBusy
                                  ? null
                                  : () {
                                      Navigator.of(context).pop(false);
                                    },
                              child: const Text('Odustani'),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed: _isBusy ? null : _save,
                              icon: const Icon(Icons.save_outlined),
                              label: Text(
                                _isEditing
                                    ? 'Spremi izmjene'
                                    : 'Kreiraj radionicu',
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
      ),
    );
  }

  Widget _buildInitialError() {
    return AppErrorPanel(
      message: _viewModel.error ?? 'Radionicu nije moguće učitati.',
      onRetry: () {
        _viewModel.initialize(widget.workshopId);
      },
    );
  }
}
