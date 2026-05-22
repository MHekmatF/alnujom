import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../l10n/app_localizations.dart';

class ResubmitCta extends StatelessWidget {
  const ResubmitCta({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: () => context.goNamed(
          AppRouteNames.publisherListingsEdit,
          pathParameters: {'id': listingId},
        ),
        child: Text(l10n.resubmitButton),
      ),
    );
  }
}
