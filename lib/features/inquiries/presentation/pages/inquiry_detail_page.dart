import 'package:flutter/material.dart';

/// Stub page — Sub-Phase G will wire in InquiryDetailBloc and ARB strings.
class InquiryDetailPage extends StatelessWidget {
  const InquiryDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inquiry'),
      ),
      body: const SizedBox.shrink(),
    );
  }
}
