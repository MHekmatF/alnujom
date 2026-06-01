// Phase 21 (spec/021-ads-banners) — T025
// AdsListPage: admin list of ads with AdStatus chips + archived filter toggle
// + create FAB + per-row activate/deactivate + soft-delete (archive) actions.
// Route: /admin/ads (gated by requireAdsManageRedirect, T027).
// Mirrors AgencyQueuePage structure.
// Constitution IX: zero supabase_flutter imports.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/theme/spacing.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adsAdminListTitle),
        actions: [
          // Archived filter toggle
          BlocBuilder<AdsAdminCubit, AdsAdminState>(
            builder: (ctx, state) {
              final includeArchived =
                  state is AdsAdminList && state.includeArchived;
              return IconButton(
                icon: Icon(
                  includeArchived
                      ? Icons.archive
                      : Icons.archive_outlined,
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
      ),
      body: BlocConsumer<AdsAdminCubit, AdsAdminState>(
        listener: (ctx, state) {
          if (state is AdsAdminError) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text(state.failure.message)),
            );
          }
        },
        builder: (ctx, state) {
          if (state is AdsAdminLoading) {
            return const Center(child: CircularProgressIndicator());
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
                padding: const EdgeInsets.all(AppSpacing.lg),
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
          return const Center(child: CircularProgressIndicator());
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context),
        tooltip: l10n.adsAdminCreateTooltip,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openEditor(BuildContext context, {Ad? ad}) {
    final cubit = context.read<AdsAdminCubit>();
    final state = cubit.state;
    final includeArchived =
        state is AdsAdminList && state.includeArchived;
    // Reload on return so backing out mid-edit (cubit left in a transient
    // upload/save state by the shared instance) restores the list, preserving
    // the archived filter (review Bug 1 + Gap 2).
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BlocProvider<AdsAdminCubit>.value(
            value: cubit,
            child: AdEditorPage(ad: ad),
          ),
        ),
      ).then((_) => cubit.loadAds(includeArchived: includeArchived)),
    );
  }
}

class _AdListTile extends StatelessWidget {
  const _AdListTile({
    required this.ad,
    required this.onTap,
  });

  final Ad ad;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(ad.title, style: theme.textTheme.titleSmall),
        subtitle: AdStatusChip(ad.status),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Activate / Deactivate — not shown for archived ads
            if (ad.archivedAt == null) ...[
              IconButton(
                icon: Icon(
                  ad.isActive
                      ? Icons.toggle_on_outlined
                      : Icons.toggle_off_outlined,
                  color: ad.isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
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
                icon: Icon(
                  Icons.archive_outlined,
                  color: theme.colorScheme.error,
                ),
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
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adsAdminArchiveConfirmTitle),
        content: Text(l10n.adsAdminArchiveConfirmBody(ad.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.adsAdminArchiveAction),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      unawaited(context.read<AdsAdminCubit>().archiveAd(ad.id));
    }
  }
}
