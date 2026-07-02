import 'package:flutter/material.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5FB),
      body: SafeArea(
        child: Center(
          child: Text(
            'Journal coming soon',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ),
    );
  }
}
