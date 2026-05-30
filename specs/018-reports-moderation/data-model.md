# Data Model — Reports & Moderation

**Feature**: `specs/018-reports-moderation/` | **Date**: 2026-05-29

This document captures the full SQL migration bodies, the Dart domain entities, and a per-FR / per-SC verification map. SQL here is the authoritative draft the Sub-Phase B–E migrations implement (final bodies land as the checked-in `supabase/migrations/20260530120001`–`…008` files). Identifiers, FK behaviors, and grants are normative.

---

## 1. Postgres schema

### 1.1 `public.reports` (migration `20260530120001`)

```sql
-- Phase 18 (spec/018-reports-moderation) — reports table.
-- A signed-in user's complaint about one approved listing. Reporter-self +
-- reports.manage read; creation via submit_report RPC only; resolution/claim
-- via privileged paths only (see 20260530120003 policies, ...006/...007 RPCs).

CREATE TABLE IF NOT EXISTS public.reports (
  id                    UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id            UUID         NOT NULL REFERENCES public.listings(id)  ON DELETE RESTRICT,
  reporter_user_id      UUID         NOT NULL REFERENCES auth.users(id)       ON DELETE CASCADE,
  reason                TEXT         NOT NULL
                          CHECK (reason IN (
                            'fake_listing','wrong_price','already_sold_or_rented',
                            'duplicate','spam','wrong_location',
                            'inappropriate_content','other')),
  note                  TEXT         CHECK (note IS NULL OR char_length(note) <= 1000),
  status                TEXT         NOT NULL DEFAULT 'new'
                          CHECK (status IN ('new','reviewing','resolved','dismissed')),
  reviewing_by          UUID         REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewing_started_at  TIMESTAMPTZ,
  resolved_by           UUID         REFERENCES auth.users(id) ON DELETE SET NULL,
  resolved_at           TIMESTAMPTZ,
  resolution            TEXT,
  metadata              JSONB,        -- optional reporter IP / user-agent (FR-010(e))
  created_at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Admin queue: newest-first by status.
CREATE INDEX IF NOT EXISTS idx_reports_status_created
  ON public.reports (status, created_at DESC);

-- My-Reports + per-listing reporter-banner lookup.
CREATE INDEX IF NOT EXISTS idx_reports_reporter_created
  ON public.reports (reporter_user_id, created_at DESC);

-- FK + sibling-resolve scan.
CREATE INDEX IF NOT EXISTS idx_reports_listing
  ON public.reports (listing_id);

-- Open-report dedup (FR-004): at most one OPEN report per (reporter, listing).
CREATE UNIQUE INDEX IF NOT EXISTS ux_reports_open_per_reporter_listing
  ON public.reports (reporter_user_id, listing_id)
  WHERE status IN ('new','reviewing');

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
```

### 1.2 `public.moderation_actions` (migration `20260530120002`)

```sql
-- Phase 18 — moderation_actions table (append-only). One row per resolved
-- report (the triggering report + any auto-resolved siblings). reports.manage
-- read only; written only by resolve_report_internal. target_id is a plain
-- column (no FK) so the audit log is decoupled from listing lifecycle (R-131).

CREATE TABLE IF NOT EXISTS public.moderation_actions (
  id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  target_type   TEXT         NOT NULL DEFAULT 'listing'
                  CHECK (target_type IN ('listing')),
  target_id     UUID         NOT NULL,
  report_id     UUID         REFERENCES public.reports(id) ON DELETE SET NULL,
  action        TEXT         NOT NULL
                  CHECK (action IN ('dismiss','hide','mark_duplicate','delete')),
  performed_by  UUID         REFERENCES auth.users(id) ON DELETE SET NULL,
  performed_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  reason        TEXT,
  before_state  JSONB,
  after_state   JSONB
);

CREATE INDEX IF NOT EXISTS idx_moderation_actions_target
  ON public.moderation_actions (target_type, target_id, performed_at DESC);

ALTER TABLE public.moderation_actions ENABLE ROW LEVEL SECURITY;
```

### 1.3 Policies (migration `20260530120003`)

