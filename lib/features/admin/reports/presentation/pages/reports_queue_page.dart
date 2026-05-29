// Phase 18 (spec/018-reports-moderation) — ReportsQueuePage stub.
// Navigated to from AdminHomePage via /admin/reports (T003/T008).
// Gated by requireReportsManageRedirect. Full implementation in Phase 9 (Sub-Phase I).
import 'package:flutter/material.dart';

class ReportsQueuePage extends StatelessWidget {
  const ReportsQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports Queue'),
      ),
      body: const SizedBox.shrink(),
    );
  }
}
