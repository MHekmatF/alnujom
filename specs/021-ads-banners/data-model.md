# Data Model — Ads & Banners Admin Module (Phase 21)

Full migration bodies (apply in timestamp order via Supabase MCP), Dart domain entities, and the per-FR / per-SC verification map. SQL follows the verified project idioms: `log_audit(action, cols, pk)` triggers, `current_user_has_permission(key)` gates, RPC-only writes (REVOKE), the `agency-assets` storage idiom, and the `v_listings_public` definer-view idiom.

---

## Migration `20260601120006_create_ads.sql`

```sql
-- Phase 21 (spec/021-ads-banners) — ads table. First-party banner ads.
-- RLS on; admin-only SELECT; all client writes REVOKEd (RPC-only, R-165).
CREATE TABLE IF NOT EXISTS public.ads (
  id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  title       TEXT         NOT NULL CHECK (char_length(title) BETWEEN 1 AND 200),
  image_path  TEXT         NOT NULL CHECK (char_length(image_path) BETWEEN 1 AND 400),
  caption_ar  TEXT         CHECK (caption_ar IS NULL OR char_length(caption_ar) <= 200),
  caption_en  TEXT         CHECK (caption_en IS NULL OR char_length(caption_en) <= 200),
  link_kind   TEXT         NOT NULL
                CHECK (link_kind IN ('external','listing','search','category','agency')),
  link_value  TEXT         NOT NULL CHECK (char_length(link_value) BETWEEN 1 AND 2000),
  start_at    TIMESTAMPTZ,
  end_at      TIMESTAMPTZ,
  is_active   BOOLEAN      NOT NULL DEFAULT true,
  archived_at TIMESTAMPTZ,                              -- soft-delete marker (R-170)
  created_by  UUID         REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  -- Both-or-neither bilingual caption (R-172).
  CONSTRAINT ads_caption_both_or_neither CHECK (
    (caption_ar IS NULL AND caption_en IS NULL)
    OR (caption_ar IS NOT NULL AND caption_en IS NOT NULL)
  ),
  -- Valid schedule window (R-170 / edge case): start strictly before end when both set.
  CONSTRAINT ads_window_valid CHECK (start_at IS NULL OR end_at IS NULL OR start_at < end_at)
);

-- Index supporting the serving-view eligibility filter.
CREATE INDEX IF NOT EXISTS idx_ads_active_window
  ON public.ads (is_active, archived_at, start_at, end_at);

ALTER TABLE public.ads ENABLE ROW LEVEL SECURITY;

-- Admin-only direct table read (drafts/inactive/expired/archived). Public reads via v_ads_serving.
DROP POLICY IF EXISTS ads_select_admin ON public.ads;
CREATE POLICY ads_select_admin ON public.ads
  FOR SELECT TO authenticated
  USING (public.current_user_has_permission('ads.manage'));

-- No INSERT/UPDATE/DELETE policy: writes are exclusively via the SECURITY DEFINER
-- RPCs (create_ad/update_ad/set_ad_active/archive_ad, migration …011). RPC-only (R-165, FR-019).
REVOKE INSERT, UPDATE, DELETE ON public.ads FROM authenticated, anon;

-- Reuse the Phase 4 updated_at trigger fn.
DROP TRIGGER IF EXISTS trg_ads_updated_at ON public.ads;
CREATE TRIGGER trg_ads_updated_at
  BEFORE UPDATE ON public.ads
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
```

## Migration `20260601120007_create_ad_placements.sql`

```sql
-- Phase 21 — ad ↔ placement mapping with per-placement carousel priority.
CREATE TABLE IF NOT EXISTS public.ad_placements (
  ad_id         UUID    NOT NULL REFERENCES public.ads(id) ON DELETE CASCADE,
  placement_key TEXT    NOT NULL
                  CHECK (placement_key IN (
                    'home_top_banner','home_middle_banner','search_results_banner',
                    'listing_details_banner','category_banner')),
  priority      INTEGER NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (ad_id, placement_key)
);

CREATE INDEX IF NOT EXISTS idx_ad_placements_key_priority
  ON public.ad_placements (placement_key, priority DESC, created_at DESC);

ALTER TABLE public.ad_placements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ad_placements_select_admin ON public.ad_placements;
CREATE POLICY ad_placements_select_admin ON public.ad_placements
  FOR SELECT TO authenticated
  USING (public.current_user_has_permission('ads.manage'));

REVOKE INSERT, UPDATE, DELETE ON public.ad_placements FROM authenticated, anon;
```

