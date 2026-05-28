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
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/deep_link_aware_back_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/inquiry.dart';
import '../../domain/entities/inquiry_status.dart';
import '../bloc/inquiry_inbox_bloc.dart';
import '../widgets/admin_tier_banner.dart';
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
      icon: const Icon(Icons.filter_list),
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
      icon: const Icon(Icons.person_outlined),
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
      InquiryInboxLoading() => const Center(child: CircularProgressIndicator()),
      InquiryInboxError(:final failure) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(failure.message),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<InquiryInboxBloc>().add(
                const InquiryInboxRefreshRequested(),
              ),
              child: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
      InquiryInboxLoaded(inquiries: final inquiries, hasMore: final hasMore) =>
        inquiries.isEmpty
            ? Center(child: Text(l10n.inquiry_inbox_empty_state))
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
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _AdminInquiryRowTile(inquiry: inquiries[index]);
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

    final displayPhone =
        inquiry.decryptedPhone ??
        l10n.inquiry_detail_phone_unavailable_placeholder;
    final displayName = inquiry.senderName.isEmpty
        ? l10n.inquiry_inbox_anonymous_sender_label
        : inquiry.senderName;

    return Card(
      margin: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: InkWell(
        onTap: () => context.push(AppRoutes.inquiryDetailFor(inquiry.id)),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InboxStatusBadge(status: inquiry.status),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayPhone,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      inquiry.listingTitle,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    InquiryMessageSnippet(message: inquiry.message),
                    const SizedBox(height: 4),
                    Text(
                      matLoc.formatCompactDate(inquiry.createdAt.toLocal()),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
