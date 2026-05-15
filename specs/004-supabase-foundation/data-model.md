# Phase 1 Data Model — Supabase Foundation

This document captures the concrete shape of every Phase 4 backend artifact. The DDL fragments below are illustrative — final SQL lives in `supabase/migrations/`.

---

## Tables

### `profiles`

A user's server-side identity and operational-status record. Keyed by `auth.users.id` (one profile per auth user). Auto-provisioned by the `handle_new_auth_user()` trigger (R-07).

| Column | Type | Default | Nullable | Constraint | Notes |
|---|---|---|---|---|---|
| `user_id` | `UUID` | — | NO | `PRIMARY KEY`, `REFERENCES auth.users(id) ON DELETE CASCADE` | Same value as `auth.users.id`. |
| `full_name` | `TEXT` | NULL | YES | — | Filled by Phase 5's auth flow. |
| `username` | `TEXT` | NULL | YES | `UNIQUE` (NULL-distinct, Postgres default; Q4) | Filled by Phase 5. Multiple NULLs coexist. |
| `phone` | `TEXT` | NULL | YES | `UNIQUE` (NULL-distinct, Q4) | E.164 normalized by Phase 5. Multiple NULLs coexist. |
| `email` | `TEXT` | NULL | YES | — | Optional real email; password-reset uses it when set. |
| `avatar_url` | `TEXT` | NULL | YES | — | Filled by Phase 5+. |
| `account_status` | `account_status_enum` | `'pending'` | NO | — | Status changes audit-logged (R-04). |
| `publisher_status` | `publisher_status_enum` | `'pending'` | NO | — | Status changes audit-logged (R-04). |
| `created_at` | `TIMESTAMPTZ` | `now()` | NO | — | |
| `updated_at` | `TIMESTAMPTZ` | `now()` | NO | trigger updates on row change | Phase 4 ships the simple `updated_at = now()` trigger inline. |

**Deliberate omissions** (Q2): `preferred_language` and `preferred_currency` are NOT on `profiles`. `user_preferences.locale` and `user_preferences.display_currency` are canonical.

**Vault-backed columns** (per ADR-0001): `legal_name`, `national_id`, `private_contact_methods` — NOT introduced in Phase 4. Phase 5's `0008_profiles_vault_columns.sql` adds them on top of Phase 4's Vault scaffolding.

**RLS**: Enabled. Policies in `supabase/policies/profiles_policies.sql`:
- Self-read on all non-status columns.
- Admin-read on status columns (gated by `current_user_is_admin()`; Phase 4 evaluates to FALSE).
- Self-write on non-status, non-uniqueness-affecting columns.
- Admin-write on `account_status`, `publisher_status`.

**Audit triggers** (FR-010): `AFTER UPDATE OF account_status, publisher_status` → `log_audit('profile.status_changed', 'account_status,publisher_status', 'user_id')`. The third argument is the PK column name (per R-04); `profiles` uses `user_id` rather than `id` as the PK.

**Column-level enforcement trigger** (R-12, FR-006): `BEFORE UPDATE` → `enforce_profile_status_admin_only()`. Raises `42501 insufficient_privilege` if a non-privileged, non-admin caller attempts to change `account_status` or `publisher_status`. Privileged sessions (`postgres`, `supabase_admin`, `service_role`, `supabase_auth_admin`) bypass the check; authenticated users with `current_user_is_admin() = TRUE` also bypass.

**`updated_at` trigger**: `BEFORE UPDATE` → `set_updated_at()` (sets `NEW.updated_at := now()`).

---

### `user_preferences`

A user's account-level preferences. Keyed by `user_id` (one row per auth user). Auto-provisioned by the same trigger that creates the profile (R-07). Self-only RLS.