```sql
-- reports: reporter-self OR reports.manage read; no client write.
CREATE POLICY reports_select_self_or_admin
  ON public.reports
  FOR SELECT
  TO authenticated
  USING (
    reporter_user_id = auth.uid()
    OR public.current_user_has_permission('reports.manage')
  );

REVOKE INSERT, UPDATE, DELETE ON public.reports FROM authenticated, anon;
-- (No anon SELECT policy ⇒ anonymous reads denied entirely.)

-- moderation_actions: reports.manage read; no client write.
CREATE POLICY moderation_actions_select_admin
  ON public.moderation_actions
  FOR SELECT
  TO authenticated
  USING (public.current_user_has_permission('reports.manage'));

REVOKE INSERT, UPDATE, DELETE ON public.moderation_actions FROM authenticated, anon;
```

### 1.4 `public.v_reports` view (migration `20260530120004`)

```sql
-- SECURITY INVOKER so the base-table reports RLS scopes view reads
-- (reporter sees own rows; reports.manage sees all). NOT filtered on
-- listing status — reports about non-approved listings still appear.
CREATE OR REPLACE VIEW public.v_reports
WITH (security_invoker = true) AS
SELECT
  r.id,
  r.listing_id,
  r.reporter_user_id,
  r.reason,
  r.note,
  r.status,
  r.reviewing_by,
  r.resolved_by,
  r.resolution,
  r.created_at,
  r.resolved_at,
  l.title                              AS listing_title,
  l.status                             AS listing_status,
  lm.storage_path                      AS main_image_path,
  g.display_name->>'ar'                AS governorate_name_ar,
  g.display_name->>'en'                AS governorate_name_en,
  c.display_name->>'ar'                AS city_name_ar,
  c.display_name->>'en'                AS city_name_en
FROM public.reports r
JOIN public.listings l        ON l.id = r.listing_id
LEFT JOIN public.governorates g ON g.id = l.governorate_id
LEFT JOIN public.cities      c ON c.id = l.city_id
LEFT JOIN LATERAL (
  SELECT m.storage_path
  FROM public.listing_media m
  WHERE m.listing_id = l.id AND m.is_main = true
  ORDER BY m.ordering
  LIMIT 1
) lm ON true;

GRANT SELECT ON public.v_reports TO authenticated;
```

### 1.5 Reports resolution-audit trigger (migration `20260530120005`)

```sql
-- Reuses the Phase 4 log_audit() trigger fn (20260506120004). Actor comes
-- from app.current_user_id set by resolve_report_internal.
CREATE TRIGGER trg_reports_audit_resolution
  AFTER UPDATE OF status ON public.reports
  FOR EACH ROW
  WHEN (NEW.status IN ('resolved','dismissed')
        AND OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION log_audit('report.resolved', 'status,resolution,resolved_by', 'id');
```

### 1.6 `submit_report` RPC (migration `20260530120006`)

```sql
CREATE OR REPLACE FUNCTION public.submit_report(
  p_listing_id UUID,
  p_reason     TEXT,
  p_note       TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_uid    UUID := auth.uid();
  v_status TEXT;
  v_id     UUID;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '28000';
  END IF;

  IF p_reason NOT IN ('fake_listing','wrong_price','already_sold_or_rented',
                      'duplicate','spam','wrong_location',
                      'inappropriate_content','other') THEN
    RAISE EXCEPTION 'invalid_reason' USING ERRCODE = '22023';
  END IF;

  SELECT l.status INTO v_status FROM public.listings l WHERE l.id = p_listing_id;
  IF v_status IS NULL THEN
    RAISE EXCEPTION 'listing_not_found' USING ERRCODE = '23503';
  END IF;
  IF v_status <> 'approved' THEN
    RAISE EXCEPTION 'listing_not_approved' USING ERRCODE = '23514';
  END IF;

  -- Open-report dedup (FR-004). The partial unique index is the race backstop.
  IF EXISTS (
    SELECT 1 FROM public.reports
    WHERE reporter_user_id = v_uid
      AND listing_id = p_listing_id
      AND status IN ('new','reviewing')
  ) THEN
    RAISE EXCEPTION 'already_reported' USING ERRCODE = '23505';
  END IF;

  INSERT INTO public.reports (listing_id, reporter_user_id, reason, note, status, metadata)
  VALUES (
    p_listing_id, v_uid, p_reason, NULLIF(p_note, ''), 'new',
    jsonb_build_object(
      'ip', inet_client_addr()::text,
      'user_agent', current_setting('request.headers', true)::jsonb->>'user-agent'
    )                                            -- FR-010(e), mirrors record_lead_event
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.submit_report(UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_report(UUID, TEXT, TEXT) TO authenticated;
```

