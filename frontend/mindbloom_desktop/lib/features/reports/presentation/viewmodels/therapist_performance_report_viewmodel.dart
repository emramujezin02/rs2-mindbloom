import 'package:flutter/foundation.dart';

import '../../data/models/report_therapist_option_model.dart';
import '../../data/models/therapist_performance_report_model.dart';
import '../../data/repositories/admin_report_repository.dart';
import '../../data/services/therapist_performance_pdf_service.dart';

class TherapistPerformanceReportViewModel extends ChangeNotifier {
  final AdminReportRepository _repository;
  final TherapistPerformancePdfService _pdfService;

  TherapistPerformanceReportViewModel(this._repository, this._pdfService);

  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);

  DateTime _toDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  TherapistPerformanceReportModel? _report;
  Uint8List? _pdfBytes;

  List<ReportTherapistOptionModel> _therapistOptions = const [];

  int? _selectedTherapistId;
  int _minimumAppointments = 0;
  String? _selectedTherapistStatus;

  bool _isLoading = false;
  bool _isLoadingTherapists = false;
  bool _isGeneratingPdf = false;
  bool _isSavingPdf = false;
  bool _isPrintingPdf = false;

  String? _errorMessage;

  DateTime get fromDate => _fromDate;

  DateTime get toDate => _toDate;

  TherapistPerformanceReportModel? get report => _report;

  Uint8List? get pdfBytes => _pdfBytes;

  List<ReportTherapistOptionModel> get therapistOptions => _therapistOptions;

  int? get selectedTherapistId => _selectedTherapistId;

  int get minimumAppointments => _minimumAppointments;

  String? get selectedTherapistStatus => _selectedTherapistStatus;

  bool get isLoading => _isLoading;

  bool get isLoadingTherapists => _isLoadingTherapists;

  bool get isGeneratingPdf => _isGeneratingPdf;

  bool get isSavingPdf => _isSavingPdf;

  bool get isPrintingPdf => _isPrintingPdf;

  bool get isBusy =>
      _isLoading || _isGeneratingPdf || _isSavingPdf || _isPrintingPdf;

  String? get errorMessage => _errorMessage;

  bool get hasReportData => _report != null && _report!.therapists.isNotEmpty;

  Future<void> loadTherapistOptions() async {
    if (_isLoadingTherapists) {
      return;
    }

    _isLoadingTherapists = true;
    notifyListeners();

    try {
      _therapistOptions = await _repository.getTherapists();
    } catch (error) {
      _errorMessage = _readableError(error);
    } finally {
      _isLoadingTherapists = false;
      notifyListeners();
    }
  }

  void setFromDate(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);

    if (_fromDate == normalized) {
      return;
    }

    _fromDate = normalized;
    _clearGeneratedResult();

    notifyListeners();
  }

  void setToDate(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);

    if (_toDate == normalized) {
      return;
    }

    _toDate = normalized;
    _clearGeneratedResult();

    notifyListeners();
  }

  void setSelectedTherapistId(int? therapistId) {
    if (_selectedTherapistId == therapistId) {
      return;
    }

    _selectedTherapistId = therapistId;

    _clearGeneratedResult();

    notifyListeners();
  }

  void setMinimumAppointments(int value) {
    if (_minimumAppointments == value) {
      return;
    }

    _minimumAppointments = value;

    _clearGeneratedResult();

    notifyListeners();
  }

  void setTherapistStatus(String? value) {
    final normalized = value?.trim();

    final newValue = normalized == null || normalized.isEmpty
        ? null
        : normalized;

    if (_selectedTherapistStatus == newValue) {
      return;
    }

    _selectedTherapistStatus = newValue;

    _clearGeneratedResult();

    notifyListeners();
  }

  Future<bool> loadReport() async {
    final validationMessage = _validateFilters();

    if (validationMessage != null) {
      _errorMessage = validationMessage;

      notifyListeners();

      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _report = null;
    _pdfBytes = null;

    notifyListeners();

    try {
      final fromUtc = DateTime.utc(
        _fromDate.year,
        _fromDate.month,
        _fromDate.day,
      );

      final toUtc = DateTime.utc(
        _toDate.year,
        _toDate.month,
        _toDate.day,
        23,
        59,
        59,
        999,
      );

      final loadedReport = await _repository.getTherapistPerformanceReport(
        fromUtc: fromUtc,
        toUtc: toUtc,
        therapistId: _selectedTherapistId,
        minimumAppointments: _minimumAppointments,
        therapistStatus: _selectedTherapistStatus,
      );

      _report = loadedReport;

      await _generatePdf(loadedReport);

      return true;
    } catch (error) {
      _errorMessage = _readableError(error);

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> savePdf() async {
    final currentReport = _report;
    final currentPdfBytes = _pdfBytes;

    if (currentReport == null || currentPdfBytes == null) {
      _errorMessage = 'Generate the report before saving the PDF.';

      notifyListeners();

      return false;
    }

    _isSavingPdf = true;
    _errorMessage = null;

    notifyListeners();

    try {
      return await _pdfService.savePdf(
        bytes: currentPdfBytes,
        report: currentReport,
      );
    } catch (error) {
      _errorMessage = _readableError(error);

      return false;
    } finally {
      _isSavingPdf = false;
      notifyListeners();
    }
  }

  Future<bool> printPdf() async {
    final currentReport = _report;
    final currentPdfBytes = _pdfBytes;

    if (currentReport == null || currentPdfBytes == null) {
      _errorMessage = 'Generate the report before printing.';

      notifyListeners();

      return false;
    }

    _isPrintingPdf = true;
    _errorMessage = null;

    notifyListeners();

    try {
      return await _pdfService.printPdf(
        bytes: currentPdfBytes,
        report: currentReport,
      );
    } catch (error) {
      _errorMessage = _readableError(error);

      return false;
    } finally {
      _isPrintingPdf = false;
      notifyListeners();
    }
  }

  Future<void> _generatePdf(TherapistPerformanceReportModel report) async {
    _isGeneratingPdf = true;
    _errorMessage = null;

    notifyListeners();

    try {
      _pdfBytes = await _pdfService.generatePdf(report: report);
    } catch (error) {
      _pdfBytes = null;
      _errorMessage = _readableError(error);
    } finally {
      _isGeneratingPdf = false;
      notifyListeners();
    }
  }

  String? _validateFilters() {
    if (_fromDate.isAfter(_toDate)) {
      return 'Start date cannot be later than end date.';
    }

    final difference = _toDate.difference(_fromDate);

    if (difference.inDays > 366 * 5) {
      return 'Report period cannot be longer than five years.';
    }

    if (_minimumAppointments < 0) {
      return 'Minimum appointments cannot be negative.';
    }

    return null;
  }

  void _clearGeneratedResult() {
    _report = null;
    _pdfBytes = null;
    _errorMessage = null;
  }

  String _readableError(Object error) {
    final text = error.toString();

    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }

    if (text.startsWith('FormatException: ')) {
      return text.substring('FormatException: '.length);
    }

    return text;
  }
}