## Migration `20260601120008_create_ad_impressions.sql`

```sql
-- Phase 21 — click events (clicks ONLY in v1; kind CHECK locked to 'click', R-168).
-- Named ad_impressions per plan §6.2; admin-read-only; RPC-only write (record_ad_event).
CREATE TABLE IF NOT EXISTS public.ad_impressions (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  ad_id         UUID        NOT NULL REFERENCES public.ads(id) ON DELETE CASCADE,
  placement_key TEXT        NOT NULL
                  CHECK (placement_key IN (
                    'home_top_banner','home_middle_banner','search_results_banner',
                    'listing_details_banner','category_banner')),
  user_id       UUID        REFERENCES auth.users(id) ON DELETE SET NULL,  -- null = anonymous
  kind          TEXT        NOT NULL DEFAULT 'click' CHECK (kind IN ('click')),
  metadata      JSONB,
  occurred_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ad_impressions_ad_kind
  ON public.ad_impressions (ad_id, kind, occurred_at DESC);

ALTER TABLE public.ad_impressions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ad_impressions_select_admin ON public.ad_impressions;
CREATE POLICY ad_impressions_select_admin ON public.ad_impressions
  FOR SELECT TO authenticated
  USING (public.current_user_has_permission('ads.manage'));

-- Writes ONLY via record_ad_event SECURITY DEFINER RPC (…012). No client write.
REVOKE INSERT, UPDATE, DELETE ON public.ad_impressions FROM authenticated, anon;
```

## Migration `20260601120009_create_v_ads_serving.sql`

```sql
-- Phase 21 — public serving projection. SECURITY DEFINER (no security_invoker), so it
-- bypasses the admin-only base-table SELECT policy and returns ONLY eligible rows (R-166).
-- Exposes ONLY render+tap fields — no title/schedule/created_by/is_active (FR-020).
CREATE OR REPLACE VIEW public.v_ads_serving AS
SELECT
  a.id            AS ad_id,
  a.image_path,
  a.caption_ar,
  a.caption_en,
  a.link_kind,
  a.link_value,
  p.placement_key,
  p.priority
FROM public.ads a
JOIN public.ad_placements p ON p.ad_id = a.id
WHERE a.is_active = true
  AND a.archived_at IS NULL
  AND (a.start_at IS NULL OR a.start_at <= now())
  AND (a.end_at   IS NULL OR a.end_at   >  now());

-- New views default to anon EXECUTE/SELECT — keep it but be explicit (memory: project_supabase_view_rls_gotchas).
GRANT SELECT ON public.v_ads_serving TO anon, authenticated;
```

> Client serving query (PD datasource): `select(...).eq('placement_key', <key>).order('priority', ascending:false).order('ad_id')` — bounded per placement (FR-013). Carousel order honors `priority DESC` then a stable tie-break.

## Migration `20260601120010_create_ads_storage.sql`

```sql
-- Phase 21 — public 'ads' banner bucket. Public read; ads.manage write; path {uuid}/{file} (R-174).
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('ads', 'ads', true, 5242880, ARRAY['image/jpeg','image/png','image/webp'])
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Public read of all banner images (non-sensitive promotional art; eligibility is filtered
-- at the data layer by v_ads_serving, so an archived ad's image is simply unreferenced).
DROP POLICY IF EXISTS "ads_public_select" ON storage.objects;
CREATE POLICY "ads_public_select" ON storage.objects
  FOR SELECT TO anon, authenticated
  USING (bucket_id = 'ads');

-- ads.manage write (insert/update/delete), path-shape {uuid}/{filename}.
DROP POLICY IF EXISTS "ads_admin_write" ON storage.objects;
CREATE POLICY "ads_admin_write" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'ads'
    AND public.current_user_has_permission('ads.manage')
    AND name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/.+$'
  );

DROP POLICY IF EXISTS "ads_admin_update" ON storage.objects;
CREATE POLICY "ads_admin_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'ads' AND public.current_user_has_permission('ads.manage'));

DROP POLICY IF EXISTS "ads_admin_delete" ON storage.objects;
CREATE POLICY "ads_admin_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'ads' AND public.current_user_has_permission('ads.manage'));
```

