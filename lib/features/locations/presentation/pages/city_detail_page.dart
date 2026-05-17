import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

class CityDetailPage extends StatelessWidget {
  const CityDetailPage({
    super.key,
    required this.governorateId,
    required this.cityId,
  });

  final String governorateId;
  final String cityId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cityDetailPageTitle)),
      body: Center(
        child: Text(
          'US5 lands here — governorateId=$governorateId cityId=$cityId',
        ),
      ),
    );
  }
}
