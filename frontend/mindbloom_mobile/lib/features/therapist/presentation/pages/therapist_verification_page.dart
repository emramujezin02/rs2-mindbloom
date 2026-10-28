import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../../../../app/di/injection.dart';
import '../../data/repositories/therapist_repository.dart';
import '../../data/services/therapist_api_service.dart';
import '../viewmodels/therapist_verification_viewmodel.dart';

class TherapistVerificationPage extends StatefulWidget {
  final TherapistVerificationViewModel? viewModel;
  final Future<XFile?> Function()? pickFile;
  const TherapistVerificationPage({super.key, this.viewModel, this.pickFile});
  @override
  State<TherapistVerificationPage> createState() =>
      _TherapistVerificationPageState();
}

class _TherapistVerificationPageState extends State<TherapistVerificationPage> {
  late final TherapistVerificationViewModel _model;
  @override
  void initState() {
    super.initState();
    _model =
        widget.viewModel ??
        TherapistVerificationViewModel(
          repository: TherapistRepository(
            therapistApiService: TherapistApiService(
              apiClient: AppInjection.apiClient,
            ),
          ),
        );
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
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final file =
          await (widget.pickFile?.call() ??
              openFile(
                acceptedTypeGroups: [
                  const XTypeGroup(
                    label: 'Verifikacijski dokumenti',
                    extensions: ['pdf', 'jpg', 'jpeg', 'png'],
                    mimeTypes: ['application/pdf', 'image/jpeg', 'image/png'],
                    uniformTypeIdentifiers: [
                      'com.adobe.pdf',
                      'public.jpeg',
                      'public.png',
                    ],
                  ),
                ],
              ));
      if (file != null && mounted) await _model.selectFile(file);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Odabir dokumenta nije uspio.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Verifikacija psihoterapeuta'),
      actions: [
        IconButton(
          onPressed: _model.isLoading || _model.isUploading
              ? null
              : () => _model.load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(_model.statusLabel, style: Theme.of(context).textTheme.titleLarge),
        if (_model.profile?.verificationNotes?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_model.profile!.verificationNotes!),
          ),
        const SizedBox(height: 16),
        const Text(
          'Pošaljite dokumentaciju kojom potvrđujete stručne kvalifikacije. Dozvoljeni su PDF, JPG, JPEG i PNG fajlovi do 10 MB. Dokumenti su privatni i dostupni administratoru.',
        ),
        if (_model.isLoading || _model.isSelecting)
          const LinearProgressIndicator(),
        if (_model.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _model.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_model.success != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_model.success!),
          ),
        if (_model.canUpload) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed:
                _model.isLoading || _model.isUploading || _model.isSelecting
                ? null
                : _pick,
            icon: const Icon(Icons.attach_file),
            label: const Text('Odaberi dokument'),
          ),
          if (_model.selectedFile != null) Text(_model.selectedFile!.name),
          FilledButton(
            onPressed:
                _model.selectedFile == null ||
                    _model.isUploading ||
                    _model.isSelecting
                ? null
                : _model.upload,
            child: _model.isUploading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(),
                  )
                : const Text('Pošalji dokument'),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Poslani dokumenti',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (!_model.isLoading && _model.documents.isEmpty)
          const Text('Još nema poslanih dokumenata.'),
        ..._model.documents.map(
          (document) => ListTile(
            leading: const Icon(Icons.description),
            title: Text(document.fileName),
            subtitle: Text(
              document.isApproved
                  ? 'Odobren dokument'
                  : 'Dokument čeka pregled',
            ),
          ),
        ),
        if (_model.hasNextPage)
          TextButton(
            onPressed: _model.isLoading || _model.isUploading
                ? null
                : () => _model.load(nextPage: true),
            child: const Text('Učitaj još'),
          ),
      ],
    ),
  );
}
