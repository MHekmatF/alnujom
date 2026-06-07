// lib/features/search/presentation/widgets/recent_searches_panel.dart
//
// Phase 25 premium uplift — the "Recent searches" overlay shown when the
// search bar is focused + empty. Reads [RecentSearchesCubit]; tapping a row
// re-runs that query, the trailing ✕ removes nothing destructive beyond the
// list, and "Clear" wipes all recents. Token-clean + RTL-safe.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/recent_searches_cubit.dart';

class RecentSearchesPanel extends StatelessWidget {
  const RecentSearchesPanel({super.key, required this.onSelected});

  /// Invoked with the chosen query when the user taps a recent row.
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Material(
      color: colors.surface,
      child: BlocBuilder<RecentSearchesCubit, RecentSearchesState>(
        builder: (context, state) {
          if (!state.loaded) {
            return const SizedBox.shrink();
          }
          if (state.queries.isEmpty) {
            return EmptyState(
              icon: LucideIcons.history,
              headline: l10n.search_recent_empty_title,
              body: l10n.search_recent_empty_subtitle,
            );
          }
          return ListView(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: AppSpacing.sm,
            ),
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.search_recent_title,
                        style: styles.labelLarge.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          context.read<RecentSearchesCubit>().clear(),
                      child: Text(l10n.search_recent_clear_all),
                    ),
                  ],
                ),
              ),
              for (final query in state.queries)
                ListTile(
                  leading: Icon(
                    LucideIcons.clock,
                    size: AppSpacing.lg,
                    color: colors.textMuted,
                  ),
                  title: Text(
                    query,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: styles.bodyLarge,
                  ),
                  trailing: Icon(
                    LucideIcons.arrow_up_left,
                    size: AppSpacing.lg,
                    color: colors.textMuted,
                  ),
                  onTap: () => onSelected(query),
                ),
            ],
          );
        },
      ),
    );
  }
}