| Column | Type | Default | Nullable | Constraint | Notes |
|---|---|---|---|---|---|
| `user_id` | `UUID` | — | NO | `PRIMARY KEY`, `REFERENCES auth.users(id) ON DELETE CASCADE` | |
| `locale` | `TEXT` | `'ar'` | NO | `CHECK (locale IN ('ar','en'))` | Source of truth for locale (Q2). |
| `theme_mode` | `TEXT` | `'system'` | NO | `CHECK (theme_mode IN ('system','light','dark'))` | Mirrors Flutter `ThemeMode`. |
| `display_currency` | `TEXT` | `'SYP'` | NO | — | Free-form text in Phase 4; FK to `currencies(code)` lands in Phase 9. |
| `notifications_enabled` | `BOOLEAN` | `TRUE` | NO | — | |
| `created_at` | `TIMESTAMPTZ` | `now()` | NO | — | |
| `updated_at` | `TIMESTAMPTZ` | `now()` | NO | trigger | |

**RLS**: Enabled. Policies in `supabase/policies/user_preferences_policies.sql`:
- Self-only read (`USING (auth.uid() = user_id)`).
- Self-only write — `INSERT WITH CHECK (auth.uid() = user_id)`, `UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id)`.
- No admin policy in Phase 4 (FR-007).

**Audit triggers**: None in Phase 4 (`user_preferences` changes are not audit-relevant per §6.4 of the implementation plan).

---

### `audit_logs`

Append-only record of admin-relevant changes. Written exclusively by the `log_audit()` trigger function. Admin-readable only.

| Column | Type | Default | Nullable | Constraint | Notes |
|---|---|---|---|---|---|
| `id` | `UUID` | `gen_random_uuid()` | NO | `PRIMARY KEY` | R-11. |
| `actor_user_id` | `UUID` | NULL | YES | `REFERENCES auth.users(id) ON DELETE SET NULL` | NULL for system/trigger-context writes. |
| `action` | `TEXT` | — | NO | — | E.g., `'profile.status_changed'`, `'role.permission_added'`. |
| `target_type` | `TEXT` | — | NO | — | Table name (e.g., `'profiles'`). |
| `target_id` | `TEXT` | NULL | YES | — | TEXT to support UUID, BIGINT, composite-key targets uniformly. |
| `before_state` | `JSONB` | NULL | YES | — | OLD column subset captured by the trigger args. |
| `after_state` | `JSONB` | NULL | YES | — | NEW column subset captured by the trigger args. |
| `ip` | `INET` | NULL | YES | — | NULL in Phase 4; Edge Functions populate from Phase 7+. |
| `user_agent` | `TEXT` | NULL | YES | — | NULL in Phase 4; Edge Functions populate from Phase 7+. |
| `created_at` | `TIMESTAMPTZ` | `now()` | NO | — | |

**RLS**: Enabled. Policies in `supabase/policies/audit_logs_policies.sql`:
- Admin-only read (`USING (current_user_is_admin())`; Phase 4 evaluates to FALSE).
- No INSERT/UPDATE/DELETE policies — writes happen exclusively via `SECURITY DEFINER` functions (the `log_audit()` trigger).

**Indexes** (Phase 4 ships only the PK index; later phases that query audit logs at scale add `CREATE INDEX ON audit_logs (target_type, target_id)` etc. as needed):

- `audit_logs_pkey` on `(id)` — implicit from `PRIMARY KEY`.

---

## Status Enums (§6.3 of the implementation plan)

All eight enums are pre-declared in `20260506120001_init_enums.sql` per the Q3 clarification. Each enum is a Postgres native type (R-03).

| Enum type | Values |
|---|---|
| `account_status_enum` | `pending`, `approved`, `rejected`, `suspended`, `deleted` |
| `publisher_status_enum` | `pending`, `approved`, `rejected`, `suspended`, `deleted` (same value set as account; kept as a separate type so the two columns can evolve independently) |
| `listing_status_enum` | `draft`, `pending_review`, `approved`, `rejected`, `paused`, `sold`, `rented`, `expired`, `deleted` |
| `inquiry_status_enum` | `new`, `seen`, `responded`, `closed`, `spam` |
| `report_status_enum` | `new`, `reviewing`, `resolved`, `dismissed` |
| `listing_purpose_enum` | `sale`, `rent`, `daily_rent`, `investment` |
| `property_type_enum` | `apartment`, `villa`, `land`, `shop`, `office`, `farm`, `warehouse`, `other` |
| `location_visibility_enum` | `hidden`, `approximate`, `exact`, `admin_only` |
| `report_reason_enum` | `fake_listing`, `wrong_price`, `already_sold_or_rented`, `duplicate`, `spam`, `wrong_location`, `inappropriate_content`, `other` |