### 1.7 `resolve_report_internal` + `start_report_review` RPCs (migration `20260530120007`)

```sql
-- ─── resolve_report_internal (service_role only) ───
-- Mirrors the Phase 12 approve_reject_atomic_wrappers (20260523120005):
-- sets app.current_user_id so the existing listing triggers + the reports
-- audit trigger attribute the actor; performs report update + moderation_actions
-- insert + listing transition + sibling auto-resolve in ONE transaction.
CREATE OR REPLACE FUNCTION public.resolve_report_internal(
  p_report_id     UUID,
  p_actor_user_id UUID,
  p_action        TEXT,
  p_note          TEXT DEFAULT NULL
)
RETURNS TABLE(report_id UUID, report_status TEXT, listing_id UUID, listing_status TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_listing_id   UUID;
  v_open_status  TEXT;
  v_before       JSONB;
  v_after        JSONB;
  v_new_report   TEXT;
  v_sib          RECORD;
BEGIN
  PERFORM set_config('app.current_user_id', p_actor_user_id::text, true);

  IF p_action NOT IN ('dismiss','hide','mark_duplicate','delete') THEN
    RAISE EXCEPTION 'invalid_action' USING ERRCODE = '22023';
  END IF;

  SELECT r.listing_id, r.status INTO v_listing_id, v_open_status
  FROM public.reports r WHERE r.id = p_report_id;
  IF v_listing_id IS NULL THEN
    RAISE EXCEPTION 'report_not_found' USING ERRCODE = '23503';
  END IF;
  IF v_open_status NOT IN ('new','reviewing') THEN
    RAISE EXCEPTION 'already_resolved' USING ERRCODE = '23514';   -- SC-015
  END IF;

  SELECT jsonb_build_object('status', l.status, 'title', l.title)
    INTO v_before FROM public.listings l WHERE l.id = v_listing_id;

  v_new_report := CASE WHEN p_action = 'dismiss' THEN 'dismissed' ELSE 'resolved' END;

  UPDATE public.reports
     SET status = v_new_report, resolved_by = p_actor_user_id,
         resolved_at = now(), resolution = p_action
   WHERE id = p_report_id;

  -- Listing transition (Q1=A). The existing listing triggers fire here.
  IF p_action = 'hide' THEN
    UPDATE public.listings SET status = 'paused'
      WHERE id = v_listing_id AND status = 'approved';
  ELSIF p_action = 'mark_duplicate' THEN
    PERFORM set_config('app.current_rejection_reason', 'duplicate', true);
    UPDATE public.listings SET status = 'rejected'
      WHERE id = v_listing_id AND status = 'approved';
  ELSIF p_action = 'delete' THEN
    UPDATE public.listings SET status = 'deleted'
      WHERE id = v_listing_id AND status IN ('approved','paused','rejected');
  END IF;  -- dismiss: no listing change.

  SELECT jsonb_build_object('status', l.status, 'title', l.title)
    INTO v_after FROM public.listings l WHERE l.id = v_listing_id;

  INSERT INTO public.moderation_actions
    (target_type, target_id, report_id, action, performed_by, reason, before_state, after_state)
  VALUES ('listing', v_listing_id, p_report_id, p_action, p_actor_user_id, p_note, v_before, v_after);

  -- Sibling auto-resolve (Q5=A) — only for listing-affecting actions.
  -- NOTE: alias the reports table (sib) — the OUT param `listing_id` would
  -- otherwise make a bare `WHERE listing_id = …` ambiguous (fixed in
  -- 20260530120009 after device QA).
  IF p_action <> 'dismiss' THEN
    FOR v_sib IN
      SELECT sib.id AS sib_id
      FROM public.reports sib
      WHERE sib.listing_id = v_listing_id
        AND sib.id <> p_report_id
        AND sib.status IN ('new','reviewing')
    LOOP
      UPDATE public.reports
         SET status = 'resolved', resolved_by = p_actor_user_id,
             resolved_at = now(), resolution = p_action
       WHERE id = v_sib.sib_id;
      INSERT INTO public.moderation_actions
        (target_type, target_id, report_id, action, performed_by, reason, before_state, after_state)
      VALUES ('listing', v_listing_id, v_sib.sib_id, p_action, p_actor_user_id,
              'auto-resolved: listing actioned via report ' || p_report_id::text,
              v_before, v_after);
    END LOOP;
  END IF;

  RETURN QUERY
    SELECT p_report_id, v_new_report, v_listing_id,
           (SELECT l.status FROM public.listings l WHERE l.id = v_listing_id);
END;
$$;

REVOKE ALL ON FUNCTION public.resolve_report_internal(UUID, UUID, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.resolve_report_internal(UUID, UUID, TEXT, TEXT) FROM anon;
REVOKE ALL ON FUNCTION public.resolve_report_internal(UUID, UUID, TEXT, TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_report_internal(UUID, UUID, TEXT, TEXT) TO service_role;

-- ─── start_report_review (authenticated; self-gates on reports.manage) ───
CREATE OR REPLACE FUNCTION public.start_report_review(p_report_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.current_user_has_permission('reports.manage') THEN
    RAISE EXCEPTION 'permission_denied' USING ERRCODE = '42501';
  END IF;
  -- Advisory soft lock: only claims a still-`new` report; an already-`reviewing`
  -- report is left to its current reviewer but remains resolvable by anyone.
  UPDATE public.reports
     SET status = 'reviewing', reviewing_by = auth.uid(), reviewing_started_at = now()
   WHERE id = p_report_id AND status = 'new';
END;
$$;

REVOKE ALL ON FUNCTION public.start_report_review(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.start_report_review(UUID) TO authenticated;
```

