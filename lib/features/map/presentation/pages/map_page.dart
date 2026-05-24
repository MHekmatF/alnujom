import 'package:flutter/material.dart';

import '../../domain/entities/map_entry_context.dart';

/// Phase 15 Sub-Phase A stub. Sub-Phase E (Phase 6) replaces this body with
/// the full MapPage composition (BlocProvider, FlutterMap, cluster layer,
/// geolocation FAB, popover, etc.).
class MapPage extends StatelessWidget {
  const MapPage({super.key, this.entryContext});

  final MapEntryContext? entryContext;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
    );
  }
}
