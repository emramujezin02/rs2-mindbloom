import 'package:flutter/material.dart';
import '../../../../app/di/injection.dart';
import '../../data/models/therapist_specialization_model.dart';
import '../../data/services/therapist_api_service.dart';

class TherapistSpecializationDropdown extends StatefulWidget {
  final int? value;
  final String existingName;
  final bool enabled, requiredSelection;
  final ValueChanged<int?> onChanged;
  final TherapistApiService? service;
  const TherapistSpecializationDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.existingName = '',
    this.enabled = true,
    this.requiredSelection = false,
    this.service,
  });
  @override
  State<TherapistSpecializationDropdown> createState() =>
      _TherapistSpecializationDropdownState();
}

class _TherapistSpecializationDropdownState
    extends State<TherapistSpecializationDropdown> {
  List<TherapistSpecializationModel> _items = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items =
          await (widget.service ??
                  TherapistApiService(apiClient: AppInjection.apiClient))
              .getActiveSpecializations();
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Specijalizacije nije moguće učitati.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing =
        widget.value != null && !_items.any((x) => x.id == widget.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loading) const LinearProgressIndicator(),
        DropdownButtonFormField<int>(
          key: ValueKey('specialization-${widget.value}-${_items.length}'),
          initialValue: widget.value,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Specijalizacija',
            border: OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem<int>(
              enabled: widget.value == null,
              child: const Text('Odaberite specijalizaciju'),
            ),
            if (existing)
              DropdownMenuItem(
                value: widget.value,
                enabled: false,
                child: Text(
                  '${widget.existingName} (raniji izbor)',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ..._items.map(
              (x) => DropdownMenuItem(
                value: x.id,
                child: Text(x.name, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: widget.enabled && !_loading
              ? (id) {
                  if (id != null) widget.onChanged(id);
                }
              : null,
          validator: (_) => widget.requiredSelection && widget.value == null
              ? 'Odaberite specijalizaciju.'
              : null,
        ),
        if (widget.value == null && widget.existingName.isNotEmpty)
          Text('Postojeća specijalizacija: ${widget.existingName}'),
        if (_error != null)
          TextButton(
            onPressed: _load,
            child: Text('$_error Pokušajte ponovo.'),
          ),
        if (!_loading && _error == null && _items.isEmpty)
          const Text('Nema aktivnih specijalizacija.'),
      ],
    );
  }
}
