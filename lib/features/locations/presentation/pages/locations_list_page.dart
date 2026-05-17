import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

class LocationsListPage extends StatelessWidget {
  const LocationsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.locationsListPageTitle)),
      body: const Center(child: Text('US3 lands here')),
    );
  }
}
