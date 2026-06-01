# Phase 0 Research — Ads & Banners Admin Module (Phase 21)

Locked plan-time decisions **R-164 .. R-178** (continuing the project's R-series after Phase 20's R-163). Each resolves a NEEDS-CLARIFICATION-or-choice surfaced by the spec + plan. Format: Decision / Rationale / Alternatives considered.

---

### R-164 — ZERO new dependencies

**Decision**: Implement the entire feature with the existing stack. External-URL launch reuses `url_launcher` (already used by Phase 16 `contact_block.dart`); in-app deep links reuse `go_router`; the carousel is Flutter's built-in `PageView` + a `Timer`; banner image pick/compress/upload/display reuse `image_picker` + `image`/`flutter_image_compress` + `supabase_flutter` storage + `cached_network_image` (all already in `pubspec.yaml`).
**Rationale**: FR-025 + Principle XI; no Android-manifest or plugin churn. Confirmed `url_launcher: ^6.3.0`, `image_picker`, `image`, `flutter_image_compress`, `cached_network_image`, `go_router` all present.
**Alternatives**: a `carousel_slider` package (rejected — `PageView` suffices); a third-party ad SDK (rejected — out of scope, FR-026).

### R-165 — RPC-only writes; all three tables REVOKE client INSERT/UPDATE/DELETE

**Decision**: `ads`, `ad_placements`, `ad_impressions` grant NO client write. Every mutation flows through a SECURITY DEFINER RPC (`create_ad`/`update_ad`/`set_ad_active`/`archive_ad`/`record_ad_event`). Each admin RPC re-checks `current_user_has_permission('ads.manage')` and raises `permission_denied` (ERRCODE 42501) otherwise.
**Rationale**: The dominant recent posture (Phase 18 reports `20260530120003`, Phase 19 agencies — "the three tables grant NO client INSERT/UPDATE/DELETE"). Gives atomic multi-table writes (ad + placements) and "checks at both ends" (FR-019). The `log_audit()` triggers fire with the correct `auth.uid()` because the admin RPCs run under the admin's own JWT (SECURITY DEFINER changes role, not `auth.uid()`) — so NO `set_config('app.current_user_id')` GUC is needed (unlike the service-role `moderate_agency` Edge Function).
**Alternatives**: direct RLS `WITH CHECK (current_user_has_permission('ads.manage'))` INSERT/UPDATE policies (rejected — non-atomic across ads+placements, and diverges from the established RPC-only sibling tables).

### R-166 — Public serving via a SECURITY DEFINER view `v_ads_serving`