## Migration `20260601120011_create_ad_write_rpcs.sql`

```sql
-- Phase 21 — admin write RPCs. SECURITY DEFINER; each re-checks ads.manage (FR-019, R-165).
-- Placements passed as JSONB array: '[{"placement_key":"home_top_banner","priority":10}, ...]'.

CREATE OR REPLACE FUNCTION public.create_ad(
  p_title       TEXT,
  p_image_path  TEXT,
  p_caption_ar  TEXT,
  p_caption_en  TEXT,
  p_link_kind   TEXT,
  p_link_value  TEXT,
  p_start_at    TIMESTAMPTZ,
  p_end_at      TIMESTAMPTZ,
  p_is_active   BOOLEAN,
  p_placements  JSONB
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_ad_id UUID;
  v_elem  JSONB;
BEGIN
  IF NOT public.current_user_has_permission('ads.manage') THEN
    RAISE EXCEPTION 'permission_denied' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.ads (
    title, image_path, caption_ar, caption_en, link_kind, link_value,
    start_at, end_at, is_active, created_by
  ) VALUES (
    p_title, p_image_path, p_caption_ar, p_caption_en, p_link_kind, p_link_value,
    p_start_at, p_end_at, COALESCE(p_is_active, true), auth.uid()
  ) RETURNING id INTO v_ad_id;

  IF p_placements IS NOT NULL THEN
    FOR v_elem IN SELECT * FROM jsonb_array_elements(p_placements) LOOP
      INSERT INTO public.ad_placements (ad_id, placement_key, priority)
      VALUES (v_ad_id, v_elem->>'placement_key', COALESCE((v_elem->>'priority')::int, 0));
    END LOOP;
  END IF;

  RETURN v_ad_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_ad(
  p_ad_id       UUID,
  p_title       TEXT,
  p_image_path  TEXT,
  p_caption_ar  TEXT,
  p_caption_en  TEXT,
  p_link_kind   TEXT,
  p_link_value  TEXT,
  p_start_at    TIMESTAMPTZ,
  p_end_at      TIMESTAMPTZ,
  p_is_active   BOOLEAN,
  p_placements  JSONB
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_elem JSONB;
BEGIN
  IF NOT public.current_user_has_permission('ads.manage') THEN
    RAISE EXCEPTION 'permission_denied' USING ERRCODE = '42501';
  END IF;

  UPDATE public.ads SET
    title = p_title, image_path = p_image_path,
    caption_ar = p_caption_ar, caption_en = p_caption_en,
    link_kind = p_link_kind, link_value = p_link_value,
    start_at = p_start_at, end_at = p_end_at, is_active = p_is_active
  WHERE id = p_ad_id AND archived_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ad_not_found' USING ERRCODE = '23503';
  END IF;

  -- Replace placement set atomically.
  DELETE FROM public.ad_placements WHERE ad_id = p_ad_id;
  IF p_placements IS NOT NULL THEN
    FOR v_elem IN SELECT * FROM jsonb_array_elements(p_placements) LOOP
      INSERT INTO public.ad_placements (ad_id, placement_key, priority)
      VALUES (p_ad_id, v_elem->>'placement_key', COALESCE((v_elem->>'priority')::int, 0));
    END LOOP;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_ad_active(p_ad_id UUID, p_is_active BOOLEAN)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.current_user_has_permission('ads.manage') THEN
    RAISE EXCEPTION 'permission_denied' USING ERRCODE = '42501';
  END IF;
  UPDATE public.ads SET is_active = p_is_active WHERE id = p_ad_id AND archived_at IS NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'ad_not_found' USING ERRCODE = '23503'; END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.archive_ad(p_ad_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.current_user_has_permission('ads.manage') THEN
    RAISE EXCEPTION 'permission_denied' USING ERRCODE = '42501';
  END IF;
  UPDATE public.ads SET archived_at = now() WHERE id = p_ad_id AND archived_at IS NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'ad_not_found' USING ERRCODE = '23503'; END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.create_ad(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TIMESTAMPTZ,TIMESTAMPTZ,BOOLEAN,JSONB) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.update_ad(UUID,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TIMESTAMPTZ,TIMESTAMPTZ,BOOLEAN,JSONB) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_ad_active(UUID,BOOLEAN) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.archive_ad(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_ad(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TIMESTAMPTZ,TIMESTAMPTZ,BOOLEAN,JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_ad(UUID,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TIMESTAMPTZ,TIMESTAMPTZ,BOOLEAN,JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_ad_active(UUID,BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.archive_ad(UUID) TO authenticated;
```

