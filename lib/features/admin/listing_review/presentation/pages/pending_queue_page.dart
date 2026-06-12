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
import '../bloc/pending_queue_bloc.dart';
import '../widgets/pending_queue_card.dart';

/// Phase 12 — admin pending-review queue page.
/// Route: `/admin/listing-review/pending` (registered in `app_router.dart`).
/// Contract: `contracts/phase12-admin-queue-page.md`.
class PendingQueuePage extends StatelessWidget {
  const PendingQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PendingQueueBloc>(
      create: (_) =>
          getIt<PendingQueueBloc>()..add(const PendingQueueLoadFirstPage()),
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminQueueTitle)),
      body: BlocBuilder<PendingQueueBloc, PendingQueueState>(
        builder: (ctx, state) {
          if (state.isLoadingFirstPage && state.listings.isEmpty) {
            return const _QueueSkeleton();
          }
          if (state.failure != null && state.listings.isEmpty) {
            return _ErrorState(
              message: state.failure!.message,
              onRetry: () =>
                  ctx.read<PendingQueueBloc>().add(const PendingQueueRefresh()),
            );
          }
          if (state.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                ctx.read<PendingQueueBloc>().add(const PendingQueueRefresh());
              },
              child: ListView(
                children: [
                  const SizedBox(height: AppSpacing.xxxl + AppSpacing.xxl),
                  Center(child: Text(l10n.adminQueueEmpty)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ctx.read<PendingQueueBloc>().add(const PendingQueueRefresh());
            },
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              itemCount:
                  state.listings.length + (state.isLoadingNextPage ? 1 : 0),
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (ctx, index) {
                if (index >= state.listings.length) {
                  return const Padding(
                    padding: EdgeInsetsDirectional.all(AppSpacing.md),
                    child: AppSpinner(),
                  );
                }
                return PendingQueueCard(summary: state.listings[index]);
              },
            ),
          );
        },
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
