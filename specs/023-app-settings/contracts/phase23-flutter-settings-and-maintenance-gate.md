# Contract: Flutter settings layer + maintenance gate + registration seeding

**Phase 23 · `lib/features/settings/**` + 4 amended files**

## Domain interface (FD — the shared symbol set FA & FC import)

```text
enum AppSettingKey { defaultLanguage, defaultCurrency, defaultPublisherNameVisibility,
                     defaultLocationVisibility, maintenanceMode, supportContact, termsUrl, privacyUrl }
                     // each exposes its wire `key` string

class AppSettings {                          // aggregate snapshot
  Locale  defaultLocale;
  String  defaultCurrency;
  ContactNameVisibility defaultPublisherNameVisibility;
  LocationVisibility    defaultLocationVisibility;
  MaintenanceState maintenance;              // { bool isOn; LocalizedText? message }
  SupportContact   supportContact;           // { String? phone, whatsapp, email; bool hasAny }
  String? termsUrl; String? privacyUrl;
  const AppSettings.safeDefaults();          // maintenance off, ar/SYP, empty contact/links (R-201)
}
class LocalizedText { String? ar; String? en; String? forLocale(Locale l); }

abstract class AppSettingsRepository {
  Future<Result<AppSettings>>      loadPublicSettings();
  Future<Result<List<AppSetting>>> loadAllSettings();
  Future<Result<AppSetting>>       updateSetting(AppSettingKey key, Object value);
}
// use cases: LoadPublicSettings, LoadAllSettings, UpdateSetting
```

## FA — admin editor (consumes FD)

- `AppSettingsEditorCubit` → `LoadAllSettings` / `UpdateSetting`.
- `AppSettingsEditorPage`: toggle (`maintenance_mode.on`), pickers (`default_language`, `default_currency` via pre-existing `ListCurrencies(activeOnly: true)`, both visibility defaults), validated text (`support_contact.*`, `terms_url`, `privacy_url`, bilingual `maintenance_mode.message`).
- Route: `AppRoutes.adminSettings = '/admin/settings'` + a `GoRoute` in `buildAppRouter()`.
- Dashboard: `dashboard_sections.dart` Settings tile `comingSoon` → active, gated by `PermissionKeys.settingsManage`.

## FC — consumer + maintenance gate (consumes FD)

- `AppSettingsCubit.load()` at app-start + on `AppLifecycleState.resumed`; holds `AppSettings current`; exposes `bool get maintenanceActive`; serves `AppSettings.safeDefaults()` on load failure (**fetch-failure ⇒ maintenance OFF, app runs, no crash** — R-201).
- `maintenance_gate.dart`: composed into the **existing global `redirect`** in `app_router.dart`. Behavior:
  - `maintenanceActive == false` → no redirect.
  - `maintenanceActive == true` AND `getIt<PermissionChecker>().has(PermissionKeys.settingsManage)` → **bypass** (no redirect).
  - `maintenanceActive == true` AND not settings.manage (incl. anonymous) → redirect to `MaintenanceScreen`.
- `MaintenanceScreen`: localized title + active-locale custom message (`LocalizedText.forLocale`, fallback to built-in copy) + `SupportContact` affordances + **retry** → `AppSettingsCubit.load()`.
- `AboutSupportPage`/section: renders set `support_contact` channels + `terms_url`/`privacy_url`; omits unset ones (never a broken link).

## FC — registration seeding (amends `auth_repository_impl.dart`)

- On register, read `LoadPublicSettings()` and seed the new user's `user_preferences.locale` from `default_language` and `display_currency` from `default_currency`, via the **pre-existing** `ProfileRepository` preferences path — replacing the current `updateLocale(deviceLocale)`-only seed (R-203, FR-007). Forward-only: existing users untouched.

## Invariants

- FA and FC import **only FD's domain symbols** + pre-existing Phase 6/9/20 symbols — never each other.
- The maintenance gate is the single enforcement point; the bypass is exactly `settings.manage` (R-202).
- No `supabase_flutter` import under `lib/features/settings/domain/` (Principle IX).
