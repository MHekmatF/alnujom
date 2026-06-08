// lib/features/agency/presentation/pages/agency_profile_page.dart
//
// Phase 19 (spec/019-agencies) Sub-Phase H (T055).
// Public /agency/:id page: name + logo + contact + verified badge + the
// agency's approved listings (via LoadAgencyListings → v_listings_public).
// v_agencies returns approved agencies to anyone; a non-approved id resolves
// to a not-found body. Phase 2 tokens only; all strings via AppLocalizations.
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
import '../../domain/entities/agency.dart';
import '../../domain/entities/agency_status.dart';
import '../bloc/agency_listings_bloc.dart';
import '../bloc/agency_verification_cubit.dart';

/// Public agency profile. Reuses [AgencyVerificationCubit] only as a lightweight
/// loader for the single agency (via LoadAgencyById) — it shares that use case.
class AgencyProfilePage extends StatelessWidget {
  const AgencyProfilePage({super.key, required this.agencyId});

  final String agencyId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AgencyVerificationCubit>(
          create: (_) => getIt<AgencyVerificationCubit>()..load(agencyId),
        ),
        BlocProvider<AgencyListingsBloc>(
          create: (_) =>
              getIt<AgencyListingsBloc>()..add(AgencyListingsOpened(agencyId)),
        ),
      ],
      child: _AgencyProfileView(agencyId: agencyId),
    );
  }
}

class _AgencyProfileView extends StatelessWidget {
  const _AgencyProfileView({required this.agencyId});

  final String agencyId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: const DeepLinkAwareBackButton(),
        title: Text(l10n.agency_profile_title),
      ),
      body: BlocBuilder<AgencyVerificationCubit, AgencyVerificationState>(
        builder: (context, state) {
          return switch (state) {
            AgencyVerificationLoading() =>
              const Center(child: CircularProgressIndicator()),
            AgencyVerificationError() =>
              Center(child: Text(l10n.agency_generic_error)),
            AgencyVerificationReady(:final agency) =>
              agency.status == AgencyStatus.approved
                  ? _ProfileBody(agency: agency)
                  : Center(child: Text(l10n.agency_generic_error)),
          };
        },
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.agency});

  final Agency agency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: SizedBox(
                width: AppSpacing.xxxl,
                height: AppSpacing.xxxl,
                child: agency.logoPath != null && agency.logoPath!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: agency.logoPath!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _logoFallback(scheme),
                      )
                    : _logoFallback(scheme),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(agency.name, style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(Icons.verified, size: AppSpacing.lg, color: scheme.primary),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        l10n.agency_verified_badge,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (agency.description != null &&
            agency.description!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(agency.description!, style: theme.textTheme.bodyMedium),
        ],
        if (agency.phone != null && agency.phone!.isNotEmpty)
          _ContactRow(icon: Icons.phone_outlined, value: agency.phone!),
        if (agency.whatsapp != null && agency.whatsapp!.isNotEmpty)
          _ContactRow(icon: Icons.chat_outlined, value: agency.whatsapp!),
        if (agency.address != null && agency.address!.isNotEmpty)
          _ContactRow(icon: Icons.location_on_outlined, value: agency.address!),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.agency_manage_listings, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        BlocBuilder<AgencyListingsBloc, AgencyListingsState>(
          builder: (context, state) {
            return switch (state) {
              AgencyListingsLoading() => const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
              AgencyListingsError() => Text(l10n.agency_generic_error),
              AgencyListingsLoaded(:final items) => items.isEmpty
                  ? Text(
                      l10n.agency_listings_empty,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  : Column(
                      children: [
                        for (final row in items) _ListingRow(row: row),
                      ],
                    ),
            };
          },
        ),
      ],
    );
  }

  Widget _logoFallback(ColorScheme scheme) {
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.business_outlined, color: scheme.onSurfaceVariant),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: AppSpacing.lg, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _ListingRow extends StatelessWidget {
  const _ListingRow({required this.row});

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
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: id == null
            ? null
            : () => context.push(AppRoutes.listingDetailsFor(id)),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: SizedBox(
                  width: AppSpacing.xxxl,
                  height: AppSpacing.xxxl,
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