### 1.8 Advisor hardening (migration `20260530120008`)

Safety-net `ALTER FUNCTION … SET search_path` for the three functions, re-assert the grants (`submit_report` + `start_report_review` → `authenticated`; `resolve_report_internal` → `service_role`), re-assert `REVOKE INSERT, UPDATE, DELETE ON public.reports, public.moderation_actions FROM authenticated, anon`, and `GRANT SELECT ON public.v_reports TO authenticated` — matching the Phase 16/17 advisor-hardening files (`20260527120012` / `20260529120005`).

### 1.9 RLS reader/writer matrix (load-bearing — Principle III)

| Actor | `reports` SELECT | `reports` INSERT | `reports` UPDATE/DELETE | `moderation_actions` SELECT | `moderation_actions` write |
|-------|------------------|------------------|--------------------------|------------------------------|----------------------------|
| Anonymous | ❌ (no anon policy) | ❌ | ❌ | ❌ | ❌ |
| Authenticated reporter | ✅ own rows only | ❌ (RPC only) | ❌ | ❌ | ❌ |
| Authenticated non-reporter (no perm) | ✅ own rows only | ❌ | ❌ | ❌ | ❌ |
| `reports.manage` holder | ✅ ALL rows | ❌ (RPC only) | ❌ (Edge Fn → service-role RPC only) | ✅ ALL rows | ❌ (resolve RPC only) |
| `service_role` (Edge Fn) | n/a (bypasses RLS) | via RPC | via `resolve_report_internal` | n/a | via `resolve_report_internal` |

No publisher path. No aggregate count. No admin client UPDATE. This is IMPLEMENTATION_PLAN §6.4 verbatim.

---

## 2. Dart domain entities (Constitution IX — zero Supabase imports)

### 2.1 `lib/features/reports/domain/entities/report_reason.dart`

