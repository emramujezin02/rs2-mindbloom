import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/error/app_exception.dart';
import '../../data/repositories/therapist_repository.dart';
import '../../data/models/therapist_document_model.dart';
import '../../data/models/therapist_profile_model.dart';

class TherapistVerificationViewModel extends ChangeNotifier {
  final TherapistRepository repository;
  TherapistVerificationViewModel({required this.repository});
  TherapistProfileModel? profile;
  List<TherapistDocumentModel> documents = [];
  XFile? selectedFile;
  String? contentType, error, success;
  bool isLoading = false,
      isUploading = false,
      isSelecting = false,
      hasNextPage = false;
  int _page = 1;
  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool get canUpload =>
      ['Pending', 'RequiresChanges'].contains(profile?.verificationStatus);
  String get statusLabel => switch (profile?.verificationStatus) {
    'Pending' => 'Čeka verifikaciju',
    'Approved' => 'Odobren',
    'Rejected' => 'Odbijen – odluka je konačna',
    'RequiresChanges' => 'Potrebna dopuna dokumentacije',
    _ => 'Status nije dostupan',
  };

  Future<void> load({bool nextPage = false}) async {
    if (isLoading || isUploading) return;
    isLoading = true;
    error = null;
    _notify();
    try {
      profile = await repository.getTherapistProfile();
      final page = await repository.getMyDocuments(
        pageNumber: nextPage ? _page + 1 : 1,
      );
      documents = nextPage ? [...documents, ...page.items] : page.items;
      _page = page.pageNumber;
      hasNextPage = page.hasNextPage;
    } catch (_) {
      error = 'Verifikaciju nije moguće učitati. Pokušajte ponovo.';
    } finally {
      isLoading = false;
      _notify();
    }
  }

  Future<void> selectFile(XFile file) async {
    if (isUploading || isSelecting) return;
    isSelecting = true;
    selectedFile = null;
    contentType = null;
    error = null;
    success = null;
    _notify();
    try {
      final size = await file.length();
      if (size == 0 || size > 10 * 1024 * 1024) {
        throw const FormatException(
          'Odaberite dokument veličine do 10 MB koji nije prazan.',
        );
      }
      final extension = file.name.split('.').last.toLowerCase();
      final types = {
        'pdf': 'application/pdf',
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
      };
      if (!types.containsKey(extension)) {
        throw const FormatException(
          'Dozvoljeni su PDF, JPG, JPEG i PNG dokumenti.',
        );
      }
      final header = await file
          .openRead(0, size < 8 ? size : 8)
          .expand((chunk) => chunk)
          .toList();
      final pdf =
          header.length >= 5 &&
          listEquals(header.take(5).toList(), [37, 80, 68, 70, 45]);
      final jpeg =
          header.length >= 3 &&
          listEquals(header.take(3).toList(), [255, 216, 255]);
      final png =
          header.length >= 8 &&
          listEquals(header, [137, 80, 78, 71, 13, 10, 26, 10]);
      if (!(extension == 'pdf'
          ? pdf
          : extension == 'png'
          ? png
          : jpeg)) {
        throw const FormatException(
          'Sadržaj dokumenta ne odgovara odabranom tipu fajla.',
        );
      }
      selectedFile = file;
      contentType = types[extension];
    } on FormatException catch (exception) {
      error = exception.message;
    } catch (_) {
      error = 'Dokument nije moguće pročitati.';
    } finally {
      isSelecting = false;
      _notify();
    }
  }

  Future<void> upload() async {
    if (isUploading ||
        isSelecting ||
        !canUpload ||
        selectedFile == null ||
        contentType == null) {
      return;
    }
    isUploading = true;
    error = null;
    success = null;
    _notify();
    try {
      await repository.uploadVerificationDocument(
        selectedFile!.path,
        contentType!,
      );
      selectedFile = null;
      success =
          'Dokument je uspješno poslan. Zahtjev čeka pregled administratora.';
      profile = await repository.getTherapistProfile();
      final page = await repository.getMyDocuments();
      documents = page.items;
      _page = page.pageNumber;
      hasNextPage = page.hasNextPage;
    } on AppException catch (exception) {
      error = exception.message;
    } catch (_) {
      error =
          'Dokument nije poslan ili status nije osvježen. Provjerite listu prije ponovnog slanja.';
    } finally {
      isUploading = false;
      _notify();
    }
  }
}
