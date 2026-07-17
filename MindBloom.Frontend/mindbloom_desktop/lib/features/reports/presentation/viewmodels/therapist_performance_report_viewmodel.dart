import 'package:flutter/foundation.dart';

import '../../data/models/therapist_performance_report_item_model.dart';
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
  int? _selectedTherapistId;

  bool _isLoading = false;
  bool _isGeneratingPdf = false;
  bool _isSavingPdf = false;
  bool _isPrintingPdf = false;

  String? _errorMessage;

  DateTime get fromDate => _fromDate;

  DateTime get toDate => _toDate;

  TherapistPerformanceReportModel? get report => _report;

  Uint8List? get pdfBytes => _pdfBytes;

  int? get selectedTherapistId => _selectedTherapistId;

  bool get isLoading => _isLoading;

  bool get isGeneratingPdf => _isGeneratingPdf;

  bool get isSavingPdf => _isSavingPdf;

  bool get isPrintingPdf => _isPrintingPdf;

  bool get isBusy =>
      _isLoading || _isGeneratingPdf || _isSavingPdf || _isPrintingPdf;

  String? get errorMessage => _errorMessage;

  List<TherapistPerformanceReportItemModel> get therapists {
    final items = [...?_report?.therapists];

    items.sort(
      (first, second) => first.therapistName.toLowerCase().compareTo(
        second.therapistName.toLowerCase(),
      ),
    );

    return items;
  }

  List<TherapistPerformanceReportItemModel> get visibleTherapists {
    final currentReport = _report;

    if (currentReport == null) {
      return const [];
    }

    if (_selectedTherapistId == null) {
      return currentReport.therapists;
    }

    final therapist = currentReport.therapistById(_selectedTherapistId!);

    return therapist == null ? const [] : [therapist];
  }

  TherapistPerformanceReportItemModel? get selectedTherapist {
    final currentReport = _report;
    final therapistId = _selectedTherapistId;

    if (currentReport == null || therapistId == null) {
      return null;
    }

    return currentReport.therapistById(therapistId);
  }

  int get displayedCompletedAppointments {
    final therapist = selectedTherapist;

    if (therapist != null) {
      return therapist.completedAppointments;
    }

    return visibleTherapists.fold<int>(
      0,
      (sum, item) => sum + item.completedAppointments,
    );
  }

  int get displayedUniqueClients {
    final therapist = selectedTherapist;

    if (therapist != null) {
      return therapist.uniqueClientsCount;
    }

    return _report?.totalUniqueClients ?? 0;
  }

  double get displayedGrossRevenue {
    return visibleTherapists.fold<double>(
      0,
      (sum, item) => sum + item.grossRevenue,
    );
  }

  double get displayedRefundedAmount {
    return visibleTherapists.fold<double>(
      0,
      (sum, item) => sum + item.refundedAmount,
    );
  }

  double get displayedNetRevenue {
    return visibleTherapists.fold<double>(
      0,
      (sum, item) => sum + item.netRevenue,
    );
  }

  void setFromDate(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);

    if (_fromDate == normalized) {
      return;
    }

    _fromDate = normalized;
    _clearReport();

    notifyListeners();
  }

  void setToDate(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);

    if (_toDate == normalized) {
      return;
    }

    _toDate = normalized;
    _clearReport();

    notifyListeners();
  }

  Future<void> setSelectedTherapistId(int? therapistId) async {
    if (_selectedTherapistId == therapistId) {
      return;
    }

    _selectedTherapistId = therapistId;
    _errorMessage = null;

    notifyListeners();

    final currentReport = _report;

    if (currentReport != null) {
      await _generatePdf(currentReport);
    }
  }

  Future<bool> loadReport() async {
    final validationMessage = _validatePeriod();

    if (validationMessage != null) {
      _errorMessage = validationMessage;
      notifyListeners();

      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _report = null;
    _pdfBytes = null;
    _selectedTherapistId = null;

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
        therapistId: _selectedTherapistId,
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
        therapistId: _selectedTherapistId,
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
      _pdfBytes = await _pdfService.generatePdf(
        report: report,
        therapistId: _selectedTherapistId,
      );
    } catch (error) {
      _pdfBytes = null;
      _errorMessage = _readableError(error);
    } finally {
      _isGeneratingPdf = false;
      notifyListeners();
    }
  }

  String? _validatePeriod() {
    if (_fromDate.isAfter(_toDate)) {
      return 'Start date cannot be later than end date.';
    }

    final difference = _toDate.difference(_fromDate);

    if (difference.inDays > 366 * 5) {
      return 'Report period cannot be longer than five years.';
    }

    return null;
  }

  void _clearReport() {
    _report = null;
    _pdfBytes = null;
    _selectedTherapistId = null;
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
