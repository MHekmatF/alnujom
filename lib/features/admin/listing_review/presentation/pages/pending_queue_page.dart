import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/radii.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../core/widgets/_widget_support.dart';
import '../../../../../core/widgets/app_spinner.dart';
import '../../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/error_state.dart';
import '../../../../../core/widgets/loading_state.dart';
import '../../../../../core/widgets/staggered_list_item.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../listing_form/domain/entities/pending_revision.dart';
import '../bloc/pending_queue_bloc.dart';
import '../bloc/pending_revisions_cubit.dart';
import '../pages/revision_review_page.dart';
import '../widgets/pending_queue_card.dart';

/// Phase 12 — admin pending-review queue page.
/// Route: `/admin/listing-review/pending` (registered in `app_router.dart`).
/// Contract: `contracts/phase12-admin-queue-page.md`.
class PendingQueuePage extends StatelessWidget {
  const PendingQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<PendingQueueBloc>(
          create: (_) =>
              getIt<PendingQueueBloc>()..add(const PendingQueueLoadFirstPage()),
        ),
        // Phase 031 (WS-B) — pending stay-live edit revisions surface in their
        // own section atop the new-listing queue.
        BlocProvider<PendingRevisionsCubit>(
          create: (_) => getIt<PendingRevisionsCubit>()..load(),
        ),
      ],
      child: const _PendingQueueView(),
    );
  }
}

class _PendingQueueView extends StatefulWidget {
  const _PendingQueueView();

  @override
  State<_PendingQueueView> createState() => _PendingQueueViewState();
}

class _PendingQueueViewState extends State<_PendingQueueView> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      context.read<PendingQueueBloc>().add(const PendingQueueLoadNextPage());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DcCrownScaffold(
      title: l10n.adminQueueTitle,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.shellHome),
      ),
      body: Column(
        children: [
          const _PendingRevisionsSection(),
          Expanded(child: _buildQueueBody(context, l10n)),
        ],
      ),
    );
  }

  Widget _buildQueueBody(BuildContext context, AppLocalizations l10n) {
    return BlocBuilder<PendingQueueBloc, PendingQueueState>(
      builder: (ctx, state) {
        if (state.isLoadingFirstPage && state.listings.isEmpty) {
          return const _QueueSkeleton();
        }
        if (state.failure != null && state.listings.isEmpty) {
          // Batch-2: the local _ErrorState clone became the shared ErrorState.
          return ErrorState(
            title: l10n.adminQueueTitle,
            message: state.failure!.message,
            onRetry: () =>
                ctx.read<PendingQueueBloc>().add(const PendingQueueRefresh()),
          );
        }
        if (state.isEmpty) {
          // Batch-2: a bare centred Text under a hand-tuned 80dp spacer became
          // the shared EmptyState, still inside a scrollable so the existing
          // pull-to-refresh keeps working while empty.
          return RefreshIndicator(
            onRefresh: () async {
              ctx.read<PendingQueueBloc>().add(const PendingQueueRefresh());
            },
            child: LayoutBuilder(
              builder: (context, constraints) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: constraints.maxHeight,
                    child: EmptyState(
                      icon: LucideIcons.circle_check_big,
                      headline: l10n.adminQueueEmpty,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ctx.read<PendingQueueBloc>().add(const PendingQueueRefresh());
          },
          child: ListView.separated(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsetsDirectional.all(AppSpacing.md),
            itemCount:
                state.listings.length + (state.isLoadingNextPage ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (ctx, index) {
              if (index >= state.listings.length) {
                return const Padding(
                  padding: EdgeInsetsDirectional.all(AppSpacing.md),
                  child: AppSpinner(),
                );
              }
              return StaggeredListItem(
                index: index,
                child: PendingQueueCard(summary: state.listings[index]),
              );
            },
          ),
        );
      },
    );
  }
}

/// Phase 031 (WS-B) — the "edits awaiting approval" section pinned above the
/// new-listing queue. Collapses to nothing (no header chrome) when there are no
/// pending revisions. Each row pushes the [RevisionReviewPage]; on return the
/// section re-loads so an approved/rejected revision drops off.
class _PendingRevisionsSection extends StatelessWidget {
  const _PendingRevisionsSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final styles = AppTextStyles.of(context);

    return BlocBuilder<PendingRevisionsCubit, PendingRevisionsState>(
      builder: (ctx, state) {
        if (state.revisions.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.adminRevisionsSectionTitle, style: styles.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              for (final rev in state.revisions) ...[
                _PendingRevisionCard(revision: rev),
                const SizedBox(height: AppSpacing.sm),
              ],
              const Divider(height: AppSpacing.lg),
            ],
          ),
        );
      },
    );
  }
}

class _PendingRevisionCard extends StatelessWidget {
  const _PendingRevisionCard({required this.revision});

  final PendingRevision revision;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final title = revision.proposedTitle.isEmpty ? '—' : revision.proposedTitle;

    return Material(
      color: colors.surfaceVariant,
      borderRadius: appRadius(AppRadii.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(LucideIcons.file_pen, color: colors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: styles.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.adminRevisionPendingSubtitle,
                      style: styles.bodyMedium.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Batch-2 RTL: a bare chevron_right does not mirror in Arabic;
              // this matches the directional disclosure used by the DS app bar,
              // settings rows and the super-admin/currency cards.
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? LucideIcons.chevron_left
                    : LucideIcons.chevron_right,
                color: colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final cubit = context.read<PendingRevisionsCubit>();
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => RevisionReviewPage(
          revisionId: revision.revision.id,
          listingId: revision.listingId,
        ),
      ),
    );
    // Re-load on return so an applied/rejected revision drops off the queue.
    await cubit.load();
  }
}

/// Shimmer placeholder rows shown while the first queue page loads.
class _QueueSkeleton extends StatelessWidget {
  const _QueueSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, __) => const SizedBox(
        height: AppSpacing.xxxl + AppSpacing.xxl,
        child: LoadingState.card(),
      ),
    );
  }
}
