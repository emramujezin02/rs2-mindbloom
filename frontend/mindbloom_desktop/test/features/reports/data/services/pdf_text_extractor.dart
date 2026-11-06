import 'dart:convert';
import 'dart:io';

/// Test-only decoder for the pdf package's content streams and bfchar CMaps.
/// This is not a general PDF parser; independent PDFium QA verifies rendering.
String extractReportPdfText(List<int> bytes) {
  final source = latin1.decode(bytes);
  final objects = <int, String>{
    for (final match in RegExp(
      r'(\d+) 0 obj\b([\s\S]*?)endobj',
    ).allMatches(source))
      int.parse(match[1]!): match[2]!,
  };
  String stream(String object) {
    final match = RegExp(
      r'stream\r?\n([\s\S]*?)\r?\nendstream',
    ).firstMatch(object);
    if (match == null) return '';
    final data = latin1.encode(match[1]!);
    return latin1.decode(
      object.contains('/FlateDecode') ? ZLibDecoder().convert(data) : data,
    );
  }

  final fontMaps = <int, Map<int, String>>{};
  for (final entry in objects.entries) {
    final reference = RegExp(r'/ToUnicode\s+(\d+) 0 R').firstMatch(entry.value);
    if (reference == null) continue;
    final cmap = stream(objects[int.parse(reference[1]!)]!);
    final map = <int, String>{};
    for (final block in RegExp(
      r'beginbfchar([\s\S]*?)endbfchar',
    ).allMatches(cmap)) {
      for (final pair in RegExp(
        r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>',
      ).allMatches(block[1]!)) {
        final hex = pair[2]!;
        map[int.parse(pair[1]!, radix: 16)] = String.fromCharCodes([
          for (var i = 0; i < hex.length; i += 4)
            int.parse(hex.substring(i, i + 4), radix: 16),
        ]);
      }
    }
    fontMaps[entry.key] = map;
  }
  final fonts = <String, Map<int, String>>{};
  for (final ref in RegExp(r'/(F\d+)\s+(\d+) 0 R').allMatches(source)) {
    final map = fontMaps[int.parse(ref[2]!)];
    if (map != null) fonts[ref[1]!] = map;
  }

  final text = StringBuffer();
  final contentIds = RegExp(
    r'/Contents\s*(?:\[\s*)?(\d+)\s+0 R',
  ).allMatches(source).map((match) => int.parse(match[1]!)).toSet();
  for (final id in contentIds) {
    final object = objects[id]!;
    final content = stream(object);
    if (!content.contains('BT')) continue;
    Map<int, String>? activeFont;
    final tokens = RegExp(
      r'/(F\d+)\s+[\d.]+\s+Tf|<([0-9A-Fa-f]+)>|\(((?:\\.|[^()\\])*)\)',
    );
    for (final token in tokens.allMatches(content)) {
      if (token[1] != null) {
        activeFont = fonts[token[1]!];
      } else if (token[2] != null) {
        final hex = token[2]!;
        final step = activeFont == null ? 2 : 4;
        for (var i = 0; i + step <= hex.length; i += step) {
          final code = int.parse(hex.substring(i, i + step), radix: 16);
          text.write(
            activeFont == null
                ? String.fromCharCode(code)
                : activeFont[code] ?? '\uFFFD',
          );
        }
      } else {
        text.write(token[3]);
      }
    }
  }
  return text.toString();
}
