# Contract: `public.app_settings` table

**Phase 23 · migration `20260602120014_create_app_settings.sql` (+ `…017` hardening)**

## Shape

| column | type | notes |
|---|---|---|
| `key` | `TEXT` PRIMARY KEY | catalog identifier (e.g. `maintenance_mode`) |
| `value` | `JSONB` NOT NULL | typed value; shape per the catalog (see `phase23-settings-seed-and-catalog.md`) |
| `description` | `TEXT` | human-readable note |
| `is_public` | `BOOLEAN` NOT NULL DEFAULT `true` | per-key read classification (R-197) |
| `updated_by` | `UUID` → `auth.users(id)` ON DELETE SET NULL | last editor |
| `updated_at` | `TIMESTAMPTZ` NOT NULL DEFAULT `now()` | maintained by `set_updated_at()` BEFORE-UPDATE trigger |

## RLS & grants

- RLS **enabled**.
- `GRANT SELECT ON public.app_settings TO anon, authenticated;`
- SELECT policy `app_settings_select`: `USING (is_public OR public.current_user_has_permission('settings.manage'))`.
- `REVOKE INSERT, UPDATE, DELETE ON public.app_settings FROM anon, authenticated;` — **no direct client writes**; mutation only via `set_app_setting()`.
- `…017`: `REVOKE ALL … FROM PUBLIC; GRANT SELECT TO anon, authenticated;` (tighten).

## Invariants

- A non-admin (incl. anonymous) client **reads only `is_public = true` rows**; a sensitive (`is_public = false`) row is invisible to it at the wire level.
- A `settings.manage` holder reads **all** rows.
- No client can INSERT/UPDATE/DELETE directly (denied) — the only write path is the `set_app_setting` RPC.
- `key` is stable and seeded; clients never create keys.

## Consumed by

- FD `SupabaseAppSettingsDatasource.loadPublicSettings()` / `loadAllSettings()` — `_client.from('app_settings').select()`.
