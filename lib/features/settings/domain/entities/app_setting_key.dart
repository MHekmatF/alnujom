/// Closed enum for the 8 catalog keys seeded in `public.app_settings`.
///
/// Each value carries its wire [key] string — the exact `TEXT PRIMARY KEY`
/// stored in the database (data-model §1.3).  Use [key] when building
/// datasource params (`'p_key': AppSettingKey.maintenanceMode.key`).
enum AppSettingKey {
  defaultLanguage('default_language'),
  defaultCurrency('default_currency'),
  defaultPublisherNameVisibility('default_publisher_name_visibility'),
  defaultLocationVisibility('default_location_visibility'),
  maintenanceMode('maintenance_mode'),
  // Plan A26 — days a listing stays public after approval or renewal (7–365).
  listingValidityDays('listing_validity_days'),
  supportContact('support_contact'),
  termsUrl('terms_url'),
  privacyUrl('privacy_url');

  const AppSettingKey(this.key);

  /// The wire string used as the DB primary key.
  final String key;

  /// Returns the [AppSettingKey] for a given wire [key] string, or `null` if
  /// the key is not part of the v1 catalog.
  static AppSettingKey? fromWireKey(String wireKey) {
    for (final k in values) {
      if (k.key == wireKey) return k;
    }
    return null;
  }
}
