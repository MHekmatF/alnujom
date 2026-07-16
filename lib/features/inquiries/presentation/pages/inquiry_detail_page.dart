// lib/features/inquiries/presentation/pages/inquiry_detail_page.dart
//
// Phase 16 Sub-Phase F (T071) — REPLACES the Sub-Phase A stub.
// Full implementation per plan §Sub-Phase F step 6.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/ds/dc_status_chip.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../crm/presentation/widgets/add_to_crm_action.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/inquiry.dart';
import '../../domain/entities/inquiry_status.dart';
import '../bloc/inquiry_detail_bloc.dart';

class InquiryDetailPage extends StatelessWidget {
  const InquiryDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<InquiryDetailBloc>(
      create: (_) => getIt<InquiryDetailBloc>()..add(InquiryDetailOpened(id)),
      child: _InquiryDetailView(id: id),
    );
  }
}

class _InquiryDetailView extends StatelessWidget {
  const _InquiryDetailView({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DcCrownScaffold(
      title: l10n.inquiry_detail_app_bar_title,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () => context.canPop()
            ? context.pop()
            : context.go(AppRoutes.shellHome),
      ),
      body: BlocBuilder<InquiryDetailBloc, InquiryDetailState>(
        builder: (context, state) {
          return switch (state) {
            InquiryDetailLoading() => const AppSpinner.page(),
            InquiryDetailError(:final failure) => ErrorState(
              title: failure.message,
              variant: ErrorStateVariant.network,
              onRetry: () => context.read<InquiryDetailBloc>().add(
                InquiryDetailOpened(id),
              ),
            ),
            InquiryDetailLoaded(:final inquiry) => _InquiryDetailBody(
              inquiry: inquiry,
            ),
          };
        },
      ),
    );
  }
}

class _InquiryDetailBody extends StatelessWidget {
  const _InquiryDetailBody({required this.inquiry});

  final Inquiry inquiry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    final displayPhone =
        inquiry.decryptedPhone ??
        l10n.inquiry_detail_phone_unavailable_placeholder;

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card: status pill, sender name, and the callback phone with
          // a call affordance — grouped in a DS surface.
          AppSurface(
            radius: AppRadii.lg,
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _statusChip(inquiry.status, l10n),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  inquiry.senderName.isNotEmpty
                      ? inquiry.senderName
                      : l10n.inquiry_inbox_anonymous_sender_label,
                  style: styles.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.inquiry_detail_callback_phone_label,
                            style: styles.labelMedium.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                          Text(displayPhone, style: styles.bodyMedium),
                        ],
                      ),
                    ),
                    if (inquiry.decryptedPhone != null)
                      AppButton(
                        label: l10n.inquiry_detail_tap_to_call_action,
                        variant: AppButtonVariant.tonal,
                        size: AppButtonSize.dense,
                        icon: LucideIcons.phone,
                        onPressed: () => launchUrl(
                          Uri.parse('tel:${inquiry.decryptedPhone}'),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Message body in its own card surface.
          AppSurface(
            radius: AppRadii.lg,
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.inquiry_form_message_label,
                  style: styles.labelMedium.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(inquiry.message, style: styles.bodyLarge),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Listing reference (tappable) — a DS surface row with a chevron.
          AppSurface(
            radius: AppRadii.lg,
            padding: const EdgeInsetsDirectional.all(AppSpacing.md),
            onTap: () =>
                context.push(AppRoutes.listingDetailsFor(inquiry.listingId)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: kAppMinTouchTarget),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.house,
                    size: AppSpacing.lg,
                    color: colors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      inquiry.listingTitle,
                      style: styles.bodyMedium.copyWith(color: colors.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    l10n.inquiry_detail_listing_link_label,
                    style: styles.labelMedium.copyWith(color: colors.primary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Phase 29 (F1) — "Add to CRM": attach this inquiry's sender as a
          // lead in the publisher's pipeline (publisher-only; the lead's
          // contact is resolved server-side by the upsert RPC).
          if (inquiry.viewerIsPublisher) ...[
            AppButton(
              label: l10n.crmAddToCrmAction,
              variant: AppButtonVariant.tonal,
              icon: LucideIcons.handshake,
              onPressed: () => addToCrm(
                context,
                source: CrmLeadSource.inquiry,
                sourceId: inquiry.id,
                displayName: inquiry.senderName,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Status mutation buttons — gated by allowedTransitions.
          // The closed→new transition has NO UI affordance per Q2=B.
          // The spam status is NOT exposed as a publisher-side affordance per Q3=B.
          _StatusMutationButtons(inquiry: inquiry),
        ],
      ),
    );
  }
}

class _StatusMutationButtons extends StatelessWidget {
  const _StatusMutationButtons({required this.inquiry});

  final Inquiry inquiry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bloc = context.read<InquiryDetailBloc>();

    // Read-only for non-publishers (admin oversight / sender views): only the
    // listing's publisher may mutate status. RLS enforces the same server-side.
    if (!inquiry.viewerIsPublisher) return const SizedBox.shrink();

    final allowed = inquiry.status.allowedTransitions;

    // Filter out spam (Q3=B: no publisher-side spam marking in Phase 16).
    final visibleTransitions = allowed
        .where((s) => s != InquiryStatus.spam)
        .toSet();

    if (visibleTransitions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        if (visibleTransitions.contains(InquiryStatus.responded))
          AppButton.filledPrimary(
            label: l10n.inquiry_detail_mark_responded_action,
            onPressed: () => bloc.add(const MarkResponded()),
          ),
        if (visibleTransitions.contains(InquiryStatus.closed) &&
            inquiry.status != InquiryStatus.new_)
          AppButton(
            label: l10n.inquiry_detail_mark_closed_action,
            variant: AppButtonVariant.outlined,
            onPressed: () => bloc.add(const MarkClosed()),
          ),
        // Reopen paths (Q2=B): closed/responded → seen.
        if (visibleTransitions.contains(InquiryStatus.seen) &&
            (inquiry.status == InquiryStatus.closed ||
                inquiry.status == InquiryStatus.responded))
          AppButton(
            label: l10n.inquiry_detail_reopen_to_seen_action,
            variant: AppButtonVariant.outlined,
            onPressed: () => bloc.add(const ReopenToSeen()),
          ),
        // Reopen directly to responded (closed → responded per Q2=B).
        if (visibleTransitions.contains(InquiryStatus.responded) &&
            inquiry.status == InquiryStatus.closed)
          AppButton.filledPrimary(
            label: l10n.inquiry_detail_reopen_to_responded_action,
            onPressed: () => bloc.add(const ReopenToResponded()),
          ),
      ],
    );
  }
}

/// Maps an inquiry status to a DC status chip.
DcStatusChip _statusChip(InquiryStatus status, AppLocalizations l10n) {
  final (label, tone) = switch (status) {
    InquiryStatus.new_ => (l10n.inquiry_status_new, DcStatusTone.neutral),
    InquiryStatus.seen => (l10n.inquiry_status_seen, DcStatusTone.neutral),
    InquiryStatus.responded => (
      l10n.inquiry_status_responded,
      DcStatusTone.green,
    ),
    InquiryStatus.closed => (l10n.inquiry_status_closed, DcStatusTone.neutral),
    InquiryStatus.spam => (l10n.inquiry_status_spam, DcStatusTone.red),
  };
  return DcStatusChip(label: label, tone: tone);
}
