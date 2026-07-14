// Phase 18 (spec/018-reports-moderation) — T056
// ReportsQueuePage: admin moderation queue with status/reason filters +
// cursor-paginated list. Replaces the Phase 1 stub.
// Route: /admin/reports (gated by requireReportsManageRedirect, T003).
// Tapping a card navigates to ReportDetailPage.
// Mirrors PendingQueuePage (Phase 12) with filter-bar composition.
// Constitution IX: zero Supabase imports.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_spinner.dart';
import '../../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../../core/widgets/loading_state.dart';
import '../../../../../l10n/app_localizations.dart';
import '../bloc/reports_queue_bloc.dart';
import '../bloc/reports_queue_state.dart';
import '../widgets/report_filter_bar.dart';
import '../widgets/report_queue_card.dart';
import 'report_detail_page.dart';

class ReportsQueuePage extends StatelessWidget {
  const ReportsQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ReportsQueueBloc>(
      create: (_) => getIt<ReportsQueueBloc>()..add(const ReportsQueueOpened()),
      child: const _ReportsQueueView(),
    );
  }
}

class _ReportsQueueView extends StatefulWidget {
  const _ReportsQueueView();

  @override
  State<_ReportsQueueView> createState() => _ReportsQueueViewState();
}

class _ReportsQueueViewState extends State<_ReportsQueueView> {
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
      context.read<ReportsQueueBloc>().add(const ReportsQueueLoadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DcCrownScaffold(
      title: l10n.reports_queue_title,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.shellHome),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Filter bar ───────────────────────────────────────────────────
          BlocBuilder<ReportsQueueBloc, ReportsQueueState>(
            buildWhen: (prev, curr) =>
                prev.statusFilter != curr.statusFilter ||
                prev.reasonFilter != curr.reasonFilter,
            builder: (ctx, state) {
              return ReportFilterBar(
                selectedStatus: state.statusFilter,
                selectedReason: state.reasonFilter,
                onStatusChanged: (s) {
                  ctx.read<ReportsQueueBloc>().add(
                    ReportsQueueFilterChanged(
                      status: s,
                      clearStatus: s == null,
                    ),
                  );
                },
                onReasonChanged: (r) {
                  ctx.read<ReportsQueueBloc>().add(
                    ReportsQueueFilterChanged(
                      reason: r,
                      clearReason: r == null,
                    ),
                  );
                },
              );
            },
          ),
          // ── Queue list ───────────────────────────────────────────────────
          Expanded(
            child: BlocBuilder<ReportsQueueBloc, ReportsQueueState>(
              builder: (ctx, state) {
                if (state.isLoadingFirstPage && state.items.isEmpty) {
                  return const _QueueSkeleton();
                }
                if (state.failure != null && state.items.isEmpty) {
                  return _ErrorState(
                    message: state.failure!.message,
                    onRetry: () => ctx.read<ReportsQueueBloc>().add(
                      const ReportsQueueRefresh(),
                    ),
                  );
                }
                if (state.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      ctx.read<ReportsQueueBloc>().add(
                        const ReportsQueueRefresh(),
                      );
                    },
                    child: ListView(
                      children: [
                        const SizedBox(height: AppSpacing.xl),
                        Center(child: Text(l10n.reports_queue_empty)),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ctx.read<ReportsQueueBloc>().add(
                      const ReportsQueueRefresh(),
                    );
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
                      return ReportQueueCard(
                        item: item,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ReportDetailPage(reportId: item.id),
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

/// Shimmer placeholder rows shown while the first reports page loads.
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
