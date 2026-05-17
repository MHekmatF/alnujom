import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LocationFormPage extends StatelessWidget {
  const LocationFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    final params = GoRouterState.of(context).uri.queryParameters;
    final mode = params['mode'] ?? '';
    final level = params['level'] ?? '';
    return Scaffold(
      appBar: AppBar(title: Text('Form: $mode / $level')),
      body: Center(
        child: Text('US3 form lands here — mode=$mode level=$level'),
      ),
    );
  }
}
