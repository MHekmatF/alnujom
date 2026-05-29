// Phase 18 (spec/018-reports-moderation) — MyReportsPage stub.
// Navigated to from Profile "My Reports" tile via /reports (T003/T007).
// Full implementation in Phase 8 (Sub-Phase H).
import 'package:flutter/material.dart';

class MyReportsPage extends StatelessWidget {
  const MyReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reports'),
      ),
      body: const SizedBox.shrink(),
    );
  }
}
