# Phase 1 — Data Model: App Settings (Phase 23)

Source of truth for the migration SQL, the Dart domain entities, and the per-FR / per-SC verification map. All SQL is checked in under `supabase/migrations/` (Principle II) and applied via Supabase MCP in timestamp order (`project_supabase_apply_via_mcp`).

---

## 1. Backend (Supabase Postgres)

### 1.1 `20260602120014_create_app_settings.sql` — table + RLS + per-key SELECT + REVOKE writes

```sql
CREATE TABLE IF NOT EXISTS public.app_settings (
  key         TEXT PRIMARY KEY,
  value       JSONB NOT NULL,
  description TEXT,
  is_public   BOOLEAN NOT NULL DEFAULT true,
  updated_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Read: public keys readable by anyone (incl. anon); sensitive keys only by settings.manage holders (R-197).
GRANT SELECT ON public.app_settings TO anon, authenticated;
CREATE POLICY app_settings_select ON public.app_settings
  FOR SELECT
  USING (is_public OR public.current_user_has_permission('settings.manage'));

-- No direct client writes — mutation ONLY via set_app_setting() (R-199).
REVOKE INSERT, UPDATE, DELETE ON public.app_settings FROM anon, authenticated;

-- updated_at maintenance (reuse the Phase 4 helper).
CREATE TRIGGER trg_app_settings_set_updated_at
  BEFORE UPDATE ON public.app_settings
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
```

### 1.2 `20260602120015_create_set_app_setting_rpc.sql` — definer write RPC + grants + audit trigger

```sql
CREATE OR REPLACE FUNCTION public.set_app_setting(p_key TEXT, p_value JSONB)
RETURNS public.app_settings
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, auth AS $$
DECLARE
  v_row public.app_settings;
BEGIN
  -- Server-side re-check (checks-at-both-ends, Principle III).
  IF NOT public.current_user_has_permission('settings.manage') THEN
    RAISE EXCEPTION 'permission denied: settings.manage required' USING ERRCODE = '42501';
  END IF;

  UPDATE public.app_settings
     SET value = p_value, updated_by = auth.uid(), updated_at = now()
   WHERE key = p_key
  RETURNING * INTO v_row;

  -- Catalog keys are seeded, never client-created.
  IF NOT FOUND THEN
    RAISE EXCEPTION 'unknown app setting key: %', p_key USING ERRCODE = 'P0002';
  END IF;

  RETURN v_row;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.set_app_setting(TEXT, JSONB) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION public.set_app_setting(TEXT, JSONB) TO authenticated;

-- Audit every successful change — the §9.4 "App settings changes (Phase 23)" action (R-200).
CREATE TRIGGER trg_app_settings_audit
  AFTER UPDATE ON public.app_settings
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('settings.updated', 'value', 'key');
```

### 1.3 `20260602120016_seed_app_settings.sql` — idempotent catalog defaults

```sql
INSERT INTO public.app_settings (key, value, description, is_public) VALUES
  ('default_language',                  '"ar"'::jsonb,
     'Default UI language seeded to new users at registration', true),
  ('default_currency',                  '"SYP"'::jsonb,
     'Default display currency seeded to new users at registration', true),
  ('default_publisher_name_visibility', '"public"'::jsonb,
     'Default contact_name_visibility pre-selected on new listings', true),
  ('default_location_visibility',       '"approximate"'::jsonb,
     'Default location_visibility pre-selected on new listings', true),
  ('maintenance_mode',                  '{"on": false, "message": {"ar": null, "en": null}}'::jsonb,
     'App-wide maintenance gate + optional bilingual message', true),
  ('support_contact',                   '{"phone": null, "whatsapp": null, "email": null}'::jsonb,
     'Support contact channels surfaced in-app + on the maintenance screen', true),
  ('terms_url',                         'null'::jsonb, 'Terms-of-service URL',   true),
  ('privacy_url',                       'null'::jsonb, 'Privacy-policy URL',     true)
ON CONFLICT (key) DO NOTHING;
```

