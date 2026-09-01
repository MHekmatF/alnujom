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
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/press_scale.dart';
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

    return DcCrownScaffold(
      title: l10n.agency_profile_title,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.shellHome),
      ),
      body: BlocBuilder<AgencyVerificationCubit, AgencyVerificationState>(
        builder: (context, state) {
          return switch (state) {
            // Batch-2: full-screen spinner -> profile-shaped skeleton; the two
            // bare centred Texts -> the shared ErrorState (with a Retry that
            // re-calls the very same load).
            AgencyVerificationLoading() => const _ProfileSkeleton(),
            AgencyVerificationError() => ErrorState(
              title: l10n.agency_generic_error,
              onRetry: () =>
                  context.read<AgencyVerificationCubit>().load(agencyId),
            ),
            AgencyVerificationReady(:final agency) =>
              agency.status == AgencyStatus.approved
                  ? _ProfileBody(agency: agency)
                  : ErrorState(
                      title: l10n.agency_generic_error,
                      onRetry: () => context
                          .read<AgencyVerificationCubit>()
                          .load(agencyId),
                    ),
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
                        placeholder: (_, __) =>
                            ColoredBox(color: colors.surfaceVariant),
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
                  // Batch-2: the verified mark was a blue `Icons.verified`;
                  // the DS "one موثّق stamp" is the Lucide badge-check on the
                  // `verified` (green) trust token.
                  Row(
                    children: [
                      Icon(
                        LucideIcons.badge_check,
                        size: AppSpacing.lg,
                        color: colors.verified,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        l10n.agency_verified_badge,
                        style: styles.labelMedium.copyWith(
                          color: colors.verified,
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
        // Batch-2: Material glyphs -> the app's Lucide set.
        if (agency.phone != null && agency.phone!.isNotEmpty)
          _ContactRow(icon: LucideIcons.phone, value: agency.phone!),
        if (agency.whatsapp != null && agency.whatsapp!.isNotEmpty)
          _ContactRow(
            icon: LucideIcons.message_circle,
            value: agency.whatsapp!,
          ),
        if (agency.address != null && agency.address!.isNotEmpty)
          _ContactRow(icon: LucideIcons.map_pin, value: agency.address!),
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
              AgencyListingsError() => Text(
                l10n.agency_generic_error,
                style: styles.bodyMedium.copyWith(color: colors.error),
              ),
              AgencyListingsLoaded(:final items) =>
                items.isEmpty
                    ? Text(
                        l10n.agency_listings_empty,
                        style: styles.bodyMedium.copyWith(
                          color: colors.textMuted,
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
      child: Icon(LucideIcons.building_2, color: colors.textMuted),
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
    final styles = AppTextStyles.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
      child: MergeSemantics(
        child: Row(
          children: [
            Icon(icon, size: AppSpacing.lg, color: colors.textMuted),
            const SizedBox(width: AppSpacing.sm),
            // Batch-2: the value inherited the ambient DefaultTextStyle.
            Expanded(child: Text(value, style: styles.bodyLarge)),
          ],
        ),
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

    // Batch-2: the stock Material [Card]+[InkWell] became the DS [AppSurface]
    // under a [PressScale], matching the agency-listings and My-Reports rows.
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: PressScale(
        enabled: id != null,
        child: AppSurface(
          radius: AppRadii.lg,
          onTap: id == null
              ? null
              : () => context.push(AppRoutes.listingDetailsFor(id)),
          padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
          child: MergeSemantics(
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: appRadius(AppRadii.md),
                  child: SizedBox(
                    width: AppSpacing.xxxl,
                    height: AppSpacing.xxxl,
                    child: imagePath != null && imagePath.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imagePath,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                ColoredBox(color: colors.surfaceVariant),
                            errorWidget: (_, __, ___) => ColoredBox(
                              color: colors.surfaceVariant,
                              child: Icon(
                                LucideIcons.image_off,
                                color: colors.textMuted,
                              ),
                            ),
                          )
                        : ColoredBox(
                            color: colors.surfaceVariant,
                            child: Icon(
                              LucideIcons.image,
                              color: colors.textMuted,
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
                          style: styles.priceMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmer placeholder blocks shown while the public agency profile loads.
class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: const [
        Row(
          children: [
            SizedBox(
              width: AppSpacing.xxxl,
              height: AppSpacing.xxxl,
              child: LoadingState.card(),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(child: LoadingState.heading()),
          ],
        ),
        SizedBox(height: AppSpacing.lg),
        LoadingState.line(),
        SizedBox(height: AppSpacing.sm),
        LoadingState.line(),
        SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: AppSpacing.xxxl + AppSpacing.xl,
          child: LoadingState.card(),
        ),
        SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: AppSpacing.xxxl + AppSpacing.xl,
          child: LoadingState.card(),
        ),
      ],
    );
  }
}
