import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// Bundled fonts keep PDF reports Unicode-capable without network access.
abstract final class ReportPdfFonts {
  static Future<({ByteData regular, ByteData bold})>? _fontData;

  static Future<({ByteData regular, ByteData bold})> _loadData() async {
    final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    return (regular: regular, bold: bold);
  }

  static Future<pw.ThemeData> loadTheme() async {
    final data = await (_fontData ??= _loadData());
    // Font instances belong to a PDF document; only immutable bytes are shared.
    final regular = pw.Font.ttf(data.regular);
    final bold = pw.Font.ttf(data.bold);
    return pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: regular,
      boldItalic: bold,
    );
  }
}