**Idempotency wrapper** (R-03): each `CREATE TYPE` is wrapped in a `DO $$ BEGIN … EXCEPTION WHEN duplicate_object THEN NULL; END $$;` block so re-applying `20260506120001_init_enums.sql` is safe.

**Dart mirrors** (Phase 4 ships only the two used by `profiles`):

- `lib/shared/domain/value_objects/account_status.dart` → `enum AccountStatus { pending, approved, rejected, suspended, deleted }`
- `lib/shared/domain/value_objects/publisher_status.dart` → `enum PublisherStatus { pending, approved, rejected, suspended, deleted }`

The remaining six Dart mirrors (`ListingStatus`, `InquiryStatus`, `ReportStatus`, `ListingPurpose`, `PropertyType`, `LocationVisibility`, `ReportReason`) land in their owning phases. Per FR-011, the SQL enum types exist from Phase 4 onward; the Dart mirrors are added phase-by-phase as the corresponding domain entities enter scope.

---

## Functions

### `handle_new_auth_user() RETURNS TRIGGER`

Auto-provisions both the `profiles` row and the `user_preferences` row when a row is inserted into `auth.users`. See R-07 for the function body and trigger declaration.

**Inputs**: `NEW` (the inserted `auth.users` row).
**Side effects**: One `INSERT INTO profiles` and one `INSERT INTO user_preferences`, both with `ON CONFLICT (user_id) DO NOTHING`.
**Security**: `SECURITY DEFINER`, `SET search_path = public`.
**Returns**: `NEW`.
**Owner**: Phase 4 (this spec).
**Reused by**: All later phases — they neither modify nor add to it (Phase 5's profile-fill uses normal `UPDATE profiles SET full_name = …` calls; the auto-provision trigger doesn't run on UPDATE).

### `log_audit() RETURNS TRIGGER`

Generic audit-log emitter. See R-04 for the full PL/pgSQL body and the per-trigger argument convention.

**Inputs**: `TG_OP`, `OLD`, `NEW`, `TG_TABLE_NAME`, `TG_ARGV[0]` (action key, required), `TG_ARGV[1]` (comma-separated column list, required; `*` for all columns), `TG_ARGV[2]` (PK column name, optional, defaults to `'id'`).
**Side effects**: Up to one `INSERT INTO audit_logs`. For `UPDATE` triggers with a column list, skipped if no listed column actually changed (`IS DISTINCT FROM` filter via `to_jsonb(OLD) -> col` vs `to_jsonb(NEW) -> col`).
**Security**: `SECURITY DEFINER`, `SET search_path = public` — needed because the trigger writes `audit_logs` regardless of the calling session's RLS posture.
**Returns**: `COALESCE(NEW, OLD)` (works for INSERT/UPDATE → NEW, DELETE → OLD).
**Target ID resolution**: `to_jsonb(NEW or OLD) ->> COALESCE(TG_ARGV[2], 'id')`. Table-agnostic; supports any PK column name.
**Owner**: Phase 4 (this spec).
**Reused by**: Every phase with an audit-worthy table. Phase 5 attaches it to `account_approval_requests` (PK=`id`, omit TG_ARGV[2]); Phase 6 to `roles`/`role_permissions`/`user_roles`; Phase 7's `mutate_role` Edge Function calls it for non-trigger paths; Phase 12's `approve_listing`/`reject_listing`; Phase 18's `resolve_report`; Phase 19 agency events. The function MUST NOT be modified by those phases — only attached to new triggers with new args.

### `current_user_is_admin() RETURNS BOOLEAN`

