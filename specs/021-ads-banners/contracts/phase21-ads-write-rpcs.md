# Contract: Ads Write RPCs

**Phase 21** · migrations `20260601120011` (admin writers) + `…012` (public click recorder). All SECURITY DEFINER (R-165, R-167).

## Admin writers (gate: `current_user_has_permission('ads.manage')` → `permission_denied`/42501)

| RPC | Params | Returns | Notes |
|-----|--------|---------|-------|
| `create_ad` | `p_title, p_image_path, p_caption_ar, p_caption_en, p_link_kind, p_link_value, p_start_at, p_end_at, p_is_active, p_placements jsonb` | `UUID` (ad id) | binds `created_by := auth.uid()`; inserts placements from the JSONB array |
| `update_ad` | same as create + `p_ad_id` | `VOID` | updates fields on the non-archived ad; **replaces** the placement set atomically; `ad_not_found`/23503 if missing/archived |
| `set_ad_active` | `p_ad_id, p_is_active` | `VOID` | toggle; `ad_not_found`/23503 |
| `archive_ad` | `p_ad_id` | `VOID` | soft-delete: `archived_at := now()`; `ad_not_found`/23503 if already archived/missing |

`p_placements` shape: `[{"placement_key":"home_top_banner","priority":10}, …]`.

**Grants**: `REVOKE ALL … FROM PUBLIC, anon; GRANT EXECUTE … TO authenticated;` (the in-RPC `ads.manage` check is the real gate — "checks at both ends" with the frontend `PermissionChecker`).

**Audit**: `create_ad`'s INSERT fires `trg_ads_audit_created` → `ad.created`; `archive_ad`'s UPDATE fires `trg_ads_audit_deleted` → `ad.deleted`; both log `auth.uid()` as actor (admin's JWT; no GUC needed since these run under the caller, not service role).

**Error codes**: `42501` permission_denied · `23503` ad_not_found · `23514`/`23505` from table CHECK/constraint violations (e.g., bad `link_kind`, invalid window, one-caption-null) surface to the client as a localized save error.

## Public click recorder

| RPC | Params | Returns | Notes |
|-----|--------|---------|-------|
| `record_ad_event` | `p_ad_id, p_placement_key` | `UUID` (event id) | NO permission gate; validates the ad is **eligible + assigned** to the placement (same predicate as `v_ads_serving`) → `ad_not_eligible`/23514 otherwise; inserts `kind='click'` with `auth.uid()` (nullable) + IP/UA metadata |

**Grants**: `REVOKE ALL … FROM PUBLIC; GRANT EXECUTE … TO authenticated, anon;` (mirrors `record_lead_event`).

**Client contract**: `supabase.rpc('record_ad_event', {p_ad_id, p_placement_key})`. Best-effort: the caller MUST open the link target regardless of this call's success/failure (FR-017) — a thrown `ad_not_eligible` or network error is swallowed by the tap handler.
