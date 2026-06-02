import 'dart:ui';

import 'package:alnujom/features/listing_form/domain/entities/listing.dart';

import 'maintenance_state.dart';
import 'support_contact.dart';

/// Aggregate snapshot of all public app settings loaded from the backend.
///
/// Typed getters decode the raw JSONB values stored in `public.app_settings`
/// (data-model §2.1).  All fields have sane fallbacks so callers never crash
/// on a partially-configured tenant.
///
/// **Fail-open path (R-201)**: `AppSettings.safeDefaults()` is returned by
/// `AppSettingsCubit` when the settings fetch fails — the app stays open,
/// maintenance mode is OFF, and default locale/currency use Arabic-first
/// Syria-first values.
class AppSettings {
  const AppSettings({
    required this.defaultLocale,
    required this.defaultCurrency,
    required this.defaultPublisherNameVisibility,
    required this.defaultLocationVisibility,
    required this.maintenance,
    required this.supportContact,
    this.termsUrl,
    this.privacyUrl,
  });

  /// Safe defaults for the fetch-failure (fail-open) path.
  ///
  /// Must be a `const` constructor so FC can use it in const contexts.
  const AppSettings.safeDefaults()
    : defaultLocale = const Locale('ar'),
      defaultCurrency = 'SYP',
      defaultPublisherNameVisibility = ContactNameVisibility.public,
      defaultLocationVisibility = LocationVisibility.approximate,
      maintenance = const MaintenanceState(isOn: false),
      supportContact = const SupportContact(),
      termsUrl = null,
      privacyUrl = null;

  /// Default UI locale seeded to new users at registration (FR-007).
  final Locale defaultLocale;

  /// Default display currency code seeded to new users at registration (FR-007).
  final String defaultCurrency;

  /// Default `contact_name_visibility` pre-selected on new listings (FR-008).
  final ContactNameVisibility defaultPublisherNameVisibility;

  /// Default `location_visibility` pre-selected on new listings (FR-008).
  final LocationVisibility defaultLocationVisibility;

  /// Current maintenance gate state (FR-009/FR-011).
  final MaintenanceState maintenance;

  /// Support contact channels surfaced in-app and on the maintenance screen
  /// (FR-013).
  final SupportContact supportContact;

  /// Terms-of-service URL, or null if not configured (FR-013).
  final String? termsUrl;

  /// Privacy-policy URL, or null if not configured (FR-013).
  final String? privacyUrl;

  @override
  String toString() => 'AppSettings('
      'defaultLocale: $defaultLocale, '
      'defaultCurrency: $defaultCurrency, '
      'maintenance: $maintenance'
      ')';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          runtimeType == other.runtimeType &&
          defaultLocale == other.defaultLocale &&
          defaultCurrency == other.defaultCurrency &&
          defaultPublisherNameVisibility ==
              other.defaultPublisherNameVisibility &&
          defaultLocationVisibility == other.defaultLocationVisibility &&
          maintenance == other.maintenance &&
          supportContact == other.supportContact &&
          termsUrl == other.termsUrl &&
          privacyUrl == other.privacyUrl;

  @override
  int get hashCode =>
      defaultLocale.hashCode ^
      defaultCurrency.hashCode ^
      defaultPublisherNameVisibility.hashCode ^
      defaultLocationVisibility.hashCode ^
      maintenance.hashCode ^
      supportContact.hashCode ^
      termsUrl.hashCode ^
      privacyUrl.hashCode;
}
