# Contract: `v_ads_serving` (public serving projection)

**Phase 21** · migration `20260601120009` · SECURITY DEFINER view (R-166).

## Purpose
The ONLY public read path for ads. Returns one row per (eligible ad × placement), exposing only the fields needed to render and tap a banner. The definer view bypasses the admin-only base-table SELECT policy and applies the eligibility WHERE, so drafts / inactive / expired / not-yet-started / archived ads and admin-only fields (title, schedule, created_by, is_active) NEVER reach the client (FR-020).

## Columns
`ad_id`, `image_path`, `caption_ar`, `caption_en`, `link_kind`, `link_value`, `placement_key`, `priority`.

## Eligibility (WHERE)
```
is_active = true
AND archived_at IS NULL
AND (start_at IS NULL OR start_at <= now())
AND (end_at   IS NULL OR end_at   >  now())
```

## Grants
`GRANT SELECT ON public.v_ads_serving TO anon, authenticated;`

## Client query contract (PD datasource)
```
supabase.from('v_ads_serving')
  .select('ad_id,image_path,caption_ar,caption_en,link_kind,link_value,placement_key,priority')
  .eq('placement_key', <key>)
  .order('priority', ascending: false)
  .order('ad_id');
```
- Bounded per placement (FR-013) — no full-table fetch, no client-side eligibility filtering.
- Result drives the `AdSlot`: 0 rows → collapse; 1 row → static banner; ≥2 → priority-ordered carousel.
- Eligibility is evaluated at read time → an expired/deactivated/archived ad disappears on the next query (FR-011); a future-dated ad appears only once `start_at <= now()`.

## Security notes
- Implicit SECURITY DEFINER (no `security_invoker`) — matches `v_listings_public` / `v_agencies`.
- New views default to anon SELECT; the GRANT is explicit (memory `project_supabase_view_rls_gotchas`).
- Run `get_advisors` after apply; resolve any definer/search-path advisory (advisor-hardening migration `…014`).
