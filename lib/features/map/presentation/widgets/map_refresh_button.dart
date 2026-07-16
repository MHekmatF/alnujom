// lib/features/map/presentation/widgets/map_refresh_button.dart
//
// Phase 15 Sub-Phase E (T047) — AppBar action that dispatches
// [MarkersRefreshRequested] per R-89 (pull-to-refresh rejected due to
// map-pan gesture conflict; explicit refresh button is the chosen UX).
//
// FR-014a: dataset is session-cached; user controls re-fetch via this button.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../l10n/app_localizations.dart';
import '../bloc/map_bloc.dart';
import '../bloc/map_event.dart';

class MapRefreshButton extends StatelessWidget {
  const MapRefreshButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      icon: const Icon(LucideIcons.refresh_cw),
      tooltip: l10n.map_refresh_button_tooltip,
      onPressed: () =>
          context.read<MapBloc>().add(const MarkersRefreshRequested()),
    );
  }
}
