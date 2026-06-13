// lib/features/inquiries/presentation/pages/inquiry_detail_page.dart
//
// Phase 16 Sub-Phase F (T071) — REPLACES the Sub-Phase A stub.
// Full implementation per plan §Sub-Phase F step 6.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/deep_link_aware_back_button.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../crm/presentation/widgets/add_to_crm_action.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/inquiry.dart';
import '../../domain/entities/inquiry_status.dart';
import '../bloc/inquiry_detail_bloc.dart';
import '../widgets/inbox_status_badge.dart';

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

    return Scaffold(
      appBar: AppBar(
        leading: const DeepLinkAwareBackButton(),
        title: Text(l10n.inquiry_detail_app_bar_title),
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
          // Status badge
          InboxStatusBadge(status: inquiry.status),
          const SizedBox(height: AppSpacing.lg),

          // Sender name
          Text(
            inquiry.senderName.isNotEmpty
                ? inquiry.senderName
                : l10n.inquiry_inbox_anonymous_sender_label,
            style: styles.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),

          // Callback phone row
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
                Tooltip(
                  message: l10n.inquiry_detail_tap_to_call_action,
                  child: IconButton(
                    icon: const Icon(Icons.phone_outlined),
                    onPressed: () =>
                        launchUrl(Uri.parse('tel:${inquiry.decryptedPhone}')),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Message
          Text(inquiry.message, style: styles.bodyMedium),
          const SizedBox(height: AppSpacing.lg),

          // Listing reference (tappable)
          InkWell(
            onTap: () =>
                context.push(AppRoutes.listingDetailsFor(inquiry.listingId)),
            child: Row(
              children: [
                const Icon(Icons.home_outlined, size: AppSpacing.lg),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    inquiry.listingTitle,
                    style: styles.bodyMedium.copyWith(
                      color: colors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                Text(
                  l10n.inquiry_detail_listing_link_label,
                  style: styles.labelMedium.copyWith(color: colors.primary),
                ),
              ],
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
              icon: Icons.handshake_outlined,
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
          ElevatedButton(
            onPressed: () => bloc.add(const MarkResponded()),
            child: Text(l10n.inquiry_detail_mark_responded_action),
          ),
        if (visibleTransitions.contains(InquiryStatus.closed) &&
            inquiry.status != InquiryStatus.new_)
          OutlinedButton(
            onPressed: () => bloc.add(const MarkClosed()),
            child: Text(l10n.inquiry_detail_mark_closed_action),
          ),
        // Reopen paths (Q2=B): closed/responded → seen.
        if (visibleTransitions.contains(InquiryStatus.seen) &&
            (inquiry.status == InquiryStatus.closed ||
                inquiry.status == InquiryStatus.responded))
          OutlinedButton(
            onPressed: () => bloc.add(const ReopenToSeen()),
            child: Text(l10n.inquiry_detail_reopen_to_seen_action),
          ),
        // Reopen directly to responded (closed → responded per Q2=B).
        if (visibleTransitions.contains(InquiryStatus.responded) &&
            inquiry.status == InquiryStatus.closed)
          ElevatedButton(
            onPressed: () => bloc.add(const ReopenToResponded()),
            child: Text(l10n.inquiry_detail_reopen_to_responded_action),
          ),
      ],
    );
  }
}
