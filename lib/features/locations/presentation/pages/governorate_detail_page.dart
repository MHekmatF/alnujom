import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

class GovernorateDetailPage extends StatelessWidget {
  const GovernorateDetailPage({super.key, required this.governorateId});

  final String governorateId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.governorateDetailPageTitle)),
      body: Center(child: Text('US4 lands here — governorateId=$governorateId')),
    );
  }
}
