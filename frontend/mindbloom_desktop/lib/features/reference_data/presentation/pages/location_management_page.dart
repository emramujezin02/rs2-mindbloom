import 'package:flutter/material.dart';
import '../../../../app/di/injection.dart';
import '../../../../core/widgets/admin_page_header.dart';
import '../../../../core/widgets/admin_table_container.dart';
import '../../../../core/widgets/app_table_pagination.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../../../core/widgets/app_responsive_dialog_content.dart';
import '../../data/models/therapist_location_model.dart';
import '../viewmodels/location_management_viewmodel.dart';

class LocationManagementPage extends StatefulWidget {
  final LocationManagementViewModel? viewModel;
  const LocationManagementPage({super.key, this.viewModel});
  @override
  State<LocationManagementPage> createState() => _LocationManagementPageState();
}

class _LocationManagementPageState extends State<LocationManagementPage> {
  late final LocationManagementViewModel _model;
  final _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    _model =
        widget.viewModel ?? AppInjection.createLocationManagementViewModel();
    _model.addListener(_changed);
    _model.load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _model.removeListener(_changed);
    _model.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _edit([TherapistLocationModel? location]) async {
    final result = await showDialog<_LocationFormResult>(
      context: context,
      builder: (_) => _LocationForm(location: location),
    );
    if (result == null || !mounted) return;
    await _model.save(
      id: location?.id,
      name: result.name,
      country: result.country,
      region: result.region,
      isActive: result.isActive,
    );
  }

  Future<void> _delete(TherapistLocationModel location) async {
    final confirmed = await AppConfirmationDialog.show(
      context,
      title: location.therapistCount > 0
          ? 'Deaktiviraj lokaciju'
          : 'Obriši lokaciju',
      message: location.therapistCount > 0
          ? 'Lokacija je povezana s terapeutima. Bit će deaktivirana, a postojeće veze ostaju sačuvane.'
          : 'Obrisati lokaciju ${location.name}?',
      destructive: true,
    );
    if (confirmed && mounted) await _model.delete(location.id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Šifarnik lokacija')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: 'Lokacije',
            subtitle: 'Gradovi i naselja za profile i pretragu terapeuta.',
            icon: Icons.location_city,
            trailing: FilledButton.icon(
              onPressed: _model.isLoading || _model.isSaving
                  ? null
                  : () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Dodaj lokaciju'),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    labelText: 'Pretraga lokacija',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) {
                    _model.search = _search.text.trim();
                    _model.load(page: 1);
                  },
                ),
              ),
              IconButton(
                onPressed: _model.isLoading || _model.isSaving
                    ? null
                    : () {
                        _model.search = _search.text.trim();
                        _model.load(page: 1);
                      },
                icon: const Icon(Icons.search),
              ),
              DropdownButton<bool>(
                value: _model.activeFilter,
                hint: const Text('Sve lokacije'),
                items: const [
                  DropdownMenuItem<bool>(child: Text('Sve lokacije')),
                  DropdownMenuItem(value: true, child: Text('Aktivne')),
                  DropdownMenuItem(value: false, child: Text('Neaktivne')),
                ],
                onChanged: _model.isLoading || _model.isSaving
                    ? null
                    : (value) {
                        _model.activeFilter = value;
                        _model.load(page: 1);
                      },
              ),
            ],
          ),
          if (_model.error != null) AppErrorBanner(message: _model.error!),
          if (_model.isLoading || _model.isSaving)
            const LinearProgressIndicator(),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: AdminTableContainer(
                minimumWidth: 850,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Naziv')),
                    DataColumn(label: Text('Država')),
                    DataColumn(label: Text('Regija/općina')),
                    DataColumn(label: Text('Aktivna')),
                    DataColumn(label: Text('Terapeuti')),
                    DataColumn(label: Text('Akcije')),
                  ],
                  rows: _model.items
                      .map(
                        (item) => DataRow(
                          cells: [
                            DataCell(Text(item.name)),
                            DataCell(Text(item.country)),
                            DataCell(Text(item.region)),
                            DataCell(Text(item.isActive ? 'Da' : 'Ne')),
                            DataCell(Text('${item.therapistCount}')),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Uredi',
                                    onPressed:
                                        _model.isSaving || _model.isLoading
                                        ? null
                                        : () => _edit(item),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: item.therapistCount > 0
                                        ? 'Deaktiviraj'
                                        : 'Obriši',
                                    onPressed:
                                        _model.isSaving || _model.isLoading
                                        ? null
                                        : () => _delete(item),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
          if (!_model.isLoading && _model.items.isEmpty)
            const Text('Nema lokacija za odabrane uslove.'),
          AdminTablePagination(
            pageNumber: _model.pageNumber,
            pageSize: _model.pageSize,
            totalCount: _model.totalCount,
            totalPages: _model.totalPages,
            isLoading: _model.isLoading || _model.isSaving,
            onPreviousPage: () => _model.load(page: _model.pageNumber - 1),
            onNextPage: () => _model.load(page: _model.pageNumber + 1),
            onPageSizeChanged: (size) {
              _model.pageSize = size;
              _model.load(page: 1);
            },
          ),
        ],
      ),
    ),
  );
}

class _LocationFormResult {
  final String name, country, region;
  final bool isActive;
  const _LocationFormResult(
    this.name,
    this.country,
    this.region,
    this.isActive,
  );
}

class _LocationForm extends StatefulWidget {
  final TherapistLocationModel? location;
  const _LocationForm({this.location});
  @override
  State<_LocationForm> createState() => _LocationFormState();
}

class _LocationFormState extends State<_LocationForm> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.location?.name ?? '');
  late final _country = TextEditingController(
    text: widget.location?.country ?? '',
  );
  late final _region = TextEditingController(
    text: widget.location?.region ?? '',
  );
  late bool _active = widget.location?.isActive ?? true;
  @override
  void dispose() {
    _name.dispose();
    _country.dispose();
    _region.dispose();
    super.dispose();
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool required = true,
  }) => TextFormField(
    controller: controller,
    decoration: InputDecoration(labelText: label),
    validator: (value) => required && (value?.trim().isEmpty ?? true)
        ? 'Polje je obavezno.'
        : (value?.trim().length ?? 0) > 100
        ? 'Najviše 100 znakova.'
        : null,
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.location == null ? 'Dodaj lokaciju' : 'Uredi lokaciju'),
    content: AppResponsiveDialogContent(
      preferredWidth: 480,
      child: Form(
        key: _key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field('Naziv', _name),
            _field('Država', _country),
            _field('Regija/općina (opciono)', _region, required: false),
            CheckboxListTile(
              title: const Text('Aktivna'),
              value: _active,
              onChanged: (value) => setState(() => _active = value ?? false),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Odustani'),
      ),
      FilledButton(
        onPressed: () {
          if (_key.currentState!.validate()) {
            Navigator.pop(
              context,
              _LocationFormResult(
                _name.text,
                _country.text,
                _region.text,
                _active,
              ),
            );
          }
        },
        child: const Text('Sačuvaj'),
      ),
    ],
  );
}
