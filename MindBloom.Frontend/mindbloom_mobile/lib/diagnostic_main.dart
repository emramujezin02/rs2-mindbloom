import 'package:flutter/material.dart';

void main() {
  final startedAt = DateTime.now().toIso8601String();
  debugPrint('[DIAGNOSTIC] main entered at $startedAt');

  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    debugPrint(
      '[DIAGNOSTIC] first frame rendered at ${DateTime.now().toIso8601String()}',
    );
  });

  runApp(const DiagnosticApp());
}

class DiagnosticApp extends StatelessWidget {
  const DiagnosticApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('[DIAGNOSTIC] build called at ${DateTime.now().toIso8601String()}');

    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'MINDBLOOM FLUTTER ENGINE WORKS',
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
    );
  }
}