```dart
enum ReportReason {
  fakeListing('fake_listing'),
  wrongPrice('wrong_price'),
  alreadySoldOrRented('already_sold_or_rented'),
  duplicate('duplicate'),
  spam('spam'),
  wrongLocation('wrong_location'),
  inappropriateContent('inappropriate_content'),
  other('other');

  const ReportReason(this.wireValue);
  final String wireValue;

  static ReportReason fromWire(String v) =>
      ReportReason.values.firstWhere((e) => e.wireValue == v);
}
```

### 2.2 `lib/features/reports/domain/entities/report_status.dart`

```dart
enum ReportStatus {
  newReport('new'),
  reviewing('reviewing'),
  resolved('resolved'),
  dismissed('dismissed');

  const ReportStatus(this.wireValue);
  final String wireValue;

  bool get isOpen => this == ReportStatus.newReport || this == ReportStatus.reviewing;

  static ReportStatus fromWire(String v) =>
      ReportStatus.values.firstWhere((e) => e.wireValue == v);
}
```

### 2.3 `lib/features/reports/domain/entities/report.dart`

```dart
class Report extends Equatable {
  const Report({
    required this.id,
    required this.listingId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.note,
    this.resolution,
    this.resolvedAt,
    // Joined v_reports listing-card fields (for My-Reports rendering):
    required this.listingTitle,
    required this.listingStatus,        // raw listings.status string
    this.mainImagePath,
    this.governorateNameAr,
    this.governorateNameEn,
    this.cityNameAr,
    this.cityNameEn,
  });

  final String id;
  final String listingId;
  final ReportReason reason;
  final ReportStatus status;
  final DateTime createdAt;
  final String? note;
  final String? resolution;
  final DateTime? resolvedAt;
  final String listingTitle;
  final String listingStatus;
  final String? mainImagePath;
  final String? governorateNameAr;
  final String? governorateNameEn;
  final String? cityNameAr;
  final String? cityNameEn;

  @override
  List<Object?> get props => [id, listingId, reason, status, resolution, resolvedAt];
}
```

### 2.4 `lib/features/admin/reports/domain/entities/moderation_action_type.dart`

```dart
enum ModerationActionType {
  dismiss('dismiss'),
  hide('hide'),
  markDuplicate('mark_duplicate'),
  delete('delete');

  const ModerationActionType(this.wireValue);
  final String wireValue;

  /// True for actions that take the listing off the public surface (FR-016
  /// sibling auto-resolve + FR-017 destructive confirmation).
  bool get isListingAffecting => this != ModerationActionType.dismiss;
}
```

### 2.5 `lib/features/admin/reports/domain/entities/report_queue_item.dart` + `moderation_action.dart`

`ReportQueueItem` extends the `Report`-shaped projection with `reporterUserId` and `reviewingBy` (visible only to `reports.manage` holders via the view). `ModerationAction` (`id`, `targetId`, `reportId`, `action` (`ModerationActionType`), `performedBy`, `performedAt`, `reason`, `beforeState`, `afterState`) is the admin-readable log entity. Both `Equatable`, zero Supabase imports.

### 2.6 Repository interfaces

- `lib/features/reports/domain/repositories/reports_repository.dart` — `submitReport`, `loadMyReports`, `loadMyReportForListing` (returns `Result<T, Failure>`).
- `lib/features/admin/reports/domain/repositories/reports_admin_repository.dart` — `loadQueue`, `startReview`, `resolve` (returns `Result<T, Failure>`).

---

## 3. Per-FR verification map

