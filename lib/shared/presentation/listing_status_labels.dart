import '../../l10n/app_localizations.dart';

/// Localized labels for `public.listings.status`.
///
/// The database stores the status as a bare English key (`draft`, `approved`,
/// …) and some surfaces — notably the agency analytics breakdown — receive it
/// straight from an RPC rather than through the [ListingStatus] enum. Rendering
/// that key puts raw English in front of an Arabic-reading publisher, so it
/// goes through here instead.
///
/// The list matches the CHECK constraint on `listings.status`; an unknown key
/// falls back to itself rather than an empty string, so a future status added
/// server-side degrades to something visible instead of a blank row.
const List<String> kListingStatusKeys = <String>[
  'draft',
  'pending_review',
  'approved',
  'rejected',
  'paused',
  'sold',
  'rented',
  'expired',
  'deleted',
];

String listingStatusLabel(AppLocalizations l10n, String? key) => switch (key) {
  'draft' => l10n.listingStatusDraft,
  'pending_review' => l10n.listingStatusPendingReview,
  'approved' => l10n.listingStatusApproved,
  'rejected' => l10n.listingStatusRejected,
  'paused' => l10n.listingStatusPaused,
  'sold' => l10n.listingStatusSold,
  'rented' => l10n.listingStatusRented,
  'expired' => l10n.listingStatusExpired,
  'deleted' => l10n.listingStatusDeleted,
  _ => key ?? '',
};