Placeholder admin predicate. See R-05.

**Phase 4 body**: `SELECT FALSE;`
**Inputs**: None.
**Returns**: BOOLEAN.
**Security**: `SECURITY INVOKER` (the default — see R-05 rationale).
**Owner**: Phase 4 (this spec, in `20260506120002_create_profiles.sql` — moved from the original 0005 plan because R-12's `enforce_profile_status_admin_only` trigger ships in `0002` and calls this helper).
**Replaced by**:
- Phase 5: body becomes `SELECT (SELECT is_admin FROM profiles WHERE user_id = auth.uid());` (Phase 5 introduces the interim `is_admin` boolean column on `profiles`).
- Phase 6: body becomes `SELECT current_user_has_permission('users.view');` (or whatever anchor permission Phase 6's spec chooses).

In each case, only the function body changes; the function signature is stable, and no policy file is touched.

### `enforce_profile_status_admin_only() RETURNS TRIGGER`

Column-level enforcement of FR-006: blocks non-privileged, non-admin sessions from changing `account_status` or `publisher_status`. See R-12 for the full body, rationale, and bypass list.

**Inputs**: `OLD`, `NEW` (the row being updated).
**Side effects**: Either returns `NEW` (allowing the UPDATE) or raises `42501 insufficient_privilege`.
**Security**: `SECURITY INVOKER` (the function checks `current_user` directly, so it must run under the caller's role).
**Returns**: `NEW` on pass; otherwise raises.
**Owner**: Phase 4 (this spec, in `20260506120002_create_profiles.sql`).
**Privileged-session bypass**: `current_user` IN (`postgres`, `supabase_admin`, `service_role`, `supabase_auth_admin`). Authenticated/anon roles are subject to the `current_user_is_admin()` check.

### `app_vault_secret(p_name TEXT) RETURNS TEXT`

Vault-secret read helper. See R-06.

**Inputs**: `p_name` — the secret's name as registered in `vault.secrets`.
**Returns**: The decrypted secret value as TEXT, or `NULL` if no row matches.
**Security**: `SECURITY DEFINER` (needs to read `vault.decrypted_secrets`, which is admin-only by Supabase platform default).
**Volatility**: `STABLE`.
**Owner**: Phase 4 (this spec, in `20260506120006_enable_vault.sql`).
**Reused by**:
- Phase 5: reading the per-user encrypted PII view's plaintext fallback (admin-decrypt path).
- Phase 16: reading inquirer-phone Vault rows.
- Phase 19: reading agency-verification ID document number.
- Phase 21: reading third-party ad-network API keys.
- Phase 22: reading the FCM service-account JSON (parsed at the call site via `app_vault_secret(name)::jsonb`).

The function MUST NOT be modified by those phases.

---

## Triggers

### `trg_auth_users_handle_new`

```sql
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION handle_new_auth_user();
```

Fires once per inserted `auth.users` row, regardless of source (signup, fixture, admin import). Idempotent at the side-effect level (R-07's `ON CONFLICT DO NOTHING`).

### `trg_profiles_audit_status`

```sql
AFTER UPDATE OF account_status, publisher_status ON profiles
FOR EACH ROW
EXECUTE FUNCTION log_audit('profile.status_changed', 'account_status,publisher_status', 'user_id');
```

The concrete trigger that makes User Story 3 end-to-end verifiable in Phase 4. Fires only when `account_status` or `publisher_status` is part of the UPDATE's SET clause; `IS DISTINCT FROM` filter inside `log_audit()` further suppresses the insert if neither value actually changed. The third argument `'user_id'` is the PK column name (per R-04); without it the function would default to `'id'` and produce NULL `target_id` (since `profiles` has no `id` column).

### `trg_profiles_enforce_status_admin_only`

```sql
BEFORE UPDATE ON profiles
FOR EACH ROW
EXECUTE FUNCTION enforce_profile_status_admin_only();
```

The R-12 column-level enforcement trigger. Fires before every UPDATE on profiles; raises `42501 insufficient_privilege` if a non-privileged, non-admin session attempts to change `account_status` or `publisher_status`. Privileged sessions (Supabase MCP `execute_sql`, Edge Functions with service_role) bypass the check.

### `trg_profiles_set_updated_at` and `trg_user_preferences_set_updated_at`

Standard `BEFORE UPDATE` triggers that set `NEW.updated_at = now()`. The supporting function `set_updated_at() RETURNS TRIGGER` is shipped in `20260506120002_create_profiles.sql` and reused by `20260506120003_create_user_preferences.sql`.

---

## Extensions

| Extension | Where enabled | Purpose | Phase |
|---|---|---|---|
| `pgcrypto` | `00000000000000_init_extensions.sql` (existing) | `gen_random_uuid()` for PK defaults | Phase 1 |
| `uuid-ossp` | `00000000000000_init_extensions.sql` (existing) | Legacy compat | Phase 1 |
| `pgsodium` | `20260506120006_enable_vault.sql` | Backing for Supabase Vault | Phase 4 (this spec) |

---

## Domain Entities (Flutter side)

### `Profile` (`lib/shared/domain/entities/profile.dart`)

Plain immutable Dart class extending `Equatable`. Field shape per R-10. NO Supabase imports. NO Freezed (the project uses `equatable` for value-equality).

Fields: `userId`, `fullName?`, `username?`, `phone?`, `email?`, `avatarUrl?`, `accountStatus`, `publisherStatus`, `createdAt`, `updatedAt`. Hand-written `copyWith` and `props` getter (R-10).

### `UserPreferences` (`lib/shared/domain/entities/user_preferences.dart`)

Plain immutable Dart class extending `Equatable`. Field shape per R-10. NO Supabase imports. Uses Phase 3's `Locale` (from `dart:ui`) and Phase 2's `ThemeMode` (from `package:flutter/material.dart`).

Fields: `userId`, `locale`, `themeMode`, `displayCurrency` (String — Phase 9 narrows to a `Currency` value object), `notificationsEnabled`. Hand-written `copyWith` and `props` getter (R-10).

### Value-object enums

- `AccountStatus` (`lib/shared/domain/value_objects/account_status.dart`) — mirrors `account_status_enum`.
- `PublisherStatus` (`lib/shared/domain/value_objects/publisher_status.dart`) — mirrors `publisher_status_enum`.

Plain Dart enums; no Freezed. Phase 5's data-layer mapper handles `String ↔ Enum` conversion.

---

## State Transitions

Phase 4 introduces no state machines. The auto-provision trigger only writes the initial state (`pending` for both account and publisher status). All transitions (`pending → approved`, `pending → rejected`, etc.) are owned by the phases that introduce the actions that drive them — Phase 5 (auth approval), Phase 12 (listing approval workflow), Phase 18 (moderation), etc.

The audit infrastructure exists from Phase 4 onward; Phase 4's concrete trigger captures any `account_status`/`publisher_status` transition that happens to occur in this phase (none expected — no real admin exists yet).

---

## Out of scope for this data model

- `account_approval_requests` (Phase 5).
- `roles`, `permissions`, `role_permissions`, `user_roles` (Phase 6).
- `agencies`, `agency_members`, `agency_verification_requests` (Phase 19).
- `governorates`, `cities`, `areas` (Phase 8).
- `currencies`, `exchange_rates` (Phase 9).
- `listings`, `listing_details`, `listing_prices`, `listing_visibility`, `listing_status_history`, `listing_media` (Phases 10/11).
- `inquiries`, `lead_events` (Phase 16).
- `favorites` (Phase 17).
- `reports`, `moderation_actions` (Phase 18).
- `ads`, `ad_placements`, `ad_impressions` (Phase 21).
- Storage buckets (`listing-images`, `listing-videos`, `ads`).
- Edge Functions (`mutate_role`, `submit_listing`, `approve_listing`, `reject_listing`, `record_lead_event`, `record_ad_event`, `update_exchange_rate`, `resolve_report`).
- Realtime channels.