| FR | Where satisfied |
|----|-----------------|
| FR-001 Report CTA rewire (Share/Favorite untouched) | Sub-Phase H1, `per_listing_action_block.dart` |
| FR-002 Report sheet, 8 reasons + note | H (`report_sheet.dart`) + A (`ReportReason`) |
| FR-003 Insert `reports` row + confirmation | D (`submit_report`) + F + H |
| FR-004 Open-report dedup | B (`ux_reports_open_per_reporter_listing`) + D (`EXISTS` guard) |
| FR-005 Submit failure → retryable error, no partial row | D (RPC transaction) + F + H |
| FR-006 CTA renders for anon | H1 (renders for all) |
| FR-007 Anon tap → prompt + login, no row | H1 (`_onReportTap` anon branch) |
| FR-008 `reports` table columns | §1.1 |
| FR-009 `moderation_actions` table columns | §1.2 |
| FR-010 `submit_report` SECURITY DEFINER (auth + approved + dedup + no client INSERT) | §1.6 + §1.3 |
| FR-011 Indices (queue/reporter/dedup) | §1.1 |
| FR-012 `resolve_report` Edge Fn gate + service-role RPC | E (§1.7 + `index.ts`) |
| FR-013 Atomic resolve (status + action + transition + audit) | §1.7 (single transaction) + §1.5 |
| FR-014 Action → status map (Q1=A) | §1.7 |
| FR-015 Listing-affecting action removes from public surface | §1.7 (non-approved status) + Phase 13 public-read gate |
| FR-016 Sibling auto-resolve (dismiss excepted) | §1.7 sibling loop |
| FR-017 Destructive-action confirmation | I (`resolve_action_dialog.dart`) |
| FR-018 `lib/features/admin/reports/` Clean Architecture | G + I |
| FR-019 Queue gated by `reports.manage` (frontend + RLS) | I1 (`admin_home_page.dart`) + A (`requireReportsManageRedirect`) + §1.3 |
| FR-020 Queue newest-first, status/reason filters, paginated | I (`reports_queue_bloc.dart`) + §1.4 |
| FR-021 Report detail offers 4 actions + confirmation | I (`report_detail_page.dart`) |
| FR-022 "My Reports" page (Profile tile, `/reports`, paginated, empty-state) | A + H + §1.4 |
| FR-023 Reporter-only details banner | H (`reporter_status_banner.dart`) |
| FR-024 My-Reports + banner self-scoped | §1.3 (reporter-self RLS) + §1.4 |
| FR-025 `reports` RLS (reporter-self OR admin read; no client write) | §1.3 |
| FR-026 `moderation_actions` admin-only read; no client write | §1.3 |
| FR-027 No anon read/write either table | §1.3 (no anon policy) |
| FR-028 No publisher report visibility / no count | §1.3 + §1.4 (no publisher path projected) |
| FR-029 All strings localized | J |
| FR-030 4-combination theme×locale render | H + I (token usage) |
| FR-031 Zero new deps | R-119 |
| FR-032 No hardcoded role branch | I1 + A (`PermissionKeys.reportsManage` via `PermissionChecker`) |
| FR-033 Checks at both ends | §1.7 (service-role RPC) + `resolve_report/index.ts` (perm gate) |
| FR-034 Share/Favorite untouched; no `lead_events`/listings-enum change | H1 + R-124 (reuse statuses) |
| FR-035 Reuse `audit_logs` + listing machinery | §1.5 + §1.7 (GUC + existing triggers) |
| FR-036 "Start review" advisory soft claim | §1.7 (`start_report_review`) + I |

## 4. Per-SC verification map

| SC | Verification (see quickstart.md) |
|----|----------------------------------|
| SC-001 | Submit under 30 s; one `reports` row within 2 s |
| SC-002 | Second open-report no-op + "already reported"; fresh report after resolution |
| SC-003 | `reports.manage` sees queue tile + queue; non-admin sees neither |
| SC-004 | dismiss/hide/mark_duplicate/delete → correct listing status + 1 `moderation_actions` + 1 `audit_logs` each |
| SC-005 | Actioned listing leaves public feed/search/map within one refresh |
| SC-006 | `resolve_report_internal` single transaction; zero partial states |
| SC-007 | My-Reports shows only own reports + empty-state |
| SC-008 | Reporter banner reflects status; absent for non-reporters; updates post-resolve |
| SC-009 | Wire-level read matrix: own-only / anon-zero / non-admin-no-queue |
| SC-010 | Unauthorized resolve rejected at Edge Fn AND service-role RPC |
| SC-011 | Anon Report CTA renders; tap writes zero rows + prompt |
| SC-012 | 4-combination theme×locale render on 480 dp + 412 dp |
| SC-013 | Zero new deps; zero hardcoded role branch; no `lead_events`/listings-enum change |
| SC-014 | Queue + My-Reports paginated (LIMIT/cursor) |
| SC-015 | Concurrent resolve → one terminal + one action; second no-ops (`already_resolved`) |
