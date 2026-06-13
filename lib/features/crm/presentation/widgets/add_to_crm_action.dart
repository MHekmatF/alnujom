// lib/features/crm/presentation/widgets/add_to_crm_action.dart
//
// Phase 029 (F1) — a small, self-contained "Add to CRM" helper reused by the
// inquiry-detail / chat-thread / viewings entry points. Each source resolves
// its lead via the matching server RPC (contact resolved server-side). Shows an
// AppToast and offers a "View" action that pushes the CRM page.
//
// Self-contained: it builds its own short-lived CrmRepository call through DI,
// so the host pages do not need a CRM BlocProvider in scope.

import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/repositories/crm_repository.dart';
import '../pages/crm_page.dart';

enum CrmLeadSource { inquiry, conversation, viewing }

/// Attaches a lead from [source] identified by [sourceId] and toasts the result.
/// [displayName] is an optional hint (e.g. the inquirer name / listing title).
Future<void> addToCrm(
  BuildContext context, {
  required CrmLeadSource source,
  required String sourceId,
  String? displayName,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final repo = getIt<CrmRepository>();

  final result = switch (source) {
    CrmLeadSource.inquiry => await repo.upsertLeadFromInquiry(
      inquiryId: sourceId,
      displayName: displayName,
    ),
    CrmLeadSource.conversation => await repo.upsertLeadFromConversation(
      conversationId: sourceId,
      displayName: displayName,
    ),
    CrmLeadSource.viewing => await repo.upsertLeadFromViewing(
      viewingId: sourceId,
      displayName: displayName,
    ),
  };

  if (!context.mounted) return;

  if (result is Success<String>) {
    AppToast.show(
      context,
      l10n.crmAddedToCrmSuccess,
      variant: AppToastVariant.success,
      action: SnackBarAction(
        label: l10n.crmViewAction,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CrmPage()),
        ),
      ),
    );
  } else {
    AppToast.error(context, l10n.crmAddToCrmError);
  }
}
