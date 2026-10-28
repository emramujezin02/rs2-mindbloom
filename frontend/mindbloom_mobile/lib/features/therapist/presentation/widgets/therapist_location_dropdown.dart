import 'package:flutter/material.dart';
import '../../../../app/di/injection.dart';
import '../../data/models/therapist_location_model.dart';
import '../../data/services/therapist_api_service.dart';

class TherapistLocationDropdown extends StatefulWidget {
  final int? value;
  final TherapistLocationModel? existingLocation;
  final ValueChanged<TherapistLocationModel?> onChanged;
  final bool requiredSelection, enabled;
  final TherapistApiService? service;
  const TherapistLocationDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.existingLocation,
    this.requiredSelection = false,
    this.enabled = true,
    this.service,
  });
  @override
  State<TherapistLocationDropdown> createState() =>
      _TherapistLocationDropdownState();
}

class _TherapistLocationDropdownState extends State<TherapistLocationDropdown> {
  late final _service =
      widget.service ?? TherapistApiService(apiClient: AppInjection.apiClient);
  final List<TherapistLocationModel> _items = [];
  bool _loading = false, _hasNext = false;
  int _page = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _service.getActiveLocations(pageNumber: _page + 1);
      if (!mounted) return;
      setState(() {
        for (final item in page.items) {
          if (!_items.any((x) => x.id == item.id)) _items.add(item);
        }
        _page = page.pageNumber;
        _hasNext = page.hasNextPage;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Lokacije nije moguće učitati.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [..._items];
    final existing = widget.existingLocation;
    if (existing != null &&
        existing.id == widget.value &&
        !items.any((x) => x.id == existing.id)) {
      items.add(existing);
    }
    final selected = items.any((x) => x.id == widget.value)
        ? widget.value
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loading) const LinearProgressIndicator(),
        DropdownButtonFormField<int>(
          key: ValueKey('location-${widget.value}-${items.length}-$_loading'),
          initialValue: selected,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Lokacija',
            border: OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem<int>(
              child: Text(
                widget.requiredSelection
                    ? 'Odaberite lokaciju'
                    : 'Sve lokacije',
              ),
            ),
            ...items.map(
              (x) => DropdownMenuItem(
                value: x.id,
                child: Text(x.displayName, overflow: TextOverflow.ellipsis),
              ),
            ),
            if (_hasNext)
              const DropdownMenuItem(
                value: -1,
                child: Text('Učitaj još lokacija…'),
              ),
          ],
          onChanged: !widget.enabled || _loading
              ? null
              : (id) {
                  if (id == -1) {
                    _load();
                    return;
                  }
                  widget.onChanged(
                    id == null ? null : items.firstWhere((x) => x.id == id),
                  );
                },
          validator: (_) => widget.requiredSelection && widget.value == null
              ? 'Odaberite lokaciju.'
              : null,
        ),
        if (_error != null)
          TextButton(
            onPressed: _loading ? null : _load,
            child: Text('$_error Pokušajte ponovo.'),
          ),
        if (!_loading && _error == null && items.isEmpty)
          const Text('Nema aktivnih lokacija.'),
      ],
    );
  }
}
