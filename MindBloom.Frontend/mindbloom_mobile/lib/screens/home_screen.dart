import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'MindBloom Mobile',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
