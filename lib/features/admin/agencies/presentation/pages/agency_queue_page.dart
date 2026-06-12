// Phase 19 (spec/019-agencies) — T066
// AgencyQueuePage: admin agency verification queue with status filter +
// cursor-paginated list. Replaces the Phase 1 stub.
// Route: /admin/agencies (gated by requireAgenciesManageRedirect, T002/T003).
// Tapping a card navigates to AgencyDetailPage.
// Mirrors ReportsQueuePage (Phase 18).
// Constitution IX: zero Supabase imports.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_spinner.dart';
import '../../../../../core/widgets/loading_state.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.agencies_queue_title)),
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
                  return _ErrorState(
                    message: state.failure!.message,
                    onRetry: () => ctx.read<AgencyQueueBloc>().add(
                      const AgencyQueueRefresh(),
                    ),
                  );
                }
                if (state.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      ctx.read<AgencyQueueBloc>().add(
                        const AgencyQueueRefresh(),
                      );
                    },
                    child: ListView(
                      children: [
                        const SizedBox(height: AppSpacing.xl),
                        Center(child: Text(l10n.agencies_queue_empty)),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ctx.read<AgencyQueueBloc>().add(const AgencyQueueRefresh());
                  },
                  child: ListView.separated(
                    controller: _scrollController,
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
                      return AgencyQueueCard(
                        item: item,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  AgencyDetailPage(agencyId: item.agency.id),
                            ),
                          );
                        },
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
    final theme = Theme.of(context);

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

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // "All" chip
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: FilterChip(
                label: Text(l10n.agency_filter_status_label),
                selected: selected == null,
                onSelected: (_) => onChanged(null),
                selectedColor: theme.colorScheme.primaryContainer,
              ),
            ),
            // One chip per status
            for (final status in AgencyStatus.values)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                child: FilterChip(
                  label: Text(statusLabel(status)),
                  selected: selected == status,
                  onSelected: (picked) => onChanged(picked ? status : null),
                  selectedColor: theme.colorScheme.primaryContainer,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Error state ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: styles.bodyLarge.copyWith(color: colors.error),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: AppLocalizations.of(context)!.actionReload,
              onPressed: onRetry,
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
