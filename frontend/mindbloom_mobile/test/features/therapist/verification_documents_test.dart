import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_mobile/core/error/app_exception.dart';
import 'package:mindbloom_mobile/core/network/api_client.dart';
import 'package:mindbloom_mobile/features/therapist/data/repositories/therapist_repository.dart';
import 'package:mindbloom_mobile/features/therapist/data/services/therapist_api_service.dart';
import 'package:mindbloom_mobile/features/therapist/presentation/pages/therapist_verification_page.dart';
import 'package:mindbloom_mobile/features/therapist/presentation/viewmodels/therapist_verification_viewmodel.dart';
import 'package:mindbloom_mobile/services/session_storage_service.dart';

void main() {
  for (final status in [
    'Pending',
    'Approved',
    'Rejected',
    'RequiresChanges',
    'unknown',
  ]) {
    testWidgets(
      'backend status $status controls upload and is displayed truthfully',
      (tester) async {
        final api = _Api(status: status);
        final model = _model(api);
        await tester.pumpWidget(
          MaterialApp(home: TherapistVerificationPage(viewModel: model)),
        );
        await tester.pumpAndSettle();
        expect(find.text(model.statusLabel), findsOneWidget);
        expect(find.text('Upload additional proof.'), findsOneWidget);
        expect(
          find.text('Odaberi dokument'),
          ['Pending', 'RequiresChanges'].contains(status)
              ? findsOneWidget
              : findsNothing,
        );
        expect(find.text('Još nema poslanih dokumenata.'), findsOneWidget);
        expect(api.uploads, 0);
      },
    );
  }

  testWidgets(
    'pending therapist can select a document and upload with confirmation',
    (tester) async {
      final api = _Api(status: 'RequiresChanges');
      final model = _model(api);
      await tester.pumpWidget(
        MaterialApp(
          home: TherapistVerificationPage(
            viewModel: model,
            pickFile: () async => _pdf(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Odaberi dokument'));
      await tester.pumpAndSettle();
      expect(find.text('synthetic.pdf'), findsOneWidget);
      await tester.ensureVisible(find.text('Pošalji dokument'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pošalji dokument'));
      await tester.pumpAndSettle();
      expect(api.uploads, 1);
      expect(find.text('Čeka verifikaciju'), findsOneWidget);
      expect(
        find.textContaining('Dokument je uspješno poslan.'),
        findsOneWidget,
      );
      expect(find.text('synthetic.pdf'), findsOneWidget);
      expect(find.text('Dokument čeka pregled'), findsOneWidget);
    },
  );

  for (final name in ['invalid.exe', 'empty.pdf', 'wrong.pdf', 'wrong.png']) {
    test('rejects $name before sending upload', () async {
      final api = _Api();
      final model = _model(api);
      addTearDown(model.dispose);
      await model.load();
      await model.selectFile(
        XFile.fromData(
          Uint8List.fromList(name == 'empty.pdf' ? [] : 'invalid'.codeUnits),
          name: name,
          path: name,
        ),
      );
      expect(model.selectedFile, isNull);
      expect(model.error, isNotNull);
      await model.upload();
      expect(api.uploads, 0);
    });
  }

  test('rejects a document larger than 10 MB', () async {
    final model = _model(_Api());
    addTearDown(model.dispose);
    final directory = await Directory.systemTemp.createTemp(
      'mindbloom-size-test-',
    );
    final file = File('${directory.path}/large.pdf');
    try {
      await file.writeAsBytes(Uint8List(10 * 1024 * 1024 + 1));
      await model.selectFile(XFile(file.path));
      expect(model.selectedFile, isNull);
      expect(model.error, contains('10 MB'));
    } finally {
      await file.delete();
      await directory.delete();
    }
  });

  test(
    'accepts PDF PNG JPG and JPEG signatures with matching MIME type',
    () async {
      final model = _model(_Api());
      addTearDown(model.dispose);
      for (final entry in <String, List<int>>{
        'synthetic.pdf': '%PDF-1.4 synthetic'.codeUnits,
        'synthetic.png': [137, 80, 78, 71, 13, 10, 26, 10],
        'synthetic.jpg': [255, 216, 255],
        'synthetic.jpeg': [255, 216, 255],
      }.entries) {
        await model.selectFile(
          XFile.fromData(
            Uint8List.fromList(entry.value),
            name: entry.key,
            path: entry.key,
          ),
        );
        expect(model.selectedFile, isNotNull);
        expect(model.error, isNull);
        expect(
          model.contentType,
          entry.key.endsWith('.pdf')
              ? 'application/pdf'
              : entry.key.endsWith('.png')
              ? 'image/png'
              : 'image/jpeg',
        );
      }
    },
  );

  test(
    'upload error is shown and an active upload cannot be duplicated',
    () async {
      final pending = Completer<void>();
      final api = _Api(pending: pending.future, fail: true);
      final model = _model(api);
      addTearDown(model.dispose);
      await model.load();
      await model.selectFile(_pdf());
      final first = model.upload();
      await model.upload();
      expect(api.uploads, 1);
      expect(model.isUploading, isTrue);
      pending.complete();
      await first;
      expect(model.isUploading, isFalse);
      expect(model.error, 'Synthetic upload error');
      expect(model.success, isNull);
    },
  );

  test(
    'document pagination loads next page without losing existing entries',
    () async {
      final api = _Api(paged: true);
      final model = _model(api);
      addTearDown(model.dispose);
      await model.load();
      expect(model.documents, hasLength(1));
      expect(model.hasNextPage, isTrue);
      await model.load(nextPage: true);
      expect(model.documents.map((document) => document.id), [1, 2]);
      expect(model.hasNextPage, isFalse);
    },
  );

  testWidgets(
    'load failure is visible without pretending verification was approved',
    (tester) async {
      final model = _model(_Api(failLoad: true));
      await tester.pumpWidget(
        MaterialApp(home: TherapistVerificationPage(viewModel: model)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Status nije dostupan'), findsOneWidget);
      expect(
        find.textContaining('Verifikaciju nije moguće učitati.'),
        findsOneWidget,
      );
      expect(find.text('Odaberi dokument'), findsNothing);
    },
  );
}

XFile _pdf() => XFile.fromData(
  Uint8List.fromList('%PDF-1.4 synthetic'.codeUnits),
  name: 'synthetic.pdf',
  path: 'synthetic.pdf',
);
TherapistVerificationViewModel _model(_Api api) =>
    TherapistVerificationViewModel(
      repository: TherapistRepository(
        therapistApiService: TherapistApiService(apiClient: api),
      ),
    );

class _Api extends ApiClient {
  String status;
  final bool fail, paged, failLoad;
  final Future<void>? pending;
  int uploads = 0;
  _Api({
    this.status = 'Pending',
    this.fail = false,
    this.paged = false,
    this.failLoad = false,
    this.pending,
  }) : super(sessionStorage: SessionStorageService());
  @override
  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    expect(requiresAuth, isTrue);
    if (failLoad) {
      throw const AppException(message: 'Cannot load', statusCode: 500);
    }
    if (endpoint == '/Therapists/profile') {
      return <String, dynamic>{
        'therapistId': 1,
        'userId': 2,
        'verificationStatus': status,
        'verificationNotes': 'Upload additional proof.',
      };
    }
    expect(endpoint, startsWith('/Therapists/documents/me?'));
    final page = int.parse(Uri.parse(endpoint).queryParameters['pageNumber']!);
    return <String, dynamic>{
      'items': uploads > 0 || paged
          ? [
              {
                'id': page,
                'fileName': 'synthetic.pdf',
                'contentType': 'application/pdf',
                'isApproved': false,
              },
            ]
          : [],
      'pageNumber': page,
      'pageSize': 10,
      'totalCount': paged ? 2 : uploads,
      'totalPages': paged ? 2 : 1,
      'hasNextPage': paged && page == 1,
    };
  }

  @override
  Future<dynamic> multipartPost(
    String endpoint, {
    required String filePath,
    String fileFieldName = 'file',
    String? contentType,
    bool requiresAuth = true,
  }) async {
    uploads++;
    expect(endpoint, '/Therapists/documents');
    expect(fileFieldName, 'File');
    expect(contentType, 'application/pdf');
    expect(requiresAuth, isTrue);
    if (pending != null) await pending;
    if (fail) {
      throw const AppException(
        message: 'Synthetic upload error',
        statusCode: 400,
      );
    }
    status = 'Pending';
    return <String, dynamic>{'message': 'Document uploaded successfully.'};
  }
}