> **Seed defaults note**: `default_currency = "SYP"` and `default_language = "ar"` keep the Arabic-first / Syria-first posture; `default_currency` MUST be an **active** `currencies` row (Phase 9). `default_publisher_name_visibility = "public"` is intentional (the plan's "public-publisher-name default" — this is the listing *contact display name*, not a private legal-identity field, so it is **not** a Principle VIII concern). `default_location_visibility = "approximate"` is a deliberate **privacy-first** default (admins may raise it to `exact`). Both are values in the Phase 10 enums (`contact_name_visibility ∈ public/admin_only`, `location_visibility ∈ hidden/approximate/exact/admin_only`).

### 1.4 `20260602120017_app_settings_advisor_hardening.sql` — privilege tightening

```sql
REVOKE ALL ON public.app_settings FROM PUBLIC;
GRANT  SELECT ON public.app_settings TO anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.set_app_setting(TEXT, JSONB) FROM PUBLIC;
COMMENT ON TABLE public.app_settings IS
  'Admin-tunable app-wide settings (Phase 23). Per-key public/sensitive read; writes via set_app_setting() only.';
```

Run `get_advisors` after applying; expect no new SECURITY DEFINER search_path or RLS-disabled findings.

### 1.5 Catalog (the closed v1 set — value shapes)

| key | `value` shape | `is_public` | Consumed by |
|---|---|---|---|
| `default_language` | string `"ar"` \| `"en"` | true | FC registration seeding (FR-007) |
| `default_currency` | string (active currency code, e.g. `"SYP"`) | true | FC registration seeding (FR-007) |
| `default_publisher_name_visibility` | string `"public"` \| `"admin_only"` | true | new listing-form default (FR-008) |
| `default_location_visibility` | string `"hidden"`\|`"approximate"`\|`"exact"`\|`"admin_only"` | true | new listing-form default (FR-008) |
| `maintenance_mode` | `{ "on": bool, "message": { "ar": string\|null, "en": string\|null } }` | true | FC maintenance gate + screen (FR-009/FR-011) |
| `support_contact` | `{ "phone": string\|null, "whatsapp": string\|null, "email": string\|null }` | true | FC about/support + maintenance screen (FR-013) |
| `terms_url` | string\|null | true | FC about surface (FR-013) |
| `privacy_url` | string\|null | true | FC about surface (FR-013) |

No `supported_currencies` key (R-198). No sensitive (`is_public=false`) key is seeded in v1 (the column exists for forward use — R-197).

---

## 2. Frontend (Flutter — `lib/features/settings/`)

### 2.1 Domain entities (`domain/entities/`, Supabase-free — Principle IX)

- **`AppSetting`** — `String key`, `Object value` (decoded JSON), `bool isPublic`, `DateTime updatedAt`. One catalog row.
- **`AppSettingKey`** (enum) — `defaultLanguage`, `defaultCurrency`, `defaultPublisherNameVisibility`, `defaultLocationVisibility`, `maintenanceMode`, `supportContact`, `termsUrl`, `privacyUrl`; each carries its wire `key` string.
- **`AppSettings`** (aggregate snapshot) — typed getters parsed from the loaded rows: `Locale defaultLocale`, `String defaultCurrency`, `ContactNameVisibility defaultPublisherNameVisibility`, `LocationVisibility defaultLocationVisibility`, `MaintenanceState maintenance`, `SupportContact supportContact`, `String? termsUrl`, `String? privacyUrl`. Provides a `const AppSettings.safeDefaults()` factory (maintenance off, `ar`/`SYP`, empty contact/links) for the fetch-failure path (R-201).
- **`MaintenanceState`** — `bool isOn`, `LocalizedText? message`.
- **`SupportContact`** — `String? phone`, `String? whatsapp`, `String? email`; `bool get hasAny`.
- **`LocalizedText`** — `String? ar`, `String? en`; `String? forLocale(Locale locale)` (returns the active-locale value, else null).

### 2.2 Repository interface (`domain/repositories/app_settings_repository.dart`)

```text
abstract class AppSettingsRepository {
  Future<Result<AppSettings>>      loadPublicSettings();                 // public keys only (RLS)
  Future<Result<List<AppSetting>>> loadAllSettings();                    // settings.manage view (admin editor)
  Future<Result<AppSetting>>       updateSetting(AppSettingKey key, Object value); // → set_app_setting RPC
}
```

### 2.3 Use cases (`domain/usecases/`)

- `LoadPublicSettings` → `loadPublicSettings()` (consumed by FC's `AppSettingsCubit` + the registration seeding).
- `LoadAllSettings` → `loadAllSettings()` (consumed by FA's editor cubit).
- `UpdateSetting` → `updateSetting(key, value)` (consumed by FA's editor cubit).

### 2.4 Data layer (`data/`)

- **`AppSettingDto`** — `fromJson` (Supabase row) ↔ `AppSetting`; helpers to decode each `value` shape.
- **`SupabaseAppSettingsDatasource`** — `_client.from('app_settings').select()` (RLS returns public keys for non-admins, all keys for `settings.manage`); writes via `_client.rpc('set_app_setting', params: {'p_key': key.wire, 'p_value': value})`. Matches the Phase 9 currencies-datasource idiom.
- **`AppSettingsRepositoryImpl`** `@LazySingleton(as: AppSettingsRepository)` — maps DTOs → entities, exceptions → `Failure`, returns `Result<T>`.

### 2.5 Presentation

- **FA** — `AppSettingsEditorCubit` (`loadAll` / edit-in-place / `save`), `AppSettingsEditorPage`, typed control widgets. Currency picker uses the pre-existing Phase 9 `ListCurrencies(activeOnly: true)`.
- **FC** — `AppSettingsCubit` (`load()` at app-start + on `AppLifecycleState.resumed`; exposes `AppSettings current` + `bool get maintenanceActive`; serves `AppSettings.safeDefaults()` on failure), `MaintenanceScreen`, `AboutSupportPage`/section, `maintenance_gate.dart` (router redirect helper).

---

## 3. Per-FR verification map

| FR | Mechanism | Verification |
|---|---|---|
| FR-001 catalog store | `app_settings` table + 8-key seed (§1.1/1.3) | `SELECT key FROM app_settings ORDER BY key` returns exactly the 8 keys; no `supported_currencies` |
| FR-002 public/sensitive classification | `is_public` column + per-key SELECT policy (§1.1) | Anon `select` returns public keys; a seeded `is_public=false` row (test) is hidden from anon |
| FR-003 seeded defaults + checked-in | §1.3 seed + migrations under `supabase/` | Fresh DB after migrations has all 8 rows with sensible defaults |
| FR-004 settings.manage write at both ends | UI gate (FA) + `set_app_setting` re-check (§1.2) | Non-`settings.manage` `rpc('set_app_setting',…)` → `42501` denied |
| FR-005 writes restricted server-side | REVOKE writes + definer RPC (§1.1/1.2) | Direct `UPDATE app_settings` as `authenticated` → permission denied |
| FR-006 audit every change | `trg_app_settings_audit` → `log_audit` (§1.2) | After a save, `SELECT * FROM audit_logs WHERE action='settings.updated' ORDER BY created_at DESC LIMIT 1` shows actor + before/after |
| FR-007 default lang/currency seed new users, client-side | FC seeds at registration — `ProfileRepository.updateLocale` (lang) + Phase 9 `CurrenciesRepository.writeUserDisplayCurrency` (currency), values from `LoadPublicSettings` (R-203) | New account's `user_preferences` = current defaults; an existing user's preference unchanged after a default change |
| FR-008 visibility defaults pre-select new listings | new-listing initial state in `listing_form_bloc.dart` reads `AppSettings` defaults (FC) | New listing form pre-selects current defaults; existing listing visibility unchanged |
| FR-009 maintenance screen on all clients ~1 min | FC gate + foreground re-fetch (R-201) | Toggle on A → B shows screen on next foreground (≤~1 min) |
| FR-010 settings.manage bypass | `maintenance_gate.dart` checks `PermissionChecker.has('settings.manage')` (R-202) | settings.manage user keeps access; regular/other-admin/anon see the screen |
| FR-011 localized maintenance message | bilingual `message` + `LocalizedText.forLocale` (R-204) | ar viewer sees ar message; en viewer sees en; unset → built-in copy |
| FR-012 fetch-on-load + resume (not Realtime) | `AppSettingsCubit.load()` lifecycle hook (R-201) | No `app_settings` Realtime channel; resume triggers a re-fetch |
| FR-013 surface support contact + terms/privacy | FC about surface + maintenance screen (R-204) | Set values appear; unset channel/link is omitted, never a broken link |
| FR-014 fetch-failure fail-open/fail-safe | `AppSettings.safeDefaults()` (R-201) | Offline launch → app runs, NOT maintenance, no crash |
| FR-015 RLS public/sensitive + settings.manage write | §1.1/1.2 policies | Wire-level: anon reads public; non-admin denied sensitive; non-`settings.manage` denied write |
| FR-016 l10n editor + maintenance | ARB `ar`+`en` + `_DebugAppLocalizations` overrides | No raw literals; both locales present; debug override gate passes |
| FR-017 theming four combos | Phase 2 tokens (FA/FC widgets) | Editor + maintenance render correct in (light/dark)×(ar/en) |
| FR-018 bounded backend surface | 1 table + 1 RPC + 1 audit trigger; no new perm key; no other-table change | Structural grep (SC-010) |

## 4. Per-SC verification map

| SC | Verification (quickstart step) |
|---|---|
| SC-001 admin edit persists + audited | Step 3 — edit each control type; restart; check value + `audit_logs` |
| SC-002 maintenance ~1 min on/off two-device | Step 4 — toggle on A, observe B's next foreground; toggle off restores |
| SC-003 bypass matrix | Step 5 — settings.manage keeps access; regular/other-admin/anon blocked |
| SC-004 default currency/language new-users-only | Step 6 — existing pref unchanged; new account seeded |
| SC-005 listing visibility defaults forward-only | Step 7 — new listing pre-selected; existing unchanged |
| SC-006 wire-level write deny / sensitive read deny / public read | Step 8 — RPC deny from non-admin; anon reads public |
| SC-007 fetch-failure fail-open, not maintenance, no crash | Step 9 — offline launch on safe defaults |
| SC-008 four-combination render | Step 10 — editor + maintenance in 4 combos |
| SC-009 support/terms surfaced from settings | Step 11 — set in admin, appears in app next load; unset degrades |
| SC-010 structural/scope gate | Step 12 — grep: one table, no new perm key, no `supported_currencies`, no Supabase import in `domain/`, no iOS/Web |

*Data-model version: 1.0 | Phase 1*