**Decision**: Public read is a `SECURITY DEFINER` (implicit — no `security_invoker`) view `v_ads_serving` that JOINs eligible `ads`+`ad_placements` and exposes ONLY serving fields (`ad_id`, `image_path`, `caption_ar`, `caption_en`, `link_kind`, `link_value`, `placement_key`, `priority`). GRANT SELECT to `anon, authenticated`. The base tables keep an admin-only (`ads.manage`) SELECT policy; the definer view bypasses that for the public, returning only eligible rows.
**Rationale**: Exactly the Phase 14 `v_listings_public` / Phase 19 `v_agencies` idiom (memory `project_supabase_view_rls_gotchas` — use definer + explicit WHERE, not an invoker view that would drop rows). Keeps drafts/inactive/expired/archived ads and admin-only fields (title, schedule, created_by) off the wire (FR-020).
**Alternatives**: a public RLS SELECT policy on `ads` filtered to the active window (rejected — would expose admin-only columns and require a second policy for placements; the view is the project's established read-projection mechanism).

### R-167 — `record_ad_event` is a SECURITY DEFINER RPC, NOT an Edge Function

**Decision**: Click recording is the SECURITY DEFINER RPC `record_ad_event(p_ad_id, p_placement_key)` — `GRANT EXECUTE TO authenticated, anon`, `REVOKE … FROM PUBLIC` — mirroring Phase 16's `record_lead_event` RPC (`20260527120010`). It validates the ad is eligible + assigned to the placement, captures IP/user-agent into `metadata`, and inserts a `click` row.
**Rationale**: The plan's §6.7 lists `record_lead_event` as an "Edge Function," but Phase 16 actually implemented it as a SECURITY DEFINER RPC — the project's real pattern for high-volume client-recorded events (no permission gate, no cold-start, no Deno runtime). `record_ad_event` follows that precedent. Per Principle X, the spec's "Edge Function" wording (FR-016/021, US3/US4, scope note) is reconciled to "controlled write path (SECURITY DEFINER RPC)" in the same change.
**Alternatives**: a Deno Edge Function like `resolve_report` (rejected — that pattern is for service-role atomic admin writes with a JWT permission re-check; a click recorder needs neither service role nor a permission gate, so the lighter RPC is correct and cheaper).

### R-168 — Clicks only; `ad_impressions.kind` CHECK ∈ ('click')

**Decision**: Keep the plan's table name `ad_impressions` but constrain `kind TEXT NOT NULL DEFAULT 'click' CHECK (kind IN ('click'))`. No impression/view rows are produced in v1. `AdSlot` never calls a record path on mere display.
**Rationale**: Spec clarification (clicks only). Constraining the CHECK to a single value documents the narrowing and makes accidental impression writes fail loudly; a future phase widens the CHECK to add `'impression'`.
**Alternatives**: drop the `kind` column entirely (rejected — keeping it preserves the plan's schema shape and the forward path to impressions); allow `'impression'` now but never write it (rejected — an unenforced affordance invites silent drift).

### R-169 — Link target model: `link_kind` discriminator + `link_value`

**Decision**: Two columns — `link_kind TEXT NOT NULL CHECK (link_kind IN ('external','listing','search','category','agency'))` and `link_value TEXT NOT NULL`. `external` → an absolute URL; `listing` → a listing UUID (→ `/listings/:id`); `agency` → an agency UUID (→ `/agency/:id`); `category` → a property-type key (→ filtered search); `search` → a serialized search-filter token/query (→ `/search`).
**Rationale**: The spec's "both" decision (external URL OR in-app deep link to listing/search/category/agency). A discriminator + single value column is the minimal model that covers all five and maps cleanly to the existing route constants (`AppRoutes.listingDetailsFor`, `AppRoutes.search`, `/agency/:id`).
**Alternatives**: a single `link_url` column with a scheme convention (rejected — fragile parsing); separate nullable FK columns per kind (rejected — sparse, more constraints).

### R-170 — Soft-delete via `archived_at`; click history retained

**Decision**: Deletion is `archive_ad(p_ad_id)` setting `ads.archived_at = now()`. Archived ads are excluded from `v_ads_serving` (eligibility requires `archived_at IS NULL`) and from the admin list's default filter (shown only under an "archived" filter). `ad_impressions.ad_id` references `ads(id) ON DELETE CASCADE`, but the product NEVER hard-deletes — so click rows persist for the ad's lifetime (FR-006 retention).
**Rationale**: Spec clarification (soft-delete, retain click history). The derived `archived` status is computed from `archived_at`.
**Alternatives**: hard-delete with `ON DELETE CASCADE` on clicks (rejected — loses history) or `ON DELETE SET NULL` detach (rejected — orphan rows, lost linkage).

### R-171 — Derived ad status (not a stored enum)

**Decision**: `AdStatus ∈ {active, scheduled, expired, inactive, archived}` is COMPUTED (in the domain layer / admin queries) from `is_active` + `start_at`/`end_at` vs `now()` + `archived_at` — NOT a stored column. Priority order: archived → inactive (`is_active=false`) → scheduled (`now < start_at`) → expired (`now ≥ end_at`) → active.
**Rationale**: Avoids a redundant stored state that can drift from the schedule; matches the spec's "derived status."
**Alternatives**: a stored `status` enum updated by a job (rejected — needs a scheduler; the §6.3 listing-status enum is explicitly NOT reused, FR-040-equivalent).

### R-172 — Optional bilingual caption: both-or-neither CHECK

**Decision**: `caption_ar TEXT`, `caption_en TEXT`, with `CHECK ((caption_ar IS NULL AND caption_en IS NULL) OR (caption_ar IS NOT NULL AND caption_en IS NOT NULL))`. `AdSlot` shows the caption matching the viewer's locale; image-only ads have both NULL.
**Rationale**: Spec clarification (image + optional bilingual caption, admin's choice; when present, both languages). Captions are admin-authored CONTENT (like a listing title), NOT `AppLocalizations` keys.
**Alternatives**: single non-localized caption (rejected — breaks Arabic-first parity); always-required caption (rejected — image-only must be allowed).

### R-173 — Carousel: priority-ordered `PageView` + auto-advance Timer + swipe, looping

**Decision**: ≥2 eligible ads in a placement render in a `PageView` ordered by `priority DESC, created_at DESC` (stable tie-break), auto-advancing on a lightweight `Timer` (~5 s) and manually swipeable, looping. Exactly one eligible ad renders statically (no timer, no page indicator).
**Rationale**: Spec clarification (carousel by priority; auto-advance + swipe). The timer is pure client-side UI — NOT a network/Realtime subscription — so it respects the "no eager Realtime on home" performance posture.
**Alternatives**: swipe-only (rejected per clarification — lower-priority ads would never surface without a swipe); a carousel package (rejected — `PageView` suffices, R-164).

### R-174 — `ads` storage bucket: public read, `ads.manage` write, path-shape `{uuid}/{file}`

**Decision**: One public bucket `ads` (`INSERT INTO storage.buckets … ON CONFLICT DO UPDATE`, image mime types, ~5 MB cap). `storage.objects` policies: public SELECT `USING (bucket_id='ads')`; INSERT/UPDATE/DELETE `WITH CHECK (bucket_id='ads' AND current_user_has_permission('ads.manage') AND name ~ '^[0-9a-f-]{36}/.+$')`. Upload path is `{client-uuid}/{filename}` — the uuid prefix is organizational, NOT an FK to `ads.id` (avoids the create-then-upload chicken/egg: the client uploads first, then passes `image_path` to `create_ad`).
**Rationale**: The Phase 19 `agency-assets` public-bucket idiom, minus the per-row approval gate (banner art is non-sensitive promotional content; the data layer's `v_ads_serving` does the eligibility filtering, so an archived ad's image is simply unreferenced). Image-compression discipline (downscale, JPEG q≈80–85) reuses Phase 11.
**Alternatives**: gate public read on the image's ad being eligible (rejected — requires path→ad join + eligibility check on every image fetch; unnecessary for non-sensitive art).

### R-175 — `category_banner` defined but not host-wired this phase

**Decision**: All five placement keys exist in the CHECK constraints (schema completeness per §6.2), but `AdSlot`s are rendered only on home / search / listing-details. The admin placement picker signals `category_banner` as "not yet live" (or omits it) so an assignment there is not silently invisible.
**Rationale**: FR-014 + the plan's `AdSlot` deliverable names only home/search/details; no category landing page exists.
**Alternatives**: wire a category page now (rejected — out of scope; that surface is a separate future spec).

### R-176 — `home_middle_banner`: single slot once after the first feed page

**Decision**: Exactly one `home_middle_banner` `AdSlot` inserted into the home `CustomScrollView` after the first page/batch of listings — not repeated per-N on scroll.
**Rationale**: Spec clarification; keeps the feed uncluttered and the serving read bounded (one `v_ads_serving` query per placement on screen).
**Alternatives**: repeat every N cards (rejected per clarification — a possible later refinement).

### R-177 — Reuse `ads.manage`; ZERO catalog / seed change

**Decision**: Gate everything on the existing `ads.manage` key (seeded on `admin` + `super_admin` in `20260515120002`/`…003`). No new permission key, no §9.1 change, no role-seed change. Frontend `PermissionChecker.has(PermissionKeys.adsManage)` hides the surface + dashboard tile; the route guard `requireAdsManageRedirect` mirrors `requireAuditLogsViewRedirect`.
**Rationale**: FR-026 + Principle VII; Phase 6 reserved the key for exactly this phase. Verified `ads.manage` is on `admin` + `super_admin` (not `moderator`).
**Alternatives**: add `ads.view`/`ads.create` granularity (rejected — out of scope; a single manage key matches the §9.1 catalog).

### R-178 — Migration timestamps `20260601120006`–`…014`; apply via MCP

**Decision**: Nine migrations numbered `20260601120006`–`20260601120014` (after Phase 20's last `…005`). Apply per-file in order via Supabase MCP `apply_migration` (memory `project_supabase_apply_via_mcp` — the CLI DB path is dead), then run `get_advisors` + a structural check. SQL is written idempotently (`IF NOT EXISTS`, `ON CONFLICT`, `CREATE OR REPLACE`) given MCP does not dedupe by name (memory `project_supabase_mcp_apply_migration`).
**Rationale**: Continues the established series + apply discipline.
**Alternatives**: a new `20260602` day series (rejected — same calendar day; contiguous numbering is clearer).

---

**Open items deferred to `/speckit-tasks` / implementation** (low-impact, recorded per Principle XII): exact carousel auto-advance interval (~5 s default); per-placement recommended image aspect ratios (a design detail — the form may guide/crop); concurrent-admin edit conflict handling (last-writer-wins is acceptable for an admin-only table). None blocks the data model or the wave decomposition.
