// lib/features/inquiries/presentation/pages/inquiry_inbox_page.dart
//
// Phase 16 Sub-Phase F (T069) — REPLACES the Sub-Phase A stub.
// Full implementation per contracts/phase16-inbox-page-composition.md.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/deep_link_aware_back_button.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/inquiry.dart';
import '../../domain/entities/inquiry_status.dart';
import '../bloc/inquiry_inbox_bloc.dart';
import '../widgets/inbox_status_badge.dart';
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
        return Scaffold(
          appBar: AppBar(
            leading: const DeepLinkAwareBackButton(),
            title: Text(l10n.inquiry_inbox_app_bar_title),
            actions: [
              _StatusFilterButton(state: state),
              _ListingFilterButton(state: state),
            ],
          ),
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
    final currentFilter = state is InquiryInboxLoaded
        ? (state as InquiryInboxLoaded).statusFilter
        : null;

    return PopupMenuButton<InquiryStatus?>(
      tooltip: l10n.inquiry_inbox_filter_status_label,
      icon: const Icon(Icons.filter_list),
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

class _ListingFilterButton extends StatelessWidget {
  const _ListingFilterButton({required this.state});

  final InquiryInboxState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopupMenuButton<String?>(
      tooltip: l10n.inquiry_inbox_filter_listing_label,
      icon: const Icon(Icons.home_outlined),
      onSelected: (value) {
        context.read<InquiryInboxBloc>().add(
          InquiryInboxListingFilterChanged(value),
        );
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: null,
          child: Text(l10n.inquiry_inbox_filter_listing_label),
        ),
      ],
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
      InquiryInboxLoading() => const Center(child: CircularProgressIndicator()),
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
                icon: Icons.inbox_outlined,
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
                    // Trigger load-more at 80% scroll.
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

                    return _InquiryRowTile(inquiry: inquiries[index]);
                  },
                ),
              ),
    };
  }
}

class _InquiryRowTile extends StatelessWidget {
  const _InquiryRowTile({required this.inquiry});

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
    final formattedDate = matLoc.formatCompactDate(inquiry.createdAt.toLocal());

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
                      formattedDate,
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