## Migration `20260601120012_create_record_ad_event_rpc.sql`

```sql
-- Phase 21 — public click recorder. Mirrors Phase 16 record_lead_event (R-167).
-- Validates the ad is eligible + assigned to the placement, then inserts a 'click'.
CREATE OR REPLACE FUNCTION public.record_ad_event(
  p_ad_id        UUID,
  p_placement_key TEXT
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
DECLARE
  v_event_id   UUID;
  v_ip         INET;
  v_user_agent TEXT;
BEGIN
  -- Eligibility + assignment gate (no permission needed — public recorder).
  IF NOT EXISTS (
    SELECT 1
    FROM public.ads a
    JOIN public.ad_placements p ON p.ad_id = a.id
    WHERE a.id = p_ad_id
      AND p.placement_key = p_placement_key
      AND a.is_active = true
      AND a.archived_at IS NULL
      AND (a.start_at IS NULL OR a.start_at <= now())
      AND (a.end_at   IS NULL OR a.end_at   >  now())
  ) THEN
    RAISE EXCEPTION 'ad_not_eligible' USING ERRCODE = '23514';
  END IF;

  v_ip := inet_client_addr();
  BEGIN
    v_user_agent := current_setting('request.headers', true)::jsonb->>'user-agent';
  EXCEPTION WHEN OTHERS THEN v_user_agent := NULL;
  END;

  v_event_id := gen_random_uuid();
  INSERT INTO public.ad_impressions (id, ad_id, placement_key, user_id, kind, metadata, occurred_at)
  VALUES (v_event_id, p_ad_id, p_placement_key, auth.uid(), 'click',
          jsonb_build_object('ip', v_ip::text, 'user_agent', v_user_agent), now());

  RETURN v_event_id;
END;
$$;

REVOKE ALL ON FUNCTION public.record_ad_event(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_ad_event(UUID, TEXT) TO authenticated, anon;
```

## Migration `20260601120013_create_ad_audit_triggers.sql`

```sql
-- Phase 21 — audit ad creation + soft-delete (FR-007 / §9.4). Reuses Phase 4 log_audit().
-- Actor = auth.uid() (admin RPCs run under the admin's JWT; SECURITY DEFINER changes role, not uid).
DROP TRIGGER IF EXISTS trg_ads_audit_created ON public.ads;
CREATE TRIGGER trg_ads_audit_created
  AFTER INSERT ON public.ads
  FOR EACH ROW
  EXECUTE FUNCTION log_audit('ad.created', 'title,link_kind,is_active', 'id');

DROP TRIGGER IF EXISTS trg_ads_audit_deleted ON public.ads;
CREATE TRIGGER trg_ads_audit_deleted
  AFTER UPDATE OF archived_at ON public.ads
  FOR EACH ROW
  WHEN (OLD.archived_at IS NULL AND NEW.archived_at IS NOT NULL)
  EXECUTE FUNCTION log_audit('ad.deleted', 'archived_at', 'id');

-- Additive (per Assumptions): activation/deactivation audit.
DROP TRIGGER IF EXISTS trg_ads_audit_activation ON public.ads;
CREATE TRIGGER trg_ads_audit_activation
  AFTER UPDATE OF is_active ON public.ads
  FOR EACH ROW
  WHEN (OLD.is_active IS DISTINCT FROM NEW.is_active)
  EXECUTE FUNCTION log_audit('ad.activation_changed', 'is_active', 'id');
```

