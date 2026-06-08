// lib/features/agency/presentation/pages/agency_listings_page.dart
//
// Phase 19 (spec/019-agencies) Sub-Phase H (T057).
// Paginated list of the agency's listings (v_listings_public, approved-only).
// Mirrors MyReportsPage's RefreshIndicator + ListView + near-end load-more.
// Phase 2 tokens only; all strings via AppLocalizations.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/deep_link_aware_back_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../bloc/agency_listings_bloc.dart';

class AgencyListingsPage extends StatelessWidget {
  const AgencyListingsPage({super.key, required this.agencyId});

  final String agencyId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AgencyListingsBloc>(
      create: (_) =>
          getIt<AgencyListingsBloc>()..add(AgencyListingsOpened(agencyId)),
      child: _AgencyListingsView(agencyId: agencyId),
    );
  }
}

class _AgencyListingsView extends StatelessWidget {
  const _AgencyListingsView({required this.agencyId});

  final String agencyId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: const DeepLinkAwareBackButton(),
        title: Text(l10n.agency_listings_title),
      ),
      body: BlocBuilder<AgencyListingsBloc, AgencyListingsState>(
        builder: (context, state) {
          return switch (state) {
            AgencyListingsLoading() =>
              const Center(child: CircularProgressIndicator()),
            AgencyListingsError() =>
              Center(child: Text(l10n.agency_generic_error)),
            AgencyListingsLoaded(:final items, :final hasMore) => items.isEmpty
                ? Center(child: Text(l10n.agency_listings_empty))
                : _ListBody(agencyId: agencyId, items: items, hasMore: hasMore),
          };
        },
      ),
    );
  }
}

class _ListBody extends StatelessWidget {
  const _ListBody({
    required this.agencyId,
    required this.items,
    required this.hasMore,
  });

  final String agencyId;
  final List<Map<String, dynamic>> items;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        context
            .read<AgencyListingsBloc>()
            .add(AgencyListingsRefreshRequested(agencyId));
      },
      child: ListView.builder(
        itemCount: items.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= (items.length * 0.8).floor() && hasMore) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context
                  .read<AgencyListingsBloc>()
                  .add(AgencyListingsMoreLoaded(agencyId));
            });
          }
          if (index >= items.length) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _ListingCard(row: items[index]);
        },
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final id = row['id'] as String?;
    final title = (row['title'] as String?) ?? '';
    final amount = row['primary_amount'];
    final currency = (row['primary_currency'] as String?) ?? '';
    final imagePath = row['main_image_path'] as String?;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: InkWell(
        onTap: id == null
            ? null
            : () => context.push(AppRoutes.listingDetailsFor(id)),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: SizedBox(
                  width: AppSpacing.xxxl + AppSpacing.xl,
                  height: AppSpacing.xxxl + AppSpacing.xl,
                  child: imagePath != null && imagePath.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imagePath,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              ColoredBox(color: scheme.surfaceContainerHighest),
                        )
                      : ColoredBox(
                          color: scheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? '—' : title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (amount != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.priceWithCurrency(
                          _formatAmount(context, amount as num),
                          currency,
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Localized amount in the active locale's numerals (Arabic-Indic in ar),
  /// with no fractional part — mirrors the favorites/search card idiom.
  String _formatAmount(BuildContext context, num amount) {
    final fmt = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    )..maximumFractionDigits = 0;
    return fmt.format(amount);
  }
}
