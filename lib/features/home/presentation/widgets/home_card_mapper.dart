import 'dart:ui' show Locale;

import '../../../../core/widgets/ds/ds_listing_card_data.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/domain/value_objects/money.dart';
import '../../../../shared/presentation/deed_finish_labels.dart';
import '../../../../shared/presentation/money_formatter.dart';
import '../../../../shared/util/location_line.dart';
import '../../../currencies/domain/entities/currency.dart';
import '../../domain/entities/home_listing_card.dart';

/// Maps a [HomeListingCard] read-model into the presentation-only
/// [DsListingCardData] the unified [DsListingCard] renders.
///
/// Shared by the Home feed rows, the Home featured rail, and any other surface
/// that shows a [HomeListingCard] — so the price resolution, location line and
/// verification slots stay identical everywhere the card appears.
DsListingCardData homeCardToData(
  HomeListingCard card,
  Map<String, Currency> currenciesByCode,
  Locale locale,
  AppLocalizations l10n,
) {
  final currency = currenciesByCode[card.primaryPrice.currencyCode];
  final priceText = currency == null
      ? '${card.primaryPrice.amount} ${card.primaryPrice.currencyCode}'
      : MoneyFormatter.format(
          Money(
            amount: card.primaryPrice.amount,
            currencyCode: card.primaryPrice.currencyCode,
          ),
          locale: locale,
          currency: currency,
        );
  final location = listingLocationLine(
    governorate: card.governorateNameLocalized,
    city: card.cityNameLocalized,
    area: card.areaNameLocalized,
  );
  return DsListingCardData(
    id: card.id,
    title: card.title,
    priceText: priceText,
    purpose: card.purpose,
    locationText: location.isEmpty ? '—' : location,
    imageUrl: card.mainImageUrl,
    rooms: card.rooms,
    bathrooms: card.bathrooms,
    areaSize: card.areaSize,
    isFeatured: card.isFeatured,
    agencyId: card.agencyId,
    agencyName: card.agencyName,
    agencyLogoUrl: card.agencyLogoUrl,
    publishedAt: card.publishedAt,
    isVerified: card.isVerified,
    deedLabel: card.deedType == null ? null : deedTypeLabel(l10n, card.deedType),
    whatsappPhone: card.whatsapp ?? card.phone,
  );
}
