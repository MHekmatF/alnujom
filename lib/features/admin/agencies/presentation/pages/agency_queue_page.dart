// Phase 19 (spec/019-agencies) — T066
// AgencyQueuePage: admin agency verification queue with status filter +
// cursor-paginated list. Replaces the Phase 1 stub.
// Route: /admin/agencies (gated by requireAgenciesManageRedirect, T002/T003).
// Tapping a card navigates to AgencyDetailPage.
// Mirrors ReportsQueuePage (Phase 18).
// Constitution IX: zero Supabase imports.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/widgets/app_spinner.dart';
import '../../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/error_state.dart';
import '../../../../../core/widgets/loading_state.dart';
import '../../../../../core/widgets/staggered_list_item.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../agency/domain/entities/agency_status.dart';
import '../bloc/agency_queue_bloc.dart';
import '../bloc/agency_queue_state.dart';
import '../widgets/agency_queue_card.dart';
import 'agency_detail_page.dart';

class AgencyQueuePage extends StatelessWidget {
  const AgencyQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AgencyQueueBloc>(
      create: (_) => getIt<AgencyQueueBloc>()..add(const AgencyQueueOpened()),
      child: const _AgencyQueueView(),
    );
  }
}

class _AgencyQueueView extends StatefulWidget {
  const _AgencyQueueView();

  @override
  State<_AgencyQueueView> createState() => _AgencyQueueViewState();
}

class _AgencyQueueViewState extends State<_AgencyQueueView> {
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
      context.read<AgencyQueueBloc>().add(const AgencyQueueLoadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DcCrownScaffold(
      title: l10n.agencies_queue_title,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.shellHome),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Status filter bar ────────────────────────────────────────────
          BlocBuilder<AgencyQueueBloc, AgencyQueueState>(
            buildWhen: (prev, curr) => prev.statusFilter != curr.statusFilter,
            builder: (ctx, state) {
              return _AgencyStatusFilterBar(
                selected: state.statusFilter,
                onChanged: (s) {
                  ctx.read<AgencyQueueBloc>().add(
                    AgencyQueueFilterChanged(status: s, clearStatus: s == null),
                  );
                },
              );
            },
          ),
          // ── Queue list ───────────────────────────────────────────────────
          Expanded(
            child: BlocBuilder<AgencyQueueBloc, AgencyQueueState>(
              builder: (ctx, state) {
                if (state.isLoadingFirstPage && state.items.isEmpty) {
                  return const _QueueSkeleton();
                }
                if (state.failure != null && state.items.isEmpty) {
                  // Batch-2: the local _ErrorState clone -> shared ErrorState.
                  return ErrorState(
                    title: l10n.agencies_queue_title,
                    message: state.failure!.message,
                    onRetry: () => ctx.read<AgencyQueueBloc>().add(
                      const AgencyQueueRefresh(),
                    ),
                  );
                }
                if (state.isEmpty) {
                  // Batch-2: a bare centred Text under a hand-tuned spacer ->
                  // the shared EmptyState, still scrollable so the existing
                  // pull-to-refresh keeps working while empty.
                  return RefreshIndicator(
                    onRefresh: () async {
                      ctx.read<AgencyQueueBloc>().add(
                        const AgencyQueueRefresh(),
                      );
                    },
                    child: LayoutBuilder(
                      builder: (context, constraints) => ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: constraints.maxHeight,
                            child: EmptyState(
                              icon: LucideIcons.building_2,
                              headline: l10n.agencies_queue_empty,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ctx.read<AgencyQueueBloc>().add(const AgencyQueueRefresh());
                  },
                  child: ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                    itemCount:
                        state.items.length + (state.isLoadingNextPage ? 1 : 0),
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (ctx, index) {
                      if (index >= state.items.length) {
                        return const Padding(
                          padding: EdgeInsetsDirectional.all(AppSpacing.md),
                          child: AppSpinner(),
                        );
                      }
                      final item = state.items[index];
                      return StaggeredListItem(
                        index: index,
                        child: AgencyQueueCard(
                          item: item,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    AgencyDetailPage(agencyId: item.agency.id),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status filter bar ────────────────────────────────────────────────────────

class _AgencyStatusFilterBar extends StatelessWidget {
  const _AgencyStatusFilterBar({
    required this.selected,
    required this.onChanged,
  });

  final AgencyStatus? selected;
  final ValueChanged<AgencyStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);

    String statusLabel(AgencyStatus s) {
      switch (s) {
        case AgencyStatus.pending:
          return l10n.agency_status_pending;
        case AgencyStatus.approved:
          return l10n.agency_status_approved;
        case AgencyStatus.rejected:
          return l10n.agency_status_rejected;
        case AgencyStatus.suspended:
          return l10n.agency_status_suspended;
      }
    }

    // Batch-2: the bar sat on the bare sheet with no separation, and its chips
    // pinned `colorScheme.primaryContainer` directly instead of inheriting the
    // DS chipTheme. Now a hairline-bottom card bar of ChoiceChips with the
    // consumer selection haptic (StatusFilterChipRow idiom).
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        border: BorderDirectional(bottom: BorderSide(color: colors.outline)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            // "All" chip
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(l10n.agency_filter_status_label),
                selected: selected == null,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  onChanged(null);
                },
              ),
            ),
            // One chip per status
            for (final status in AgencyStatus.values)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                child: ChoiceChip(
                  label: Text(statusLabel(status)),
                  selected: selected == status,
                  onSelected: (picked) {
                    HapticFeedback.selectionClick();
                    onChanged(picked ? status : null);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer placeholder rows shown while the first agency page loads.
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
