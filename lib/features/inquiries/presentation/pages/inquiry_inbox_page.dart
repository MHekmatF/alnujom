// lib/features/inquiries/presentation/pages/inquiry_inbox_page.dart
//
// Phase 16 — the inquiry inbox, restyled to the DC "Blue Crown" system
// (`AlNujom - Publisher.dc.html` «الاستفسارات»): a crown header with a status
// filter, and flat inquiry rows (tonal avatar + unread dot + name + DcStatusChip
// + phone + listing + message snippet + date). Behaviour-preserving.
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
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/ds/dc_status_chip.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/inquiry.dart';
import '../../domain/entities/inquiry_status.dart';
import '../bloc/inquiry_inbox_bloc.dart';
import '../widgets/inbox_skeleton.dart';
import '../widgets/inquiry_message_snippet.dart';

class InquiryInboxPage extends StatelessWidget {
  const InquiryInboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<InquiryInboxBloc>(
      create: (_) => getIt<InquiryInboxBloc>()..add(const InquiryInboxOpened()),
      child: const _InquiryInboxView(),
    );
  }
}

class _InquiryInboxView extends StatelessWidget {
  const _InquiryInboxView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<InquiryInboxBloc, InquiryInboxState>(
      builder: (context, state) {
        return DcCrownScaffold(
          title: l10n.inquiry_inbox_app_bar_title,
          dense: true,
          leading: DcCrownIconButton(
            icon: Icons.arrow_forward,
            onTap: () => context.canPop()
                ? context.pop()
                : context.go(AppRoutes.shellHome),
          ),
          actions: [_StatusFilterButton(state: state)],
          body: _InboxBody(state: state),
        );
      },
    );
  }
}

class _StatusFilterButton extends StatelessWidget {
  const _StatusFilterButton({required this.state});

  final InquiryInboxState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final currentFilter = state is InquiryInboxLoaded
        ? (state as InquiryInboxLoaded).statusFilter
        : null;

    return PopupMenuButton<InquiryStatus?>(
      tooltip: l10n.inquiry_inbox_filter_status_label,
      icon: Icon(LucideIcons.funnel, color: colors.onBrandHeader),
      onSelected: (value) {
        context.read<InquiryInboxBloc>().add(
          InquiryInboxStatusFilterChanged(value),
        );
      },
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

class _InboxBody extends StatelessWidget {
  const _InboxBody({required this.state});

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
                  padding: const EdgeInsetsDirectional.only(
                    top: AppSpacing.sm,
                    bottom: AppSpacing.xl,
                  ),
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
                      child: _InquiryRowTile(inquiry: inquiries[index]),
                    );
                  },
                ),
              ),
    };
  }
}

/// One inquiry as a flat DC row: a tonal avatar (with an unread dot), the sender
/// name + a DcStatusChip, the callback phone, the listing, a message snippet and
/// the date.
class _InquiryRowTile extends StatelessWidget {
  const _InquiryRowTile({required this.inquiry});

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
    final initial = displayName.trim().isEmpty
        ? '؟'
        : displayName.trim().substring(0, 1);
    final formattedDate = matLoc.formatCompactDate(inquiry.createdAt.toLocal());
    final unread = inquiry.status == InquiryStatus.new_;

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Material(
        color: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: appRadius(AppRadii.lg),
          side: BorderSide(color: colors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: appRadius(AppRadii.lg),
          onTap: () => context.push(AppRoutes.inquiryDetailFor(inquiry.id)),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(initial: initial, unread: unread),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: styles.titleMedium.copyWith(
                                color: colors.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _inquiryChip(inquiry.status, l10n),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        displayPhone,
                        style: styles.bodyMedium.copyWith(
                          color: colors.textMuted,
                        ),
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
                        formattedDate,
                        style: styles.labelMedium.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, required this.unread});

  final String initial;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Text(
            initial,
            style: styles.titleMedium.copyWith(
              color: colors.onPrimaryContainer,
            ),
          ),
        ),
        if (unread)
          PositionedDirectional(
            top: -1,
            end: -1,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colors.error,
                shape: BoxShape.circle,
                border: Border.all(color: colors.card, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

/// Maps an inquiry status to a DC status chip.
DcStatusChip _inquiryChip(InquiryStatus status, AppLocalizations l10n) {
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
