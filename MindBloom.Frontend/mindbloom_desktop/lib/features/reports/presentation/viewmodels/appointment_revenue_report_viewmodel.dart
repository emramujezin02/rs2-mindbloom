// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';
import 'package:mindbloom_desktop/features/reports/data/services/appointment_revenue_pdf_service.dart';

import '../../data/models/appointment_revenue_report_model.dart';
import '../../data/repositories/admin_report_repository.dart';

class AppointmentRevenueReportViewModel extends ChangeNotifier {
  final AdminReportRepository _repository;
  final AppointmentRevenuePdfService _pdfService;

  AppointmentRevenueReportViewModel({
    required AdminReportRepository repository,
    required AppointmentRevenuePdfService pdfService,
  }) : _repository = repository,
       _pdfService = pdfService;

  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);

  DateTime _toDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  AppointmentRevenueReportModel? _report;
  Uint8List? _pdfBytes;

  bool _isLoading = false;
  bool _isGeneratingPdf = false;
  bool _isSavingPdf = false;
  bool _isPrintingPdf = false;

  String? _errorMessage;

  DateTime get fromDate => _fromDate;

  DateTime get toDate => _toDate;

  AppointmentRevenueReportModel? get report => _report;

  Uint8List? get pdfBytes => _pdfBytes;

  bool get isLoading => _isLoading;

  bool get isGeneratingPdf => _isGeneratingPdf;

  bool get isSavingPdf => _isSavingPdf;

  bool get isPrintingPdf => _isPrintingPdf;

  bool get isBusy =>
      _isLoading || _isGeneratingPdf || _isSavingPdf || _isPrintingPdf;

  String? get errorMessage => _errorMessage;

  bool get hasReport => _report != null;

  void setFromDate(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);

    if (_fromDate == normalized) {
      return;
    }

    _fromDate = normalized;
    _clearGeneratedReport();

    notifyListeners();
  }

  void setToDate(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);

    if (_toDate == normalized) {
      return;
    }

    _toDate = normalized;
    _clearGeneratedReport();

    notifyListeners();
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

      final loadedReport = await _repository.getAppointmentRevenueReport(
        fromUtc: fromUtc,
        toUtc: toUtc,
      );

      _report = loadedReport;

      await _generatePdfInternal(loadedReport);

      return true;
    } catch (error) {
      _errorMessage = _readableError(error);

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> regeneratePdf() async {
    final currentReport = _report;

    if (currentReport == null) {
      _errorMessage = 'Load the report before generating the PDF.';
      notifyListeners();

      return false;
    }

    _isGeneratingPdf = true;
    _errorMessage = null;

    notifyListeners();

    try {
      await _generatePdfInternal(currentReport);

      return true;
    } catch (error) {
      _errorMessage = _readableError(error);

      return false;
    } finally {
      _isGeneratingPdf = false;
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

  Future<void> _generatePdfInternal(
    AppointmentRevenueReportModel report,
  ) async {
    _pdfBytes = await _pdfService.generatePdf(report);
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

  void _clearGeneratedReport() {
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
