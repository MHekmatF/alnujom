import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/elevation.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/domain/value_objects/money.dart';
import '../../../../shared/presentation/money_formatter.dart';
import '../../../currencies/domain/entities/currency.dart';
import '../../../search/domain/entities/filter_state.dart';
import '../../domain/entities/home_listing_card.dart';

/// Phase 035 (Home revamp) — a horizontal rail of field-verified listings
/// ("عقارات موثّقة"), reinforcing the trust positioning. Derived from the
/// loaded home feed (no extra query); hides itself when there are none. "عرض
/// الكل" opens Search restricted to verified listings.
class HomeVerifiedRail extends StatelessWidget {
  const HomeVerifiedRail({
    required this.listings,
    required this.currenciesByCode,
    super.key,
  });

  final List<HomeListingCard> listings;
  final Map<String, Currency> currenciesByCode;

  @override
  Widget build(BuildContext context) {
    final verified = listings.where((l) => l.isVerified).toList();
    if (verified.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                LucideIcons.badge_check,
                color: colors.verified,
                size: AppSpacing.xl,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.home_verified_rail_title,
                  style: styles.titleLarge,
                ),
              ),
              InkWell(
                borderRadius: appRadius(AppRadii.pill),
                onTap: () => context.go(
                  AppRoutes.search,
                  extra: const FilterState(verifiedOnly: true),
                ),
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: kAppMinTouchTarget,
                  ),
                  alignment: AlignmentDirectional.center,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  child: Text(
                    l10n.home_see_all,
                    style: styles.labelLarge.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: MediaQuery.textScalerOf(context).scale(214),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
            ),
            itemCount: verified.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, i) => _RailCard(
              card: verified[i],
              priceText: _price(verified[i], context),
            ),
          ),
        ),
      ],
    );
  }

  String _price(HomeListingCard card, BuildContext context) {
    final currency = currenciesByCode[card.primaryPrice.currencyCode];
    if (currency == null) {
      return '${card.primaryPrice.amount} ${card.primaryPrice.currencyCode}';
    }
    return MoneyFormatter.format(
      Money(
        amount: card.primaryPrice.amount,
        currencyCode: card.primaryPrice.currencyCode,
      ),
      locale: Localizations.localeOf(context),
      currency: currency,
    );
  }
}

class _RailCard extends StatelessWidget {
  const _RailCard({required this.card, required this.priceText});

  final HomeListingCard card;
  final String priceText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);

    return PressScale(
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: appRadius(AppRadii.lg),
          border: Border.all(color: colors.outline),
          boxShadow: elevation.level1,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => context.go(AppRoutes.listingDetailsFor(card.id)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    SizedBox(
                      height: 120,
                      child: AppNetworkImage(
                        url: card.mainImageUrl,
                        semanticLabel: l10n.image_unavailable,
                      ),
                    ),
                    PositionedDirectional(
                      top: AppSpacing.sm,
                      start: AppSpacing.sm,
                      child: StatusPill(
                        label: l10n.detail_verified_badge,
                        color: colors.verified,
                        foreground: colors.onSuccess,
                        icon: LucideIcons.badge_check,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        priceText,
                        textDirection: TextDirection.ltr,
                        style: styles.priceMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        card.title.isEmpty ? '—' : card.title,
                        style: styles.labelLarge.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        _location(card),
                        style: styles.labelMedium.copyWith(
                          color: colors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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

  String _location(HomeListingCard c) {
    final parts = <String>[
      if (c.governorateNameLocalized.isNotEmpty &&
          c.governorateNameLocalized != '—')
        c.governorateNameLocalized,
      if (c.cityNameLocalized.isNotEmpty && c.cityNameLocalized != '—')
        c.cityNameLocalized,
    ];
    return parts.isEmpty ? '—' : parts.join(' · ');
  }
}
