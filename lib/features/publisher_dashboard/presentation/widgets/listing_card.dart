import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/domain/value_objects/money.dart';
import '../../../../shared/presentation/money_formatter.dart';
import '../../../currencies/domain/entities/currency.dart';
import '../../../listing_form/domain/entities/listing_form_state.dart';
import '../../../locations/domain/entities/area.dart';
import '../../../locations/domain/entities/governorate.dart';
import '../../domain/entities/publisher_listing.dart';
import 'read_only_listing_preview.dart';
import 'rejection_reason_block.dart';
import 'resubmit_cta.dart';
import 'status_badge.dart';

/// Per `contracts/my-listings-page.md § Listing card`. Tap behaviour:
/// editable status → form; non-editable → read-only preview.
class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.publisherListing,
    required this.currenciesByCode,
    required this.governoratesById,
    required this.areasById,
  });

  final PublisherListing publisherListing;
  final Map<String, Currency> currenciesByCode;
  final Map<String, Governorate> governoratesById;
  final Map<String, Area> areasById;

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
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              const SizedBox(height: AppSpacing.xs),
              if (_locationLabel(locale).isNotEmpty)
                Text(
                  _locationLabel(locale),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _formatDate(listing.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              if (publisherListing.hasRejectionReason) ...[
                const SizedBox(height: AppSpacing.md),
                RejectionReasonBlock(
                  reason: publisherListing
                      .latestStatusHistoryEntry!.reason!,
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
          builder: (_) => ReadOnlyListingPreview(
            publisherListing: publisherListing,
          ),
        ),
      );
    }
  }
}
