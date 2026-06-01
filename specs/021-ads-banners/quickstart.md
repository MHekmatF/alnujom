# Quickstart — Ads & Banners Admin Module (Phase 21)

End-to-end manual verification recipe (no new automated tests — memory `feedback_no_new_tests`). Each step maps to Success Criteria. Run on the reference Infinix Note 8 + a 412 dp Pixel 8 Pro AVD; always `flutter run --dart-define-from-file=.env.json` (memory `project_dart_defines`).

## 0. Apply backend (PB)
Apply migrations `20260601120006`–`…014` in order via Supabase MCP `apply_migration` (memory `project_supabase_apply_via_mcp`). Then run `get_advisors` and resolve any SECURITY DEFINER / function-search-path / RLS-disabled advisory. Structural check: `ads`, `ad_placements`, `ad_impressions` exist with RLS enabled; `v_ads_serving` exists; `ads` bucket exists (public); RPCs `create_ad`/`update_ad`/`set_ad_active`/`archive_ad`/`record_ad_event` exist with the grants in `contracts/phase21-ads-write-rpcs.md`.

## 1. Admin authoring (SC-001, SC-011) — sign in as an `ads.manage` holder (admin)
1. Open the admin dashboard → confirm the **Ads** tile is now navigable (no longer "coming soon"); tap it → `AdsListPage`.
2. Create an ad: title, upload a banner image, leave caption empty (image-only), `link_kind=external` + a URL, assign `home_top_banner` priority 10, schedule start=now end=null, active=on. Save (< 3 min).
3. Confirm it appears in the list with status **active** and placement `home_top_banner`.
4. SQL: `SELECT id,title,is_active,archived_at FROM ads ORDER BY created_at DESC LIMIT 1;` and `SELECT * FROM ad_placements WHERE ad_id='<id>';`.
5. Audit: `SELECT action,target_type,actor_user_id FROM audit_logs WHERE target_type='ads' ORDER BY created_at DESC LIMIT 3;` → an `ad.created` row by you.
6. Sign in as a NON-`ads.manage` user → confirm NO Ads tile, and `/admin/ads` redirects to `/admin?denied=ads`.

## 2. Public serving (SC-002, SC-003, SC-004, SC-009) — sign in as / browse as an ordinary user
1. Open home → the `home_top_banner` ad appears at the top within ~2 s (SC-002).
2. As admin, create a SECOND `home_top_banner` ad (priority 20) → reopen home → both rotate in a carousel ordered by priority (20 before 10), auto-advancing + swipeable; deactivate one → the remaining one renders static (SC-003).
3. Set the active ad's `end_at` to 1 minute ago (or toggle inactive) → pull-to-refresh home → it disappears with no admin takedown. Create an ad with `start_at` in the future → confirm it does NOT show until start (SC-004).
4. Open a placement with no eligible ad → the slot shows nothing; the surface looks identical to a no-ad state (no empty box / reflow — SC-009).
5. Repeat the "appears" check on **search results** (`search_results_banner`) and **listing details** (`listing_details_banner`).

## 3. Tap-through + click tracking (SC-005, SC-006, SC-007)
1. Tap the external-URL ad → it opens in the browser/handler. Create an ad with `link_kind=listing` + a real listing id → tap → it navigates in-app to `/listings/:id` (SC-005). Repeat for `agency` (`/agency/:id`).
2. SQL after N taps: `SELECT COUNT(*) FROM ad_impressions WHERE ad_id='<id>' AND kind='click';` == N; and `SELECT COUNT(*) FROM ad_impressions WHERE kind <> 'click';` == 0 (clicks only — SC-006).
3. Enable airplane mode (or block the RPC) and tap a banner → the destination still opens (best-effort, non-blocking — SC-007).

## 4. Security — checks at both ends (SC-008)
From a session WITHOUT `ads.manage` (and an anon session), at the wire level:
1. `insert/update/delete` on `ads` / `ad_placements` → **denied** (RLS REVOKE).
2. `rpc('create_ad', …)` / `rpc('archive_ad', …)` → **permission_denied** (42501).
3. Upload to the `ads` bucket → **denied** (storage policy).
4. `insert` into `ad_impressions` directly → **denied**.
5. Anon `select` from `v_ads_serving` → returns ONLY active in-window ads (no drafts/inactive/expired/archived, no title/schedule/created_by).

## 5. Permission data-drivenness (SC-012)
Grant `ads.manage` to a test role with a test user → refresh session → the Ads tile + admin surface become reachable. Revoke → they become unreachable on next refresh. No code change (Principle VII).

## 6. Localization & theming (SC-010)
Cycle (light, ar) × (dark, ar) × (light, en) × (dark, en) on the admin surface AND a host surface with an active banner (image-only AND image+caption variants). Confirm: every string localized (no raw literals), forms/pickers/carousel RTL- and LTR-correct, caption renders per-locale, styling from Phase 2 tokens (no inline hex/font/padding).

## 7. Constitution / dependency gates (SC-013)
- `git diff pubspec.yaml pubspec.lock` → empty (ZERO new deps — FR-025).
- Grep the ads feature for hardcoded role branches (`role ==`, `'admin'`) → none; gating is `PermissionChecker.has(PermissionKeys.adsManage)` (FR-022).
- Confirm no third-party ad-network dep, no §9.1 catalog change, no `ads.manage` seed change (FR-026).
- Run the full CI linter suite locally (analyze + format + design-tokens + l10n-parity + l10n-literals + SDK-boundary — memory `project_wave_run_full_verify_suite`).

## Definition of done
All of SC-001..SC-013 demonstrated and recorded; backend applied + advisors clean; spec/plan/data-model/contracts consistent with shipped behavior (Principle X). Per memory `project_wave_output_needs_device_qa`, the on-device walk (steps 1–6) is mandatory — analyze+grep alone is insufficient (live storage upload, deep-link resolution, carousel rotation, and click round-trips must be exercised on a real device).
