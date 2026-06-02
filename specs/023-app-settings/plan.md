# Implementation Plan: App Settings (Phase 23)

**Branch**: `023-app-settings` (spec tracked via `.specify/feature.json` → `specs/023-app-settings`) | **Date**: 2026-06-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/023-app-settings/spec.md`

## Summary

Phase 23 ships the **app-wide settings layer**: a small, admin-tunable `app_settings` store that the rest of the app reads instead of hard-coding product defaults and operational switches. A super-admin (a holder of the existing `settings.manage` permission) edits a **closed v1 catalog** — default language, default currency, default publisher-name visibility, default exact-location visibility, **maintenance mode** (+ an optional bilingual `ar`/`en` message), **support contact** (structured: optional phone / WhatsApp / email), and terms / privacy links — through a typed editor reached from the Phase 20 dashboard's "Settings" tile (currently `comingSoon`). Every change is audited (the §9.4 "App settings changes (Phase 23)" action). The app **fetches the public settings on app-load + foreground-resume** (NOT Realtime — Phase 22's Realtime scope is unchanged), seeds a **new** user's `user_preferences` from the default language/currency **client-side at registration** (existing users untouched), pre-selects the visibility defaults on **new** listing forms, surfaces the support contact + terms/privacy links, and shows a localized **maintenance screen** when maintenance is on — with a `settings.manage`-only **bypass** so the operator who flips it on is never locked out. A failed settings fetch is **fail-open for availability, fail-safe for maintenance** (safe built-in defaults; never mistaken for maintenance-on; never a crash).

**Backend** (4 migrations, no Edge Function): one new table — `public.app_settings` (`key` PK, `value` JSONB, `description`, `is_public` BOOL, `updated_by`, `updated_at`) with RLS on, a **per-key** SELECT policy (`is_public OR current_user_has_permission('settings.manage')`), **all client writes REVOKEd**, a `set_app_setting(p_key, p_value)` SECURITY DEFINER RPC that re-checks `settings.manage` and UPSERTs, an AFTER-UPDATE **audit trigger** (`EXECUTE FUNCTION log_audit('settings.updated','value','key')`), an idempotent **seed** of the catalog defaults, and advisor hardening. **No** new permission key, **no** §9.1 change, **no** new Postgres extension, **no** Edge Function, **no** change to any existing table. **Frontend** (`lib/features/settings/**` — a new feature tree — plus 4 amended files): a Supabase-free `AppSettingsRepository` (domain) with an `AppSettingsDatasource` (data) over the table + RPC; an admin typed editor under `settings/admin/presentation/`; a non-admin consumer under `settings/presentation/` (an `AppSettingsCubit` fed at app-load, a `MaintenanceScreen`, and an about/support surface); a maintenance redirect hooked into the existing global `redirect` in `app_router.dart`; and the registration default-seeding. **Zero new dependencies** (unlike Phase 22) — Phase 23 is a pure schema + feature addition on the established stack.

## Technical Context

**Language/Version**: Dart 3.9+ / Flutter 3.35.2 (existing); PostgreSQL 15 (Supabase); PL/pgSQL. No Edge Function this phase.
**Primary Dependencies**: `supabase_flutter`, `flutter_bloc`, `get_it` + `injectable`, `go_router`, `equatable`, `intl` (ALL already present). **NO new dependency** — Phase 23 adds none (contrast Phase 22's `firebase_*`).
**Storage**: Supabase Postgres — **1 NEW table** (`app_settings`), **1 NEW SECURITY DEFINER RPC** (`set_app_setting`), **1 NEW trigger** (audit AFTER UPDATE) + reused `set_updated_at()`, **1 seed block**. Reuses the Phase 4 `log_audit()` trigger fn and the Phase 6 `current_user_has_permission(text)` predicate. NO new permission key, NO §9.1 change, NO change to `user_preferences`/`currencies`/`listings` schemas (FR-018).
**Testing**: Manual on-device verification — two devices for the maintenance toggle (Infinix Note 8 + Pixel 8 Pro AVD) per the no-new-tests MVP convention (memory `feedback_no_new_tests`, `feedback_avd_acceptable_qa`); SQL/RPC wire-level RLS checks (`SELECT * FROM app_settings`, deny-write from a non-`settings.manage` session, deny-read of a sensitive key); `flutter analyze` + the full CI linter suite (format / design-tokens / l10n-parity / l10n-literals / SDK-boundary — memory `project_wave_run_full_verify_suite`).
**Target Platform**: Android (minSdk per project); Arabic-first RTL + English LTR. NO iOS/Web (Principle XI).
**Project Type**: Mobile app (Flutter) + Supabase backend — the established two-tree layout.
**Performance Goals**: public-settings read is one bounded `SELECT` at app-load + on foreground-resume (no Realtime, no per-frame polling); the maintenance gate is evaluated from the in-memory `AppSettingsCubit` snapshot (no per-route network call); writes are a single definer-RPC round-trip. The "within ~1 minute" maintenance criterion is met by the foreground-resume re-fetch latency budget, NOT a tight poll.
**Constraints**: per-key public/sensitive read RLS (anonymous may read public keys; sensitive keys gated to `settings.manage`); ALL client writes REVOKEd, mutation only via the `set_app_setting` definer that re-checks `settings.manage` server-side (Principle III, checks-at-both-ends — FR-005/FR-015); every change audited (FR-006); defaults are **forward-only** (new users/listings only — FR-007/FR-008); seeding is **client-side at registration** (resolved 2026-06-02); maintenance bypass is **`settings.manage` only** (resolved 2026-06-02 — FR-010); fetch-failure is fail-open-for-availability / fail-safe-for-maintenance (FR-014); domain stays Supabase-free (Principle IX); "supported currencies" is NOT a setting — Phase 9 `currencies.is_active` owns it (resolved 2026-06-02).
**Scale/Scope**: 4 migrations; 1 Flutter feature tree (`lib/features/settings/` — domain + data + admin presentation + consumer presentation); 4 amended files (`app_router.dart`, `dashboard_sections.dart`, `auth_repository_impl.dart`, `app.dart`/`main.dart` bootstrap); 1 new admin route (`/admin/settings`); ~35 l10n keys (editor labels, maintenance screen, about/support) split across FA + FC.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First Development | ✅ Pass | spec.md + 5 clarifications complete before this plan; research / data-model / contracts / quickstart accompany it |
| II. Source-Controlled Backend | ✅ Pass | 4 migration files + `supabase/policies/app_settings_policies.sql` + `supabase/docs/app_settings.md` under `supabase/`; applied via Supabase MCP per `project_supabase_apply_via_mcp`; no Studio-only changes |
| III. Security-First Supabase | ✅ Pass | RLS on `app_settings`; per-key public/sensitive SELECT; ALL client writes REVOKEd; mutation only via `set_app_setting` definer re-checking `settings.manage`; AFTER-UPDATE audit trigger; checks-at-both-ends (FR-005/FR-015) |
| IV. Clean Architecture | ✅ Pass | `lib/features/settings/{domain,data,presentation,admin}`; `supabase_flutter` confined to `data/`; business rules (maintenance-gate decision, default-seeding, value validation) in use cases / cubits, not widgets |
| V. Arabic-First Localization | ✅ Pass | ~35 new keys in both ARBs (+ each mirrored in `_DebugAppLocalizations`); editor + maintenance screen + about localized; the maintenance custom message is a bilingual `ar`/`en` value rendered to the active locale (FR-011/FR-016) |
| VI. Theme System | ✅ Pass | Phase 2 tokens only; no inline hex/font/padding (FR-017); editor controls, maintenance screen, about surface, empty/error/loading states themed; four-combination correct |
| VII. Dynamic Roles & Permissions | ✅ Pass | Reuses the existing `settings.manage` (`PermissionKeys.settingsManage`); NO new permission key, NO §9.1 change (FR-018); settings changes are the §9.4 Phase 23 audited action; the maintenance bypass is a `settings.manage` permission check at both ends |
| VIII. Approval Workflow & Identity | ✅ Pass | No approval/identity mutation; the publisher-name + location visibility settings only change the **default pre-selection** on new listing forms, never an existing listing's stored visibility (FR-008) |
| IX. Future Backend Portability | ✅ Pass | `AppSettingsRepository` is an abstract interface in `domain/`; `supabase_flutter` only in `data/`; the maintenance gate + cubit consume domain entities, not Supabase types |
| X. Testable AI Workflow | ✅ Pass | Per-FR / per-SC verification map in data-model + quickstart; the plan's "supported currencies" setting is reconciled away (R-198) and the maintenance "within 1 minute / next foreground" wording is reconciled to fetch-on-resume (R-201), both recorded |
| XI. Android-First MVP | ✅ Pass | No iOS/Web; **no new dependency**; no platform config change |
| XII. No Hidden Decisions | ✅ Pass | 5 clarifications resolved in spec; every plan-time choice recorded as a locked decision (research R-197..R-205) with rejected alternatives |

**Gate result**: PASS — no violations. Phase 23 adds **no new dependency and no new extension**, so it returns to the Phase 19/21 "zero-new-deps" posture — no Complexity Tracking rows required.

## Project Structure

### Documentation (this feature)

```text
specs/023-app-settings/
├── plan.md              # This file
├── research.md          # Phase 0 — locked decisions R-197..R-205
├── data-model.md        # Phase 1 — full migration SQL + Dart entities + per-FR/SC map
├── quickstart.md        # Phase 1 — end-to-end manual verification recipe (two-device)
├── contracts/           # Phase 1 — 4 interface contracts
│   ├── phase23-app-settings-table.md
│   ├── phase23-set-app-setting-rpc-and-audit.md
│   ├── phase23-settings-seed-and-catalog.md
│   └── phase23-flutter-settings-and-maintenance-gate.md
├── checklists/
│   └── requirements.md  # spec quality checklist (from /speckit-specify)
└── tasks.md             # Phase 2 — (/speckit-tasks)
```

### Source Code (repository root)

```text
lib/features/settings/                         # NEW — settings feature tree
├── domain/
│   ├── entities/        # AppSetting, AppSettingKey (enum), AppSettings (aggregate snapshot),
│   │                    #   MaintenanceState, SupportContact, LocalizedText, VisibilityDefault
│   ├── repositories/    # AppSettingsRepository (abstract)
│   └── usecases/        # LoadPublicSettings, LoadAllSettings, UpdateSetting
├── data/
│   ├── datasources/     # SupabaseAppSettingsDatasource (select app_settings + rpc set_app_setting)
│   ├── dtos/            # AppSettingDto
│   └── repositories/    # AppSettingsRepositoryImpl  (@LazySingleton(as: AppSettingsRepository))
├── admin/
│   └── presentation/
│       ├── bloc/        # AppSettingsEditorCubit  (FA)
│       ├── pages/       # AppSettingsEditorPage   (FA)
│       └── widgets/     # typed controls: toggle / picker / validated-text rows (FA)
└── presentation/        # non-admin consumer surface (FC)
    ├── bloc/            # AppSettingsCubit (app-wide snapshot, fed at app-load + on resume)
    ├── pages/           # MaintenanceScreen, AboutSupportPage (or section)
    └── widgets/         # maintenance_gate.dart (router redirect helper), support_contact_row.dart

lib/core/routing/
└── app_router.dart                            # AMENDED — (FA) GoRoute /admin/settings;
                                               #   (FC) maintenance branch composed into the global redirect

lib/features/admin/dashboard/presentation/widgets/
└── dashboard_sections.dart                    # AMENDED (FA) — Settings tile comingSoon → active + route

lib/features/auth/data/repositories/
└── auth_repository_impl.dart                  # AMENDED (FC) — seed new user's locale + display_currency
                                               #   from app_settings defaults at registration (replaces the
                                               #   current updateLocale(deviceLocale)-only seed)

lib/app.dart  (or lib/main.dart)               # AMENDED (FC) — provide AppSettingsCubit; kick the initial
                                               #   public-settings load + re-load on foreground resume

lib/l10n/{app_ar.arb, app_en.arb}             # AMENDED (FA + FC) — ~35 settings/maintenance/about keys
lib/core/localization/app_strings.dart         # AMENDED (FA + FC) — matching _DebugAppLocalizations overrides

supabase/migrations/
├── 20260602120014_create_app_settings.sql              # PB — table + RLS + per-key SELECT + REVOKE writes + index
├── 20260602120015_create_set_app_setting_rpc.sql       # PB — set_app_setting definer + grants + audit trigger
├── 20260602120016_seed_app_settings.sql                # PB — idempotent catalog defaults
└── 20260602120017_app_settings_advisor_hardening.sql   # PB — search_path / grant verification
supabase/policies/app_settings_policies.sql             # PB — checked-in policy SQL (mirrors the migration)
supabase/docs/app_settings.md                           # PB — per-table notes (RLS posture, keys, gotchas)
```

**Structure Decision**: Established two-tree layout (Flutter `lib/features/` + Supabase `supabase/`). The new `lib/features/settings/` tree mirrors the Clean-Arch shape of Phase 19 `agency/` / Phase 22 `notifications/`. The **admin editor** lives under `settings/admin/presentation/` (FA) and the **non-admin consumer** (maintenance screen, app-wide settings cubit, about/support) under `settings/presentation/` (FC) so the two Wave-2 phases occupy **disjoint subtrees** of the feature and contend only on the cross-cutting shared files (`app_router.dart`, the ARBs, `app_strings.dart`, `injection.config.dart`). Migration timestamps continue the series after the latest on disk (`20260602120013`), starting at `20260602120014`.

## Implementation Phases

> Phase 23 is one PR, decomposed into **four** implementation phases so `/wave` fans out **two wide waves**. The split is along the build-edge boundary: **PB** (all SQL) and **FD** (Flutter domain+data) implement the shared contract from `data-model.md`/`contracts/` and share NO Dart symbol, so they run in parallel; **FA** (admin editor UI + tile/route) and **FC** (maintenance gate + app-load fetch + registration seeding + about) each import FD's Dart symbols but not each other's, so they run in parallel after FD.

### PB — Backend: `app_settings` table, per-key RLS, `set_app_setting` definer RPC + audit trigger, seed, advisor hardening (4 migrations)
All SQL under `supabase/migrations/` (+ checked-in `policies/` + `docs/`). (1) **`app_settings`** — `key` TEXT PK, `value` JSONB NOT NULL, `description` TEXT, `is_public` BOOLEAN NOT NULL DEFAULT true, `updated_by` UUID (FK `auth.users`), `updated_at` TIMESTAMPTZ DEFAULT now(); RLS ON; SELECT policy `USING (is_public OR current_user_has_permission('settings.manage'))` (anon may read public keys); `REVOKE INSERT, UPDATE, DELETE ON public.app_settings FROM anon, authenticated` (writes only via RPC); reuse `set_updated_at()` BEFORE-UPDATE trigger. (2) **`set_app_setting(p_key TEXT, p_value JSONB)`** SECURITY DEFINER, `SET search_path = public, auth` — `IF NOT current_user_has_permission('settings.manage') THEN RAISE EXCEPTION` (re-check server-side); `UPDATE app_settings SET value = p_value, updated_by = auth.uid(), updated_at = now() WHERE key = p_key` (raise if no row — catalog keys are seeded, not client-created); RETURNS the updated row as JSONB; `REVOKE EXECUTE … FROM anon; GRANT EXECUTE … TO authenticated` (the function itself is the permission boundary). (3) **Audit trigger** — `CREATE TRIGGER trg_app_settings_audit AFTER UPDATE ON public.app_settings FOR EACH ROW EXECUTE FUNCTION log_audit('settings.updated', 'value', 'key')` (the §9.4 audited action; actor = `auth.uid()` seen through the definer). (4) **Seed** — idempotent `INSERT … ON CONFLICT (key) DO NOTHING` for the catalog: `default_language` (`"ar"`), `default_currency` (`"SYP"`), `default_publisher_name_visibility` (`"public"` per spec default), `default_location_visibility` (`"approximate"`), `maintenance_mode` (`{"on": false, "message": {"ar": null, "en": null}}`), `support_contact` (`{"phone": null, "whatsapp": null, "email": null}`), `terms_url` (`null`), `privacy_url` (`null`) — all `is_public = true`. (5) Advisor hardening (search_path on the new fn, grant audit). Apply in timestamp order via Supabase MCP; run `get_advisors` after.
**Touch fan**: `supabase/migrations/20260602120014..017_*.sql` (4 new files), `supabase/policies/app_settings_policies.sql` (new), `supabase/docs/app_settings.md` (new). No shared-repo-file contention.

### FD — Flutter settings domain + data + DI
Build `lib/features/settings/domain/` (entities: `AppSetting` [key, value, isPublic, updatedAt]; `AppSettingKey` enum [the 8 catalog keys]; `AppSettings` aggregate snapshot [typed getters: `defaultLocale`, `defaultCurrency`, `defaultPublisherNameVisibility`, `defaultLocationVisibility`, `maintenance` → `MaintenanceState`, `supportContact` → `SupportContact`, `termsUrl`, `privacyUrl`]; `MaintenanceState` [bool on, `LocalizedText? message`]; `SupportContact` [phone?, whatsapp?, email?]; `LocalizedText` [ar?, en? + `forLocale(Locale)`]; abstract `AppSettingsRepository` [`Future<Result<AppSettings>> loadPublicSettings()`, `Future<Result<List<AppSetting>>> loadAllSettings()`, `Future<Result<AppSetting>> updateSetting(AppSettingKey key, Object value)`]; use cases `LoadPublicSettings`, `LoadAllSettings`, `UpdateSetting`). Build `lib/features/settings/data/` (`AppSettingDto` ↔ entity; `SupabaseAppSettingsDatasource` — `_client.from('app_settings').select()` for reads and `_client.rpc('set_app_setting', params: {'p_key': …, 'p_value': …})` for writes, string-keyed per `contracts/`; `AppSettingsRepositoryImpl` `@LazySingleton(as: AppSettingsRepository)` returning `Result<T>`/`Failure`). Compiles + `flutter analyze`s WITHOUT the DB applied. Regenerate DI.
**Touch fan**: `lib/features/settings/domain/**`, `lib/features/settings/data/**` (new), `lib/core/di/injection.config.dart` (codegen).

### FA — Admin typed settings editor + dashboard tile + `/admin/settings` route + l10n
Build `lib/features/settings/admin/presentation/` (`AppSettingsEditorCubit` — load via `LoadAllSettings`, edit-in-place, validate per type, save via `UpdateSetting`; `AppSettingsEditorPage` — sectioned typed editor: toggle for `maintenance_mode.on`; pickers for `default_language` (`ar`/`en`) and `default_currency` (constrained to **active** Phase 9 currencies via `ListCurrencies(activeOnly: true)`) and the two visibility defaults; validated-text rows for `support_contact` (phone/WhatsApp/email), `terms_url`, `privacy_url`, and the bilingual `maintenance_mode.message` (ar + en); widgets for each control with localized validation messages). Register the route: `AppRoutes.adminSettings = '/admin/settings'` + `AppRouteNames.adminSettings` + a `GoRoute` in the authenticated/admin branch of `buildAppRouter()`. Flip the dashboard **Settings tile** in `dashboard_sections.dart` from `DashboardSectionState.comingSoon` to active with the new route target (still gated by `PermissionKeys.settingsManage`). Add the editor l10n keys to both ARBs + `_DebugAppLocalizations` + run gen-l10n. DI for the cubit.
**Touch fan**: `lib/features/settings/admin/**` (new), `lib/core/routing/app_router.dart`, `lib/features/admin/dashboard/presentation/widgets/dashboard_sections.dart`, `lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb`, `lib/core/localization/app_strings.dart`, `lib/l10n/app_localizations*.dart` (gen), `lib/core/di/injection.config.dart` (codegen).

### FC — App-wide consumption: maintenance gate + app-load/resume fetch + registration seeding + about/support
Build `lib/features/settings/presentation/` (`AppSettingsCubit` — holds the app-wide `AppSettings` snapshot; `load()` via `LoadPublicSettings` at app-start and on foreground resume; exposes `maintenanceActive` and a `safe-defaults` fallback when the load fails — FR-014; `MaintenanceScreen` — localized title + active-locale custom message (falls back to built-in copy) + `SupportContact` affordances + a retry that re-invokes `load()`; `AboutSupportPage`/section — renders the support contact channels + terms/privacy links, omitting unset ones; `maintenance_gate.dart` — a redirect helper composed into the existing global `redirect` in `app_router.dart` that sends non-`settings.manage` users to `MaintenanceScreen` when `maintenanceActive`, bypassing holders of `settings.manage` via `getIt<PermissionChecker>().has(PermissionKeys.settingsManage)`). Amend `app.dart`/`main.dart` to provide `AppSettingsCubit` above the router and trigger the initial load + a `WidgetsBindingObserver`/`AppLifecycleState.resumed` re-load. Amend `lib/features/auth/data/repositories/auth_repository_impl.dart` registration path to seed the new user's `locale` (default language) and `display_currency` (default currency) from `LoadPublicSettings()` (replacing the current `updateLocale(deviceLocale)`-only seed — FR-007). Add the maintenance/about l10n keys to both ARBs + `_DebugAppLocalizations` + run gen-l10n. DI for the cubit.
**Touch fan**: `lib/features/settings/presentation/**` (new), `lib/app.dart` (or `lib/main.dart`), `lib/core/routing/app_router.dart`, `lib/features/auth/data/repositories/auth_repository_impl.dart`, `lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb`, `lib/core/localization/app_strings.dart`, `lib/l10n/app_localizations*.dart` (gen), `lib/core/di/injection.config.dart` (codegen).

## Phase Dependencies

> Rule honored: every declared "B depends on A" names the exact file path AND the exported Dart symbol B consumes from A. A Dart datasource calling a Postgres RPC/table by **string name**, or SQL migrations sharing a database, are **runtime/DB contracts** — they compile and `flutter analyze` independently — so they are listed separately as "Runtime/DB contracts," NOT as build-order edges. Cross-phase edits to the same shared file (ARBs, `app_strings.dart`, `app_router.dart`, `injection.config.dart`) are **merge-contention** items handled by Touch-fan merge order, NOT build edges (no symbol crosses).

**Declared code dependencies (build/merge order edges):**

- **FA depends on FD** — `lib/features/settings/admin/presentation/bloc/app_settings_editor_cubit.dart` (FA) imports the abstract `AppSettingsRepository`, the use cases `LoadAllSettings` + `UpdateSetting`, and the entities `AppSetting` / `AppSettingKey` / `SupportContact` / `LocalizedText` / `MaintenanceState` — all defined under `lib/features/settings/domain/` by FD. `app_settings_editor_page.dart` consumes FD's `AppSettingKey` enum to render the typed rows. Without FD's symbols, FA does not compile.
- **FC depends on FD** — `lib/features/settings/presentation/bloc/app_settings_cubit.dart` (FC) imports the abstract `AppSettingsRepository`, the use case `LoadPublicSettings`, and the entities `AppSettings` / `MaintenanceState` / `SupportContact`; `maintenance_gate.dart` consumes the `AppSettings.maintenance` getter; and the FC amendment to `lib/features/auth/data/repositories/auth_repository_impl.dart` imports the `LoadPublicSettings` use case to read the default language/currency at registration. Without FD's symbols, FC does not compile.

**Runtime/DB contracts (NOT build-order edges — no named Dart symbol crosses the boundary):**

- FD's `SupabaseAppSettingsDatasource` calls the Postgres RPC `set_app_setting` and selects the `app_settings` table (created by PB) via `_client.rpc('set_app_setting', …)` / `_client.from('app_settings').select()` — runtime calls keyed by string, not Dart imports. FD compiles + `flutter analyze`s without PB applied. End-to-end verification (quickstart) requires PB applied.
- FC's `maintenance_gate.dart` consumes the **pre-existing** `PermissionChecker.has(String)` (Phase 6, `lib/core/security/permission_checker.dart`), `PermissionKeys.settingsManage` (Phase 6/20), and composes into the **pre-existing** global `redirect`/`buildAppRouter(...)` (Phase 1, `lib/core/routing/app_router.dart`) — NOT any FD-new or PB symbol.
- FA's currency picker consumes the **pre-existing** `ListCurrencies` use case + `Currency` entity (Phase 9, `lib/features/currencies/domain/`) and `PermissionKeys.settingsManage`; the dashboard-tile flip edits the **pre-existing** `DashboardSection` list (Phase 20) — pre-existing symbols, not FD-new.
- FC's registration seeding writes through the **pre-existing** `ProfileRepository` preferences path (Phase 5/9, `updateLocale` + the Phase 9 display-currency update) — a pre-existing symbol; FD supplies only the *values* (via `LoadPublicSettings`).
- Within PB, the audit trigger (`…015`) references `log_audit()` (Phase 4) and the seed (`…016`) targets the table (`…014`) — **DB apply-order** dependencies satisfied by migration timestamp order; internal to PB (one sub-agent, one ordered file set), not cross-phase edges.

**Self-audit**: Declared code deps = **2** (FA→FD, FC→FD). Deps lacking a named consumer = **0** — each names the consuming file(s) AND the imported symbol(s). PB has **0** inbound/outbound Dart edges (its only relationships are runtime contracts + internal DB apply-order). FD has **0** Dart edge to PB. FA and FC have **0** edge to each other — FA builds the admin editor (`settings/admin/**`) + amends `dashboard_sections.dart` and adds a `GoRoute`; FC builds the consumer (`settings/presentation/**`) + composes the maintenance branch into the global `redirect` and amends `auth_repository_impl.dart`. They both edit `app_router.dart` but in DISJOINT regions (FA adds a route to the route table; FC adds a redirect branch) and both add ARB keys — these are **merge-contention** items, NOT build edges; no symbol crosses FA↔FC. Graph is minimal — no over-conservative edges.

**Resulting execution waves:**

- **Wave 1 (parallel):** PB, FD — no Dart edge between them; both implement the shared `contracts/` interface.
- **Wave 2 (parallel):** FA, FC — each depends on FD only, not on each other.

**Merge-order guidance for `/wave`** (from Touch-fan overlap, not code edges): **FD → FA → FC** (FD first as both successors import it; FA/FC order between themselves is free, but FD must land first). Shared-file contention is between **FA and FC** on four files — `lib/core/routing/app_router.dart`, `lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb`, `lib/core/localization/app_strings.dart` — plus `lib/core/di/injection.config.dart` (regenerated by FD, FA, FC). The whichever-merges-second of FA/FC MUST rebase on the first, union-merge the ARBs + `app_strings.dart`, re-apply its disjoint `app_router.dart` edit, re-run `dart run build_runner build --delete-conflicting-outputs` to regenerate `injection.config.dart`, then re-run the full verify suite (`project_wave_run_full_verify_suite`) — **especially l10n-parity + the `_DebugAppLocalizations` override gate** (memory `project_l10n_debug_localizations_override`) after each ARB-touching phase. **PB merges independently** (touches only its 4 new migrations + new `policies/`+`docs/` files — no shared-file contention) but MUST be APPLIED via Supabase MCP (`project_supabase_apply_via_mcp`) before the quickstart's live verification of FD/FA/FC. Per `project_wave_worktree_base` + `project_wave_merge_cascade_gotchas`: brief sub-agents to `git reset --hard origin/023-app-settings` first, verify ancestry before merge, and re-anchor the orchestrator CWD to repo root before each merge.

## Complexity Tracking

No constitution violations, and — unlike Phase 22 — **no new dependency and no new Postgres extension**. Phase 23 is a single new table + one definer RPC + an audit trigger + a feature tree on the established stack, so there is nothing to justify here. (Table intentionally left empty.)

*Plan version: 1.0 | Generated by /speckit-plan | Aligned with constitution v1.0.0*
