// Phase 21 (spec/021-ads-banners) — T025
// AdsListPage: admin list of ads with AdStatus chips + archived filter toggle
// + create FAB + per-row activate/deactivate + soft-delete (archive) actions.
// Route: /admin/ads (gated by requireAdsManageRedirect, T027).
// Mirrors AgencyQueuePage structure.
// Constitution IX: zero supabase_flutter imports.
import 'dart:async';

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
import '../../../../../core/widgets/app_dialog.dart';
import '../../../../../core/widgets/app_spinner.dart';
import '../../../../../core/widgets/app_toast.dart';
import '../../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../../core/widgets/loading_state.dart';
import '../../../../../core/widgets/press_scale.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../domain/entities/ad.dart';
import '../bloc/ads_admin_cubit.dart';
import '../widgets/ad_status_chip.dart';
import 'ad_editor_page.dart';

class AdsListPage extends StatelessWidget {
  const AdsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdsAdminCubit>(
      create: (_) => getIt<AdsAdminCubit>()..loadAds(),
      child: const _AdsListView(),
    );
  }
}

class _AdsListView extends StatelessWidget {
  const _AdsListView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DcCrownScaffold(
      title: l10n.adsAdminListTitle,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.shellHome),
      ),
      actions: [
        // Archived filter toggle
        BlocBuilder<AdsAdminCubit, AdsAdminState>(
          builder: (ctx, state) {
            final includeArchived =
                state is AdsAdminList && state.includeArchived;
            return IconButton(
              icon: Icon(
                LucideIcons.archive,
                color: includeArchived
                    ? AppColors.of(ctx).onBrandHeader
                    : AppColors.of(ctx).onBrandHeader.withValues(alpha: 0.55),
              ),
              tooltip: l10n.adsAdminArchivedFilterTooltip,
              onPressed: () {
                ctx.read<AdsAdminCubit>().loadAds(
                  includeArchived: !includeArchived,
                );
              },
            );
          },
        ),
      ],
      body: BlocConsumer<AdsAdminCubit, AdsAdminState>(
        listener: (ctx, state) {
          if (state is AdsAdminError) {
            AppToast.error(ctx, state.failure.message);
          }
        },
        builder: (ctx, state) {
          if (state is AdsAdminLoading) {
            return const _AdsListSkeleton();
          }
          if (state is AdsAdminList) {
            if (state.ads.isEmpty) {
              return Center(child: Text(l10n.adsAdminEmptyList));
            }
            return RefreshIndicator(
              onRefresh: () => ctx.read<AdsAdminCubit>().loadAds(
                includeArchived: state.includeArchived,
              ),
              child: ListView.separated(
                padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                itemCount: state.ads.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (ctx, i) {
                  final ad = state.ads[i];
                  return _AdListTile(
                    ad: ad,
                    onTap: () => _openEditor(ctx, ad: ad),
                  );
                },
              ),
            );
          }
          if (state is AdsAdminError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.errorGeneric),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: () => ctx.read<AdsAdminCubit>().loadAds(),
                    child: Text(l10n.errorRetryAction),
                  ),
                ],
              ),
            );
          }
          // AdsAdminSaving / AdsAdminSaveSuccess / AdsAdminImageUploaded /
          // initial — transient states, often driven by the shared editor
          // cubit. Show a spinner instead of a spurious error screen (review
          // Bug 1); the editor-return reload in _openEditor restores the list.
          return const AppSpinner.page();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context),
        tooltip: l10n.adsAdminCreateTooltip,
        child: const Icon(LucideIcons.plus),
      ),
    );
  }

  void _openEditor(BuildContext context, {Ad? ad}) {
    final cubit = context.read<AdsAdminCubit>();
    final state = cubit.state;
    final includeArchived = state is AdsAdminList && state.includeArchived;
    // Reload on return so backing out mid-edit (cubit left in a transient
    // upload/save state by the shared instance) restores the list, preserving
    // the archived filter (review Bug 1 + Gap 2).
    unawaited(
      Navigator.of(context)
          .push(
            MaterialPageRoute<void>(
              builder: (_) => BlocProvider<AdsAdminCubit>.value(
                value: cubit,
                child: AdEditorPage(ad: ad),
              ),
            ),
          )
          .then((_) => cubit.loadAds(includeArchived: includeArchived)),
    );
  }
}

/// Branded ad row — tinted-circle glyph + title + status chip on a hairline
/// surface (replaces the stock [Card]+[ListTile]).
class _AdListTile extends StatelessWidget {
  const _AdListTile({required this.ad, required this.onTap});

  final Ad ad;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return PressScale(
      child: AppSurface(
        radius: AppRadii.lg,
        onTap: onTap,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: AppSpacing.xxl + AppSpacing.lg,
              height: AppSpacing.xxl + AppSpacing.lg,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary.withValues(alpha: 0.12),
              ),
              child: Icon(
                LucideIcons.megaphone,
                color: colors.primary,
                size: AppSpacing.xl,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ad.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: styles.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AdStatusChip(ad.status),
                ],
              ),
            ),
            // Activate / Deactivate — not shown for archived ads
            if (ad.archivedAt == null) ...[
              IconButton(
                icon: Icon(
                  ad.isActive
                      ? LucideIcons.toggle_right
                      : LucideIcons.toggle_left,
                  color: ad.isActive ? colors.primary : colors.textMuted,
                ),
                tooltip: ad.isActive
                    ? l10n.adsAdminDeactivateTooltip
                    : l10n.adsAdminActivateTooltip,
                onPressed: () {
                  context.read<AdsAdminCubit>().setAdActive(
                    ad.id,
                    isActive: !ad.isActive,
                  );
                },
              ),
              // Archive (soft-delete)
              IconButton(
                icon: Icon(LucideIcons.archive, color: colors.error),
                tooltip: l10n.adsAdminArchiveTooltip,
                onPressed: () => _confirmArchive(context, ad),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmArchive(BuildContext context, Ad ad) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: LucideIcons.archive,
        variant: AppDialogVariant.destructive,
        title: l10n.adsAdminArchiveConfirmTitle,
        message: l10n.adsAdminArchiveConfirmBody(ad.title),
        cancelLabel: l10n.cancelLabel,
        actionLabel: l10n.adsAdminArchiveAction,
        onAction: () => Navigator.pop(ctx, true),
      ),
    );
    if (confirmed == true && context.mounted) {
      unawaited(context.read<AdsAdminCubit>().archiveAd(ad.id));
    }
  }
}

/// Shimmer placeholder rows shown while the ads list loads.
class _AdsListSkeleton extends StatelessWidget {
  const _AdsListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, __) => const SizedBox(
        height: AppSpacing.xxxl + AppSpacing.xxl,
        child: LoadingState.card(),
      ),
    );
  }
}