## Migration `20260601120014_phase21_advisor_hardening.sql`

```sql
-- Phase 21 — advisor hardening. Pin search_path on the new SECURITY DEFINER functions
-- (defense-in-depth) and confirm the view's grants. Idempotent ALTERs.
ALTER FUNCTION public.create_ad(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TIMESTAMPTZ,TIMESTAMPTZ,BOOLEAN,JSONB) SET search_path = public;
ALTER FUNCTION public.update_ad(UUID,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TIMESTAMPTZ,TIMESTAMPTZ,BOOLEAN,JSONB) SET search_path = public;
ALTER FUNCTION public.set_ad_active(UUID,BOOLEAN) SET search_path = public;
ALTER FUNCTION public.archive_ad(UUID) SET search_path = public;
ALTER FUNCTION public.record_ad_event(UUID,TEXT) SET search_path = pg_catalog, public;
-- Run get_advisors after applying all Phase 21 migrations; resolve any SECURITY DEFINER /
-- function-search-path / RLS advisories before merge (memory: project_supabase_view_rls_gotchas).
```

---

## Dart domain entities (`lib/features/ads/domain/entities/`)

```dart
// ad_link.dart
enum AdLinkKind { external, listing, search, category, agency }

// ad_placement.dart
enum AdPlacement {
  homeTopBanner, homeMiddleBanner, searchResultsBanner,
  listingDetailsBanner, categoryBanner,
}
// wire-key mapping: homeTopBanner <-> 'home_top_banner', etc.

// ad_status.dart  — DERIVED, never stored (R-171)
enum AdStatus { active, scheduled, expired, inactive, archived }

// ad.dart  (admin view of an ad)
class Ad extends Equatable {
  final String id;
  final String title;            // internal label
  final String imagePath;        // 'ads' bucket path
  final String? captionAr;       // optional bilingual caption (R-172)
  final String? captionEn;
  final AdLinkKind linkKind;
  final String linkValue;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool isActive;
  final DateTime? archivedAt;
  final List<AdPlacementAssignment> placements;
  final DateTime createdAt;
  // status computed from isActive + start/end vs now + archivedAt (R-171).
}

// ad_placement_assignment.dart
class AdPlacementAssignment extends Equatable {
  final AdPlacement placement;
  final int priority;
}

// serving_ad.dart  (public projection from v_ads_serving)
class ServingAd extends Equatable {
  final String adId;
  final String imagePath;
  final String? captionAr;
  final String? captionEn;
  final AdLinkKind linkKind;
  final String linkValue;
  final AdPlacement placement;
  final int priority;
}
```

**Repositories (`domain/repositories/`)** — return `Result<T>` / `Failure`:

- `AdsAdminRepository`: `createAd(...)`, `updateAd(...)`, `setAdActive(id, active)`, `archiveAd(id)`, `loadAds({includeArchived})`, `uploadAdImage(bytes, contentType) → imagePath`.
- `AdsServingRepository`: `loadServingAds(AdPlacement) → List<ServingAd>`, `recordClick(adId, AdPlacement)`.

**Link-target encoding (`link_kind` → `link_value`, R-179)**:

| `link_kind` | `link_value` holds | opens |
|-------------|--------------------|-------|
| `external` | absolute web URL | external browser/handler |
| `listing` | listing UUID | `/listings/:id` |
| `agency` | agency UUID | `/agency/:id` |
| `category` | property-type key (apartment/villa/land/shop/office/farm/warehouse/other) | search filtered to that type |
| `search` | free-text query string | search pre-filled with the text (v1 = text only; full filter serialization deferred) |

`image_path` (R-180) is a Storage path in the `ads` bucket — NOT a URL; the client resolves the display URL via `getPublicUrl(image_path)`.

---

## Per-FR verification map

