import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/property_specs.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/domain/value_objects/money.dart';
import '../../../../shared/presentation/money_formatter.dart';
import '../../../currencies/domain/entities/currency.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../../../listing_form/domain/entities/listing_form_state.dart';
import '../../../locations/domain/entities/area.dart';
import '../../../locations/domain/entities/governorate.dart';
import '../../domain/entities/publisher_listing.dart';
import '../bloc/my_listings_bloc.dart';
import '../bloc/my_listings_event.dart';
import '../bloc/my_listings_state.dart';
import 'read_only_listing_preview.dart';
import 'rejection_reason_block.dart';
import 'resubmit_cta.dart';
import 'status_badge.dart';

/// Window (in days) before `expires_at` within which a listing surfaces the
/// expiry warning + Renew CTA on its card.
const int _kExpiryWarningDays = 7;

/// Number of days a single renew extends `expires_at` by (matches the RPC
/// default).
const int _kRenewDays = 30;

/// Per `contracts/my-listings-page.md § Listing card`. Tap behaviour:
/// editable status → form; non-editable → read-only preview.
class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.publisherListing,
    required this.currenciesByCode,
    required this.governoratesById,
    required this.areasById,
    this.hideLegacyRejectionBlock = false,
  });

  final PublisherListing publisherListing;
  final Map<String, Currency> currenciesByCode;
  final Map<String, Governorate> governoratesById;
  final Map<String, Area> areasById;

  /// When true (Phase 12 / US2 — `_ListingRow` sets this for rejected
  /// listings), the legacy Phase 10 `RejectionReasonBlock` + `ResubmitCta`
  /// in-card section is suppressed. The Phase 12 `RejectionReasonBanner`
  /// rendered above the card already exposes the preset + detail + Resubmit
  /// + View moderation history in a localised, JSON-aware form. Showing
  /// both leaks the raw JSON-encoded reason text to the publisher.
  final bool hideLegacyRejectionBlock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final listing = publisherListing.listing;
    final price = publisherListing.primaryPrice;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: InkWell(
        onTap: () => _onTap(context),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      listing.title.isEmpty
                          ? l10n.myListingsEmptyTitle
                          : listing.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusBadge(status: listing.status),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (price != null)
                Text(
                  _formatPrice(price.amount, price.currencyCode, locale),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              const SizedBox(height: AppSpacing.xs),
              if (_locationLabel(locale).isNotEmpty)
                Text(
                  _locationLabel(locale),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              if (PropertySpecsRow.hasAnyOf(
                rooms: listing.rooms,
                bathrooms: listing.bathrooms,
                areaSize: listing.areaSize,
              )) ...[
                const SizedBox(height: AppSpacing.sm),
                PropertySpecsRow(
                  rooms: listing.rooms,
                  bathrooms: listing.bathrooms,
                  areaSize: listing.areaSize,
                  color: AppColors.of(context).textMuted,
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Text(
                _formatDate(listing.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              _ExpirySection(listing: listing),
              if (publisherListing.hasRejectionReason &&
                  !hideLegacyRejectionBlock) ...[
                const SizedBox(height: AppSpacing.md),
                RejectionReasonBlock(
                  reason: publisherListing.latestStatusHistoryEntry!.reason!,
                ),
                const SizedBox(height: AppSpacing.sm),
                ResubmitCta(listingId: listing.id),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatPrice(Decimal amount, String code, Locale locale) {
    final currency = currenciesByCode[code];
    if (currency == null) {
      return '$amount $code';
    }
    return MoneyFormatter.format(
      Money(amount: amount, currencyCode: code),
      locale: locale,
      currency: currency,
    );
  }

  String _locationLabel(Locale locale) {
    final listing = publisherListing.listing;
    final govName = listing.governorateId == null
        ? null
        : governoratesById[listing.governorateId!]?.localizedName(locale);
    final areaName = listing.areaId == null
        ? null
        : areasById[listing.areaId!]?.localizedName(locale);
    final parts = <String>[
      if (govName != null && govName.isNotEmpty) govName,
      if (areaName != null && areaName.isNotEmpty) areaName,
    ];
    return parts.join(' • ');
  }

  String _formatDate(DateTime when) {
    final y = when.year.toString().padLeft(4, '0');
    final m = when.month.toString().padLeft(2, '0');
    final d = when.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  void _onTap(BuildContext context) {
    final listing = publisherListing.listing;
    if (publisherListing.isEditable) {
      context.goNamed(
        AppRouteNames.publisherListingsEdit,
        pathParameters: {'id': listing.id},
        extra: ListingFormMode.edit,
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ReadOnlyListingPreview(publisherListing: publisherListing),
        ),
      );
    }
  }
}

/// Renders the expiry indicator (when the listing is expired or expiring soon)
/// plus a Renew CTA. Hidden entirely when `expiresAt` is null or far off.
class _ExpirySection extends StatelessWidget {
  const _ExpirySection({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final info = _ExpiryInfo.from(listing.expiresAt);
    if (info == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final palette = AppColors.of(context);
    final color = info.expired ? palette.error : palette.warning;
    final label = info.expired
        ? l10n.myListingsExpiredLabel
        : l10n.myListingsExpiresInDays(info.daysLeft);

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.clock_alert, size: AppSpacing.lg, color: color),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          BlocSelector<MyListingsBloc, MyListingsState, bool>(
            selector: (state) => state.renewingId == listing.id,
            builder: (context, renewing) {
              return Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppButton(
                  label: l10n.myListingsRenewButton,
                  variant: AppButtonVariant.outlined,
                  size: AppButtonSize.dense,
                  icon: LucideIcons.refresh_cw,
                  loading: renewing,
                  onPressed: () => context.read<MyListingsBloc>().add(
                    MyListingsRenewRequested(listing.id, days: _kRenewDays),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Derived expiry classification for a listing's `expires_at`. Returns null
/// when there is nothing to surface (no expiry, or still far off).
class _ExpiryInfo {
  const _ExpiryInfo({required this.expired, required this.daysLeft});

  final bool expired;

  /// Whole days remaining until expiry (>= 0). Meaningless when [expired].
  final int daysLeft;

  static _ExpiryInfo? from(DateTime? expiresAt) {
    if (expiresAt == null) return null;
    final now = DateTime.now().toUtc();
    final exp = expiresAt.toUtc();
    if (!exp.isAfter(now)) {
      return const _ExpiryInfo(expired: true, daysLeft: 0);
    }
    final remaining = exp.difference(now);
    if (remaining.inDays > _kExpiryWarningDays) return null;
    // Round up so e.g. 6.3 days reads as "ينتهي خلال 7 أيام"; a future-but-
    // sub-24h expiry still reads as at least 1 day rather than 0.
    final days = (remaining.inHours + 23) ~/ 24;
    return _ExpiryInfo(expired: false, daysLeft: days < 1 ? 1 : days);
  }
}
