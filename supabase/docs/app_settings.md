# app_settings

## Purpose

`app_settings` is the admin-tunable, app-wide settings store introduced in Phase 23. Each
row is one catalog key with a typed `JSONB` value. It backs the admin settings editor,
maintenance mode, forward-only new-user / new-listing defaults, and the in-app
about/support surface. It holds **app-wide** settings only — per-user preferences live in
`user_preferences`.

## Columns

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `key` | `TEXT` | NO | - | Primary key; stable catalog identifier (e.g. `maintenance_mode`). Clients never create keys. |
| `value` | `JSONB` | NO | - | Typed value; shape per the catalog below. |
| `description` | `TEXT` | YES | - | Human-readable note. |
| `is_public` | `BOOLEAN` | NO | `true` | Per-key read classification (R-197). Public keys are readable by anyone; sensitive keys only by `settings.manage` holders. |
| `updated_by` | `UUID` | YES | - | Last editor; FK → `auth.users(id)` ON DELETE SET NULL. Stamped by `set_app_setting()`. |
| `updated_at` | `TIMESTAMPTZ` | NO | `now()` | Maintained by the `set_updated_at` BEFORE-UPDATE trigger. |

## RLS posture

RLS is **enabled**. Per-key read is enforced by **two permissive SELECT policies**
(OR-combined by Postgres), introduced by migration `…019`:

```sql
-- (1) everyone (anon + authenticated), no permission-function call:
CREATE POLICY app_settings_select_public ... USING (is_public);
-- (2) authenticated only:
CREATE POLICY app_settings_select_admin  ... TO authenticated
  USING (public.current_user_has_permission('settings.manage'));
```

- A non-admin client (including anonymous) reads **only `is_public = true` rows** via
  policy (1); a sensitive (`is_public = false`) row is invisible to it at the wire level.
- A `settings.manage` holder reads **all** rows (policy (1) ∪ policy (2)).
- `GRANT SELECT TO anon, authenticated`; `REVOKE ALL FROM PUBLIC` (hardening …017).

> **Why two policies, not one** (`…019` fix): the original single policy
> `USING (is_public OR current_user_has_permission('settings.manage'))` was granted to
> PUBLIC. But `current_user_has_permission` is `SECURITY DEFINER` with EXECUTE granted to
> `authenticated`/`service_role` only (Phase 6/22 hardening revoked it from anon/PUBLIC).
> Postgres does not short-circuit `is_public OR f()` past the function's EXECUTE-privilege
> check, so a logged-out (anon) app session loading public settings failed with
> `42501: permission denied for function current_user_has_permission`. Splitting keeps the
> predicate `authenticated`-only — matching every other policy that references it.

There are **no** INSERT / UPDATE / DELETE policies by design. All direct client writes are
REVOKEd from `anon` and `authenticated`. The **only** mutation path is the
`set_app_setting()` RPC.

## Write path — `set_app_setting(p_key TEXT, p_value JSONB)`

`SECURITY DEFINER` (`SET search_path = public, auth`), the single permission boundary:

- Re-checks `public.current_user_has_permission('settings.manage')`; raises **`42501`**
  (permission denied) if absent — checks-at-both-ends with the FA UI gate (Principle III).
- `UPDATE app_settings SET value = p_value, updated_by = auth.uid(), updated_at = now() WHERE key = p_key`;
  returns the updated row.
- Raises **`P0002`** if `p_key` is not a seeded catalog key (no row updated; no partial write).
- Grants: `REVOKE EXECUTE FROM anon, PUBLIC; GRANT EXECUTE TO authenticated`.

## Audit trigger

`trg_app_settings_audit` (AFTER UPDATE) reuses the Phase 4 `log_audit()` trigger function:

```sql
EXECUTE FUNCTION public.log_audit('settings.updated', 'value', 'key')
```

Every successful change writes one `audit_logs` row: `action = 'settings.updated'`,
`target_type = 'app_settings'`, `target_id = key`, `actor_user_id = auth.uid()`, with the
before/after `value`. A denied call writes and audits nothing (the exception aborts before
the UPDATE). This is the §9.4 "App settings changes (Phase 23)" audited action — no new
audit infrastructure.

## Catalog (the closed v1 set — 8 keys, value shapes)

All keys are seeded `is_public = true`. There is **no `supported_currencies` key** — Phase 9
`currencies.is_active` is the source of truth for supported currencies (R-198).

| key | `value` shape | seed default | consumed by |
|---|---|---|---|
| `default_language` | string `"ar"` \| `"en"` | `"ar"` | FC registration seeding (FR-007) |
| `default_currency` | string (active `currencies.code`) | `"SYP"` | FC registration seeding (FR-007) |
| `default_publisher_name_visibility` | string `"public"` \| `"admin_only"` | `"public"` | new listing-form default (FR-008) |
| `default_location_visibility` | string `"hidden"`\|`"approximate"`\|`"exact"`\|`"admin_only"` | `"approximate"` | new listing-form default (FR-008) |
| `maintenance_mode` | `{ "on": bool, "message": { "ar": string\|null, "en": string\|null } }` | `{"on": false, "message": {"ar": null, "en": null}}` | FC maintenance gate + screen (FR-009/011) |
| `support_contact` | `{ "phone": string\|null, "whatsapp": string\|null, "email": string\|null }` | `{"phone": null, "whatsapp": null, "email": null}` | FC about/support + maintenance screen (FR-013) |
| `terms_url` | string\|null | `null` | FC about surface (FR-013) |
| `privacy_url` | string\|null | `null` | FC about surface (FR-013) |

## Validation ownership

- The admin editor (FA) validates each control to the domain above **before** calling
  `set_app_setting` — an invalid value is never sent.
- The DB stores whatever JSONB the definer RPC receives (the editor is the validation gate).
  The seed guarantees a sensible starting value for each key.
- `default_currency` is **not** FK-constrained to `currencies`; instead the editor's picker
  is constrained to `ListCurrencies(activeOnly: true)` (Phase 9), so the stored code always
  references an active currency.

## Gotchas

- **`default_currency` has no FK** to `currencies.code` — the active-currency invariant is
  enforced client-side by the editor picker, not the schema. If a currency is later
  deactivated in Phase 9, an already-stored default is not auto-corrected.
- **Sensitive keys**: the `is_public` column exists for forward use, but **no
  `is_public = false` key is seeded in v1** (R-197). The SELECT policy already handles them.
- **Idempotency**: all Phase 23 migrations (`…014`–`…019`) are safe to re-apply (the
  Supabase MCP `apply_migration` re-runs SQL on a name collision): `CREATE TABLE IF NOT
  EXISTS`, `CREATE OR REPLACE FUNCTION`, `DROP TRIGGER/POLICY IF EXISTS`, seed `ON CONFLICT
  DO NOTHING`, `CREATE INDEX IF NOT EXISTS` (…018 FK index), policy split (…019).
- **Reuses, never redefines**: `set_updated_at()` (Phase 4), `current_user_has_permission()`
  (Phase 6), and `log_audit()` (Phase 4). No new permission key (reuses `settings.manage`),
  no new extension, no new dependency.
- **Not Realtime**: clients fetch settings on app-load + foreground-resume; there is no
  Realtime subscription on this table (R-201).
