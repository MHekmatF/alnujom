// lib/features/inquiries/presentation/pages/admin_inquiry_oversight_page.dart
//
// Phase 16 Sub-Phase F (T073) — REPLACES the Sub-Phase A stub.
// Thin wrapper around the InquiryInboxPage widget tree per R-106 +
// contracts/phase16-admin-oversight-overlay.md.
//
// Key differences from publisher inbox:
//   1. AdminTierBanner at the top of the body.
//   2. Extra PublisherFilterDropdown in AppBar actions (stub in Phase 16;
//      real publisher-list query deferred — admin RLS already returns all rows).
//   3. Uses same InquiryInboxBloc; cross-publisher rows come via RLS
//      inquiries_select_admin policy.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/deep_link_aware_back_button.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/inquiry.dart';
import '../../domain/entities/inquiry_status.dart';
import '../bloc/inquiry_inbox_bloc.dart';
import '../widgets/admin_tier_banner.dart';
import '../widgets/inbox_skeleton.dart';
import '../widgets/inbox_status_badge.dart';
import '../widgets/inquiry_message_snippet.dart';

class AdminInquiryOversightPage extends StatelessWidget {
  const AdminInquiryOversightPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<InquiryInboxBloc>(
      create: (_) =>
          getIt<InquiryInboxBloc>()
            ..add(const InquiryInboxOpened(adminTier: true)),
      child: const _AdminOversightView(),
    );
  }
}

class _AdminOversightView extends StatelessWidget {
  const _AdminOversightView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<InquiryInboxBloc, InquiryInboxState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            leading: const DeepLinkAwareBackButton(),
            title: Text(l10n.admin_inquiries_app_bar_title),
            actions: [
              // Status filter — reused from publisher inbox.
              _AdminStatusFilterButton(state: state),
              // Publisher filter stub (Phase 16: always "All publishers").
              const _PublisherFilterDropdown(),
            ],
          ),
          body: Column(
            children: [
              // Admin-tier banner distinguishes this from the publisher inbox.
              const AdminTierBanner(),
              Expanded(child: _AdminInboxBody(state: state)),
            ],
          ),
        );
      },
    );
  }
}

class _AdminStatusFilterButton extends StatelessWidget {
  const _AdminStatusFilterButton({required this.state});

  final InquiryInboxState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentFilter = state is InquiryInboxLoaded
        ? (state as InquiryInboxLoaded).statusFilter
        : null;

    return PopupMenuButton<InquiryStatus?>(
      tooltip: l10n.inquiry_inbox_filter_status_label,
      icon: const Icon(LucideIcons.funnel),
      onSelected: (value) => context.read<InquiryInboxBloc>().add(
        InquiryInboxStatusFilterChanged(value),
      ),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: null,
          child: Text(l10n.inquiry_inbox_filter_status_label),
        ),
        PopupMenuItem(
          value: InquiryStatus.new_,
          child: Text(l10n.inquiry_status_new),
        ),
        PopupMenuItem(
          value: InquiryStatus.seen,
          child: Text(l10n.inquiry_status_seen),
        ),
        PopupMenuItem(
          value: InquiryStatus.responded,
          child: Text(l10n.inquiry_status_responded),
        ),
        PopupMenuItem(
          value: InquiryStatus.closed,
          child: Text(l10n.inquiry_status_closed),
        ),
      ],
      initialValue: currentFilter,
    );
  }
}

/// Phase 16 stub — renders a single "All publishers" entry.
/// A real implementation would query DISTINCT publisher_user_id from listings.
class _PublisherFilterDropdown extends StatelessWidget {
  const _PublisherFilterDropdown();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopupMenuButton<String?>(
      tooltip: l10n.admin_inquiries_publisher_filter_label,
      icon: const Icon(LucideIcons.user),
      onSelected: (_) {
        // Phase 16 stub: no real publisher filter implemented.
        // The admin RLS policy returns cross-publisher rows automatically.
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: null,
          child: Text(l10n.admin_inquiries_publisher_filter_label),
        ),
      ],
    );
  }
}

class _AdminInboxBody extends StatelessWidget {
  const _AdminInboxBody({required this.state});

  final InquiryInboxState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return switch (state) {
      InquiryInboxLoading() => const InboxSkeleton(),
      InquiryInboxError(:final failure) => ErrorState(
        title: failure.message,
        variant: ErrorStateVariant.network,
        onRetry: () => context.read<InquiryInboxBloc>().add(
          const InquiryInboxRefreshRequested(),
        ),
      ),
      InquiryInboxLoaded(inquiries: final inquiries, hasMore: final hasMore) =>
        inquiries.isEmpty
            ? EmptyState(
                icon: LucideIcons.inbox,
                headline: l10n.inquiry_inbox_empty_state,
              )
            : RefreshIndicator(
                onRefresh: () async {
                  context.read<InquiryInboxBloc>().add(
                    const InquiryInboxRefreshRequested(),
                  );
                },
                child: ListView.builder(
                  itemCount: inquiries.length + (hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= (inquiries.length * 0.8).floor() && hasMore) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        context.read<InquiryInboxBloc>().add(
                          const InquiryInboxMoreLoaded(),
                        );
                      });
                    }
                    if (index >= inquiries.length) {
                      return const Padding(
                        padding: EdgeInsetsDirectional.all(AppSpacing.lg),
                        child: AppSpinner(),
                      );
                    }
                    return StaggeredListItem(
                      index: index,
                      child: _AdminInquiryRowTile(inquiry: inquiries[index]),
                    );
                  },
                ),
              ),
    };
  }
}

class _AdminInquiryRowTile extends StatelessWidget {
  const _AdminInquiryRowTile({required this.inquiry});

  final Inquiry inquiry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final matLoc = MaterialLocalizations.of(context);
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    final displayPhone =
        inquiry.decryptedPhone ??
        l10n.inquiry_detail_phone_unavailable_placeholder;
    final displayName = inquiry.senderName.isEmpty
        ? l10n.inquiry_inbox_anonymous_sender_label
        : inquiry.senderName;

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: PressScale(
        child: AppSurface(
          onTap: () => context.push(AppRoutes.inquiryDetailFor(inquiry.id)),
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          radius: AppRadii.lg,
          elevated: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: sender name (bold) + status pill.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (inquiry.status == InquiryStatus.new_) ...[
                    Container(
                      width: AppSpacing.sm,
                      height: AppSpacing.sm,
                      margin: const EdgeInsetsDirectional.only(
                        end: AppSpacing.sm,
                        top: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary,
                      ),
                    ),
                  ],
                  Expanded(
                    child: Text(
                      displayName,
                      style: styles.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  InboxStatusBadge(status: inquiry.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                displayPhone,
                style: styles.bodyMedium.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: [
                  Icon(
                    LucideIcons.house,
                    size: AppSpacing.md,
                    color: colors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      inquiry.listingTitle,
                      style: styles.bodyMedium.copyWith(
                        color: colors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              InquiryMessageSnippet(message: inquiry.message),
              const SizedBox(height: AppSpacing.sm),
              Text(
                matLoc.formatCompactDate(inquiry.createdAt.toLocal()),
                style: styles.labelMedium.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
