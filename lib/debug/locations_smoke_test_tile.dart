import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Dev-only entry point to the LocationPicker smoke-test page.
///
/// Gated by `kDebugMode` at the call site. Lives under `lib/debug/**` so the
/// l10n-literals lint exemption applies (per analysis_options.yaml).
class LocationsSmokeTestTile extends StatelessWidget {
  const LocationsSmokeTestTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.bug_report_outlined),
      title: const Text('[debug] LocationPicker smoke test'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/dev/locations-picker'),
    );
  }
}
