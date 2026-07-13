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

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/deep_link_aware_back_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/presentation/money_formatter.dart';
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
            AgencyVerificationLoading() => const AppSpinner.page(),
            AgencyVerificationError() => Center(
              child: Text(l10n.agency_generic_error),
            ),
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
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: appRadius(AppRadii.md),
              child: SizedBox(
                width: AppSpacing.xxxl,
                height: AppSpacing.xxxl,
                child: agency.logoPath != null && agency.logoPath!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: agency.logoPath!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _logoFallback(colors),
                      )
                    : _logoFallback(colors),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(agency.name, style: styles.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(
                        Icons.verified,
                        size: AppSpacing.lg,
                        color: colors.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        l10n.agency_verified_badge,
                        style: styles.labelMedium.copyWith(
                          color: colors.primary,
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
          Text(agency.description!, style: styles.bodyMedium),
        ],
        if (agency.phone != null && agency.phone!.isNotEmpty)
          _ContactRow(icon: Icons.phone_outlined, value: agency.phone!),
        if (agency.whatsapp != null && agency.whatsapp!.isNotEmpty)
          _ContactRow(icon: Icons.chat_outlined, value: agency.whatsapp!),
        if (agency.address != null && agency.address!.isNotEmpty)
          _ContactRow(icon: Icons.location_on_outlined, value: agency.address!),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.agency_manage_listings, style: styles.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        BlocBuilder<AgencyListingsBloc, AgencyListingsState>(
          builder: (context, state) {
            return switch (state) {
              AgencyListingsLoading() => const Padding(
                padding: EdgeInsetsDirectional.all(AppSpacing.lg),
                child: AppSpinner(),
              ),
              AgencyListingsError() => Text(l10n.agency_generic_error),
              AgencyListingsLoaded(:final items) =>
                items.isEmpty
                    ? Text(
                        l10n.agency_listings_empty,
                        style: styles.bodyMedium.copyWith(
                          color: colors.onSurfaceVariant,
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

  Widget _logoFallback(AppColors colors) {
    return ColoredBox(
      color: colors.surfaceVariant,
      child: Icon(Icons.business_outlined, color: colors.onSurfaceVariant),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: AppSpacing.lg, color: colors.onSurfaceVariant),
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
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
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
                borderRadius: appRadius(AppRadii.sm),
                child: SizedBox(
                  width: AppSpacing.xxxl,
                  height: AppSpacing.xxxl,
                  child: imagePath != null && imagePath.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imagePath,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              ColoredBox(color: colors.surfaceVariant),
                        )
                      : ColoredBox(
                          color: colors.surfaceVariant,
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: colors.onSurfaceVariant,
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
                      style: styles.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (amount != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        MoneyFormatter.formatAmount(
                          amount as num,
                          currency,
                          locale: Localizations.localeOf(context),
                        ),
                        style: styles.bodyMedium.copyWith(
                          color: colors.onSurfaceVariant,
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

}