| FR | Mechanism | Verify |
|----|-----------|--------|
| FR-001 | `create_ad` RPC + `AdEditorPage` | Create ad with all fields → row in `ads` + rows in `ad_placements` |
| FR-002 | `ads` bucket upload + `caption_ar/en` both-or-neither CHECK | Upload image; save with/without caption; both-null or both-set accepted, one-null rejected |
| FR-003 | `link_kind`+`link_value` + `link_target_picker` | Each of external/listing/search/category/agency persists |
| FR-004 | `ad_placements` PK + priority | Assign to ≥1 placement w/ priority; rows present |
| FR-005 | `start_at/end_at` + `ads_window_valid` CHECK | start≥end rejected by form + DB |
| FR-006 | `archive_ad` (`archived_at`) + admin archived filter | Delete → archived, hidden, click history retained |
| FR-007 | `trg_ads_audit_created` + `trg_ads_audit_deleted` | `audit_logs` rows for `ad.created` + `ad.deleted` |
| FR-008 | `AppRoutes.adminAds` + `requireAdsManageRedirect` + dashboard tile flip | Ads tile navigable; non-holder redirected `/admin?denied=ads` |
| FR-009 | `AdSlot` on home/search/details + `v_ads_serving` | Eligible ad appears in each placement |
| FR-010 | `ad_carousel.dart` (PageView+Timer+swipe) order `priority DESC` | ≥2 ads rotate by priority; 1 ad static |
| FR-011 | `v_ads_serving` WHERE (active+not-archived+in-window) | Ineligible ad never on wire; expiry auto-hides next read |
| FR-012 | `AdSlot` → `SizedBox.shrink()` when empty | No box/reflow when no eligible ad |
| FR-013 | `.eq('placement_key', …)` bounded query | No full-table fetch; per-placement only |
| FR-014 | placement picker signals `category_banner` not-live | category assignment flagged/omitted |
| FR-015 | `launchUrl(...externalApplication)` / `context.push` deep links | external opens; in-app navigates |
| FR-016 | `record_ad_event` RPC, kind='click' only | click row written; no impression row on display |
| FR-017 | tap handler: record → then open, best-effort | offline tap still opens target |
| FR-018 | graceful fallback on unresolved target | deleted-listing / bad-URL → localized message, no crash |
| FR-019 | RPCs re-check `ads.manage` + REVOKE writes | non-holder wire-level create/update/delete denied |
| FR-020 | `v_ads_serving` exposes only serving fields | anon read returns no drafts/archived/admin fields |
| FR-021 | `ads` bucket write policy + `ad_impressions` REVOKE | non-holder bucket write denied; client `ad_impressions` insert denied |
| FR-022 | `PermissionChecker.has(adsManage)` + RLS, no role branch | grant/revoke `ads.manage` reshapes access, no code change |
| FR-023 | l10n keys (chrome) + admin-authored captions | all UI strings ar+en; caption per-locale |
| FR-024 | Phase 2 tokens, direction-aware | 4-combination render correct |
| FR-025 | no pubspec change | `git diff pubspec.yaml` empty |
| FR-026 | no catalog/seed change, no ad network | `ads.manage` seed unchanged; no AdMob dep |

## Per-SC verification map

| SC | Verify (see quickstart.md for steps) |
|----|--------|
| SC-001 | Create ad <3 min; non-admin no tile + wire-denied |
| SC-002 | `home_top_banner` ad visible <2 s on home (+ search/details) |
| SC-003 | ≥2 ads rotate by priority, auto-advance + swipe; 1 ad static |
| SC-004 | expired/inactive auto-hidden; future-start hidden until start |
| SC-005 | external URL opens; in-app deep link navigates |
| SC-006 | `SELECT COUNT(*) FROM ad_impressions WHERE ad_id='…' AND kind='click'` == taps; no impression rows |
| SC-007 | offline tap still opens target |
| SC-008 | non-holder wire-level write denied (ads/placements/bucket/impressions); anon read = eligible only |
| SC-009 | empty placement = no reflow |
| SC-010 | 4-combination render correct on device |
| SC-011 | `SELECT * FROM audit_logs WHERE target_type='ads' ORDER BY created_at DESC` shows create+delete |
| SC-012 | grant/revoke `ads.manage` toggles tile+surface, no code change |
| SC-013 | repo check: 0 new deps/extensions/manifest/perm-keys/role-branches; no ad network |
