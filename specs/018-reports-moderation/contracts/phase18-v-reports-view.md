# Contract — `public.v_reports` view

**Migration**: `supabase/migrations/20260530120004_create_v_reports_view.sql` (Sub-Phase C)

## Declaration

`CREATE VIEW public.v_reports WITH (security_invoker = true) AS …` — SECURITY INVOKER so the base-table `reports` RLS applies to view reads. One view serves BOTH the reporter ("My Reports") and the admin (queue); row visibility differs naturally by RLS.

## Projection

`id, listing_id, reporter_user_id, reason, note, status, reviewing_by, resolved_by, resolution, created_at, resolved_at, listing_title, listing_status, main_image_path, governorate_name_ar/_en, city_name_ar/_en`.

Joins: `reports → listings` (INNER), `governorates`/`cities` (LEFT, display_name JSONB), `listing_media` (LATERAL, `is_main` main image) — the same join set as `v_listings_public` (`20260525120002`).

## Contract points

- **No `l.status` filter** — reports about non-approved listings still appear in the queue + My-Reports (the admin must see a report even after the listing changed; the reporter sees their report regardless).
- `GRANT SELECT TO authenticated`; NOT granted to `anon`.
- Projects NO publisher private field and NO aggregate count (FR-028).

## Smoke tests

1. Reporter SELECT `v_reports` → only their own report rows (base RLS).
2. `reports.manage` SELECT `v_reports` → all rows, including reports on `paused`/`deleted` listings (`listing_status` reflects the current state).
3. anon SELECT `v_reports` → denied (no grant + no base anon policy).
