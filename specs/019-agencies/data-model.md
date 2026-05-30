# Data Model — Agencies

**Feature**: `specs/019-agencies/` | **Date**: 2026-05-30

This document captures the full SQL migration bodies, the Dart domain entities, and a per-FR / per-SC verification map. SQL here is the authoritative draft the Sub-Phase B–E migrations implement (final bodies land as the checked-in `supabase/migrations/20260531120001`–`…013` files). Identifiers, FK behaviors, and grants are normative. All snippets are grounded in the verbatim Phase 4/5/10/11/12/14/18 templates (`account_approval_requests`, `profiles_vault_pii_helpers`, `approve_reject_atomic_wrappers`, `v_listings_public`, `v_reports` definer view, `listing_media` storage policies).

---

## 1. Postgres schema

### 1.1 `public.agencies` + `agency_status` enum (migration `20260531120001`)

```sql
-- Phase 19 (spec/019-agencies) — agencies table.
-- A brokerage owned by exactly one approved publisher. Public read only when
-- status='approved'; owner/active-member read at any status; agencies.view read
-- all. Writes via create_agency RPC + moderate_agency_internal only.

CREATE TYPE agency_status AS ENUM ('pending','approved','rejected','suspended');

CREATE TABLE IF NOT EXISTS public.agencies (
  id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id   UUID          NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  name            TEXT          NOT NULL CHECK (length(trim(name)) > 0),
  description     TEXT,
  phone           TEXT,
  whatsapp        TEXT,
  address         TEXT,
  logo_path       TEXT,
  cover_path      TEXT,
  status          agency_status NOT NULL DEFAULT 'pending',
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- Public directory + admin queue scans.
CREATE INDEX IF NOT EXISTS idx_agencies_status ON public.agencies (status);

-- updated_at maintenance (Phase 4 set_updated_at(), as account_approval_requests uses).
DROP TRIGGER IF EXISTS trg_agencies_set_updated_at ON public.agencies;
CREATE TRIGGER trg_agencies_set_updated_at
  BEFORE UPDATE ON public.agencies
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE public.agencies ENABLE ROW LEVEL SECURITY;
```

### 1.2 `public.agency_members` + membership predicates (migration `20260531120002`)

```sql
-- Phase 19 — agency_members roster. PK (agency_id,user_id) ⇒ one row per
-- (agency,user). member_role admin|agent; status pending(invited)→active→removed.

CREATE TABLE IF NOT EXISTS public.agency_members (
  agency_id    UUID        NOT NULL REFERENCES public.agencies(id) ON DELETE CASCADE,
  user_id      UUID        NOT NULL REFERENCES auth.users(id)      ON DELETE CASCADE,
  member_role  TEXT        NOT NULL CHECK (member_role IN ('admin','agent')),
  status       TEXT        NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending','active','removed')),
  invited_by   UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  joined_at    TIMESTAMPTZ,
  created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
  PRIMARY KEY (agency_id, user_id)
);

-- "My agencies" + "my pending invitations" lookup.
CREATE INDEX IF NOT EXISTS idx_agency_members_user
  ON public.agency_members (user_id, status);

DROP TRIGGER IF EXISTS trg_agency_members_set_updated_at ON public.agency_members;
CREATE TRIGGER trg_agency_members_set_updated_at
  BEFORE UPDATE ON public.agency_members
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE public.agency_members ENABLE ROW LEVEL SECURITY;

-- SECURITY DEFINER membership predicates — used by the RLS policies (avoids the
-- self-referential-RLS recursion an inline EXISTS on agency_members would hit)
-- and by the write RPCs. They bypass RLS (definer) and resolve auth.uid() to the caller.
CREATE OR REPLACE FUNCTION public.is_agency_member(p_agency_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.agency_members m
    WHERE m.agency_id = p_agency_id AND m.user_id = auth.uid() AND m.status = 'active'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_agency_admin(p_agency_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.agency_members m
    WHERE m.agency_id = p_agency_id AND m.user_id = auth.uid()
      AND m.status = 'active' AND m.member_role = 'admin'
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_agency_member(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_agency_admin(UUID)  TO authenticated;
```

### 1.3 `public.agency_verification_requests` (migration `20260531120003`)

```sql
-- Phase 19 — agency verification requests. Structurally mirrors Phase 5
-- account_approval_requests. The ID-document + commercial-registration numbers
-- are NOT columns here — they go to Vault (migration ...007). One open request
-- per agency (ux_agency_open_verification). decision pending→approved/rejected.

CREATE TABLE IF NOT EXISTS public.agency_verification_requests (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_id        UUID        NOT NULL REFERENCES public.agencies(id) ON DELETE CASCADE,
  decision         TEXT        NOT NULL DEFAULT 'pending'
                     CHECK (decision IN ('pending','approved','rejected')),
  decision_reason  TEXT,
  evidence_urls    JSONB,                 -- storage paths in agency-documents bucket
  submitted_by     UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  submitted_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  reviewed_by      UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at      TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT agency_verification_reason_when_rejected CHECK (
    (decision = 'rejected' AND decision_reason IS NOT NULL AND length(trim(decision_reason)) > 0)
    OR (decision <> 'rejected' AND decision_reason IS NULL)
  ),
  CONSTRAINT agency_verification_reviewed_when_decided CHECK (
    (decision IN ('approved','rejected') AND reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)
    OR (decision = 'pending' AND reviewed_by IS NULL AND reviewed_at IS NULL)
  )
);

-- One OPEN (pending) verification request per agency; a fresh request may follow a rejection.
CREATE UNIQUE INDEX IF NOT EXISTS ux_agency_open_verification
  ON public.agency_verification_requests (agency_id) WHERE decision = 'pending';

CREATE INDEX IF NOT EXISTS idx_agency_verification_decision
  ON public.agency_verification_requests (decision, submitted_at DESC);

DROP TRIGGER IF EXISTS trg_agency_verification_set_updated_at ON public.agency_verification_requests;
CREATE TRIGGER trg_agency_verification_set_updated_at
  BEFORE UPDATE ON public.agency_verification_requests
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE public.agency_verification_requests ENABLE ROW LEVEL SECURITY;
```

### 1.4 `listings.agency_id` FK (migration `20260531120004`)

```sql
-- Phase 19 — enforce the FK Phase 10 reserved (R-17). ON DELETE SET NULL so a
-- removed agency leaves its listings intact (they lose only the badge). All
-- existing listings have agency_id = NULL, so the constraint validates instantly.
ALTER TABLE public.listings
  ADD CONSTRAINT fk_listings_agency
  FOREIGN KEY (agency_id) REFERENCES public.agencies(id) ON DELETE SET NULL;
```

### 1.5 Policies + name-unique-among-approved (migration `20260531120005`)

```sql
-- agencies: public(approved) + owner + active member + agencies.view read; no client write.
CREATE POLICY agencies_select_authenticated ON public.agencies
  FOR SELECT TO authenticated
  USING (
    status = 'approved'
    OR owner_user_id = auth.uid()
    OR public.is_agency_member(id)
    OR public.current_user_has_permission('agencies.view')
  );
CREATE POLICY agencies_select_anon ON public.agencies
  FOR SELECT TO anon
  USING (status = 'approved');
REVOKE INSERT, UPDATE, DELETE ON public.agencies FROM authenticated, anon;

-- agency_members: own row + active members of the same agency + agencies.view; no client write.
CREATE POLICY agency_members_select ON public.agency_members
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_agency_member(agency_id)
    OR public.current_user_has_permission('agencies.view')
  );
REVOKE INSERT, UPDATE, DELETE ON public.agency_members FROM authenticated, anon;

-- agency_verification_requests: agency-admin of that agency + agencies.view; no client write.
CREATE POLICY agency_verification_select ON public.agency_verification_requests
  FOR SELECT TO authenticated
  USING (
    public.is_agency_admin(agency_id)
    OR public.current_user_has_permission('agencies.view')
  );
REVOKE INSERT, UPDATE, DELETE ON public.agency_verification_requests FROM authenticated, anon;

-- Name unique among APPROVED agencies only (Q2-clarify). Duplicate pending names may coexist.
CREATE UNIQUE INDEX IF NOT EXISTS ux_agencies_name_approved
  ON public.agencies (lower(name)) WHERE status = 'approved';
```

### 1.6 `v_agencies` view + `v_listings_public` badge amendment (migration `20260531120006`)

```sql
-- v_agencies — SECURITY DEFINER (views are definer unless security_invoker is set;
-- the Phase 18 20260530120010 fix). The explicit WHERE reproduces the public/owner/
-- member/admin read matrix so a member's own PENDING agency stays visible to them
-- (an invoker view would re-apply the agencies RLS and hide it). NEVER projects the
-- Vault id/registration numbers.
CREATE OR REPLACE VIEW public.v_agencies AS
SELECT
  a.id, a.owner_user_id, a.name, a.description, a.phone, a.whatsapp, a.address,
  a.logo_path, a.cover_path, a.status, a.created_at, a.updated_at
FROM public.agencies a
WHERE a.status = 'approved'
   OR a.owner_user_id = auth.uid()
   OR public.is_agency_member(a.id)
   OR public.current_user_has_permission('agencies.view');

GRANT SELECT ON public.v_agencies TO anon, authenticated;

-- Badge amendment — additive LEFT JOIN to APPROVED agencies. Preserves the existing
-- v_listings_public projection + WHERE + security setting (20260525120002). Only
-- listings under an approved agency carry the badge fields; others get NULLs.
CREATE OR REPLACE VIEW public.v_listings_public AS
SELECT
  l.id, l.title, l.address_text, l.property_type, l.purpose,
  l.governorate_id, l.city_id, l.area_id, l.rooms, l.bathrooms, l.area_size,
  l.published_at, l.expires_at, l.search_vector,
  lp.amount        AS primary_amount,
  lp.currency_code AS primary_currency,
  lm.storage_path  AS main_image_path,
  g.display_name->>'ar' AS governorate_name_ar,
  g.display_name->>'en' AS governorate_name_en,
  c.display_name->>'ar' AS city_name_ar,
  c.display_name->>'en' AS city_name_en,
  ag.id            AS agency_id,             -- NEW (FR-022)
  ag.name          AS agency_name,           -- NEW
  ag.logo_path     AS agency_logo_path       -- NEW
FROM public.listings l
LEFT JOIN LATERAL (
  SELECT amount, currency_code FROM public.listing_prices
  WHERE listing_id = l.id AND is_primary = true LIMIT 1
) lp ON true
LEFT JOIN LATERAL (
  SELECT storage_path FROM public.listing_media
  WHERE listing_id = l.id AND kind = 'image' ORDER BY ordering ASC LIMIT 1
) lm ON true
LEFT JOIN public.governorates g ON g.id = l.governorate_id
LEFT JOIN public.cities       c ON c.id = l.city_id
LEFT JOIN public.agencies     ag ON ag.id = l.agency_id AND ag.status = 'approved'   -- NEW
WHERE l.status = 'approved'
  AND (l.expires_at IS NULL OR l.expires_at > now());
```

### 1.7 Agency Vault helpers (migration `20260531120007`)

```sql
-- Admin/agency-admin write of agency identity PII to Vault (ADR-0001 + R-141),
-- mirroring app_vault_set_secret_for_self (20260510120004). secret_name namespace:
-- 'pii.agency.{agency_id}.{field}'. Re-submission overwrites via vault create/update.
CREATE OR REPLACE FUNCTION public.app_vault_set_agency_secret(
  p_agency_id UUID, field_name TEXT, p_value TEXT
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, vault AS $$
DECLARE secret_name TEXT; v_secret_id UUID;
BEGIN
  IF NOT public.is_agency_admin(p_agency_id) THEN
    RAISE EXCEPTION 'permission_denied' USING ERRCODE = '42501';
  END IF;
  IF field_name NOT IN ('id_document_number','commercial_registration_number') THEN
    RAISE EXCEPTION 'invalid field_name: %', field_name USING ERRCODE = '22023';
  END IF;
  secret_name := format('pii.agency.%s.%s', p_agency_id, field_name);
  -- Idempotent: a re-submission after a rejection updates the existing secret rather than
  -- erroring on the duplicate name (vault.create_secret rejects an existing name).
  SELECT id INTO v_secret_id FROM vault.secrets WHERE name = secret_name;
  IF v_secret_id IS NOT NULL THEN
    PERFORM vault.update_secret(v_secret_id, p_value);
  ELSE
    PERFORM vault.create_secret(p_value, secret_name, 'AlNujom agency PII per-agency-per-field');
  END IF;
END;
$$;

-- Admin-only decrypt (R-141 / FR-005). Returns NULL for non-admins (never raises a leak).
CREATE OR REPLACE FUNCTION public.app_vault_secret_for_agency(
  p_agency_id UUID, field_name TEXT
) RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.current_user_has_permission('agencies.view') THEN RETURN NULL; END IF;
  IF field_name NOT IN ('id_document_number','commercial_registration_number') THEN
    RAISE EXCEPTION 'invalid field_name: %', field_name USING ERRCODE = '22023';
  END IF;
  RETURN public.app_vault_secret(format('pii.agency.%s.%s', p_agency_id, field_name));  -- Phase 4 read helper
END;
$$;

REVOKE ALL ON FUNCTION public.app_vault_set_agency_secret(UUID,TEXT,TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.app_vault_set_agency_secret(UUID,TEXT,TEXT) TO authenticated;
REVOKE ALL ON FUNCTION public.app_vault_secret_for_agency(UUID,TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.app_vault_secret_for_agency(UUID,TEXT) TO authenticated;  -- self-gates on agencies.view
```

> **Re-submission**: handled by the update-or-create above — `app_vault_set_agency_secret` looks the secret up by name (`vault.secrets`) and calls `vault.update_secret` when it exists, else `vault.create_secret`. So a rejected agency's re-submission overwrites the prior value and the latest submitted number is the decryptable one (it does not error on the duplicate name).

### 1.8 Agency write RPCs (migration `20260531120008`)

```sql
-- create_agency — one agency per approved publisher (Q3=A / R-138). Seeds owner as admin/active member.
CREATE OR REPLACE FUNCTION public.create_agency(
  p_name TEXT, p_description TEXT DEFAULT NULL, p_phone TEXT DEFAULT NULL,
  p_whatsapp TEXT DEFAULT NULL, p_address TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_uid UUID := auth.uid(); v_id UUID;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth_required' USING ERRCODE = '28000'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles p
                 WHERE p.user_id = v_uid AND p.publisher_status='approved' AND p.account_status='approved') THEN
    RAISE EXCEPTION 'not_a_publisher' USING ERRCODE = '42501';
  END IF;
  IF EXISTS (SELECT 1 FROM public.agencies a WHERE a.owner_user_id = v_uid) THEN
    RAISE EXCEPTION 'already_owns_agency' USING ERRCODE = '23505';
  END IF;
  IF p_name IS NULL OR length(trim(p_name)) = 0 THEN
    RAISE EXCEPTION 'invalid_name' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.agencies (owner_user_id, name, description, phone, whatsapp, address, status)
  VALUES (v_uid, trim(p_name), p_description, p_phone, p_whatsapp, p_address, 'pending')
  RETURNING id INTO v_id;
  INSERT INTO public.agency_members (agency_id, user_id, member_role, status, joined_at)
  VALUES (v_id, v_uid, 'admin', 'active', now());
  RETURN v_id;
END;
$$;

-- invite_agency_member — agency-admin invites an EXISTING account by phone (Q2=B / R-139).
CREATE OR REPLACE FUNCTION public.invite_agency_member(
  p_agency_id UUID, p_phone TEXT, p_role TEXT DEFAULT 'agent'
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_target UUID;
BEGIN
  IF NOT public.is_agency_admin(p_agency_id) THEN RAISE EXCEPTION 'permission_denied' USING ERRCODE='42501'; END IF;
  IF p_role NOT IN ('admin','agent') THEN RAISE EXCEPTION 'invalid_role' USING ERRCODE='22023'; END IF;
  SELECT user_id INTO v_target FROM public.profiles WHERE phone = p_phone;     -- caller passes E.164-normalized phone
  IF v_target IS NULL THEN RAISE EXCEPTION 'user_not_found' USING ERRCODE='23503'; END IF;
  INSERT INTO public.agency_members (agency_id, user_id, member_role, status, invited_by)
  VALUES (p_agency_id, v_target, p_role, 'pending', auth.uid())
  ON CONFLICT (agency_id, user_id) DO NOTHING;                                 -- idempotent (already member/invited)
  RETURN v_target;
END;
$$;

-- respond_agency_invitation — INVITEE only (bound to auth.uid()).
CREATE OR REPLACE FUNCTION public.respond_agency_invitation(p_agency_id UUID, p_accept BOOLEAN)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  UPDATE public.agency_members
     SET status = CASE WHEN p_accept THEN 'active' ELSE 'removed' END,
         joined_at = CASE WHEN p_accept THEN now() ELSE joined_at END
   WHERE agency_id = p_agency_id AND user_id = auth.uid() AND status = 'pending';
  IF NOT FOUND THEN RAISE EXCEPTION 'no_pending_invitation' USING ERRCODE='P0002'; END IF;
END;
$$;

-- set_agency_member_role / remove_agency_member — agency-admin only; the owner is protected.
CREATE OR REPLACE FUNCTION public.set_agency_member_role(p_agency_id UUID, p_user_id UUID, p_role TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_agency_admin(p_agency_id) THEN RAISE EXCEPTION 'permission_denied' USING ERRCODE='42501'; END IF;
  IF p_role NOT IN ('admin','agent') THEN RAISE EXCEPTION 'invalid_role' USING ERRCODE='22023'; END IF;
  IF EXISTS (SELECT 1 FROM public.agencies a WHERE a.id=p_agency_id AND a.owner_user_id=p_user_id) THEN
    RAISE EXCEPTION 'cannot_modify_owner' USING ERRCODE='42501';
  END IF;
  UPDATE public.agency_members SET member_role=p_role
   WHERE agency_id=p_agency_id AND user_id=p_user_id AND status='active';
END;
$$;

CREATE OR REPLACE FUNCTION public.remove_agency_member(p_agency_id UUID, p_user_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_agency_admin(p_agency_id) THEN RAISE EXCEPTION 'permission_denied' USING ERRCODE='42501'; END IF;
  IF EXISTS (SELECT 1 FROM public.agencies a WHERE a.id=p_agency_id AND a.owner_user_id=p_user_id) THEN
    RAISE EXCEPTION 'cannot_remove_owner' USING ERRCODE='42501';
  END IF;
  UPDATE public.agency_members SET status='removed' WHERE agency_id=p_agency_id AND user_id=p_user_id;
END;
$$;

-- submit_agency_verification — agency-admin; inserts request + stores Vault PII (R-141).
CREATE OR REPLACE FUNCTION public.submit_agency_verification(
  p_agency_id UUID, p_id_document_number TEXT, p_registration_number TEXT, p_evidence_urls JSONB DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id UUID;
BEGIN
  IF NOT public.is_agency_admin(p_agency_id) THEN RAISE EXCEPTION 'permission_denied' USING ERRCODE='42501'; END IF;
  INSERT INTO public.agency_verification_requests (agency_id, evidence_urls, submitted_by, decision)
  VALUES (p_agency_id, p_evidence_urls, auth.uid(), 'pending')          -- ux_agency_open_verification ⇒ 23505 if one is open
  RETURNING id INTO v_id;
  IF p_id_document_number IS NOT NULL THEN
    PERFORM public.app_vault_set_agency_secret(p_agency_id, 'id_document_number', p_id_document_number);
  END IF;
  IF p_registration_number IS NOT NULL THEN
    PERFORM public.app_vault_set_agency_secret(p_agency_id, 'commercial_registration_number', p_registration_number);
  END IF;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_agency(TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_agency(TEXT,TEXT,TEXT,TEXT,TEXT) TO authenticated;
REVOKE ALL ON FUNCTION public.invite_agency_member(UUID,TEXT,TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.invite_agency_member(UUID,TEXT,TEXT) TO authenticated;
REVOKE ALL ON FUNCTION public.respond_agency_invitation(UUID,BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.respond_agency_invitation(UUID,BOOLEAN) TO authenticated;
REVOKE ALL ON FUNCTION public.set_agency_member_role(UUID,UUID,TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_agency_member_role(UUID,UUID,TEXT) TO authenticated;
REVOKE ALL ON FUNCTION public.remove_agency_member(UUID,UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.remove_agency_member(UUID,UUID) TO authenticated;
REVOKE ALL ON FUNCTION public.submit_agency_verification(UUID,TEXT,TEXT,JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_agency_verification(UUID,TEXT,TEXT,JSONB) TO authenticated;
```

### 1.9 `submit_listing` agency-membership amendment (migration `20260531120009`) — R-143 integration check

```sql
-- CREATE OR REPLACE re-basing the LATEST submit_listing body
-- (20260522120004_amend_submit_listing_rpc_for_media_minimum.sql). Preserve EVERY
-- existing validation (profile approval, >=1 price, >=1 image, residential rules);
-- ADD only the agency-membership branch below, immediately before the
-- "UPDATE public.listings SET status='pending_review'" line.
--
--   IF v_listing.agency_id IS NOT NULL THEN
--     IF NOT EXISTS (
--       SELECT 1 FROM public.agency_members m
--       JOIN public.agencies a ON a.id = m.agency_id
--       WHERE m.agency_id = v_listing.agency_id
--         AND m.user_id   = auth.uid()
--         AND m.status    = 'active'
--         AND a.status IN ('pending','approved')         -- not rejected/suspended (R-149)
--     ) THEN
--       RAISE EXCEPTION 'not_an_agency_member' USING ERRCODE = '42501';
--     END IF;
--   END IF;
--
-- Grants unchanged (authenticated). The existing per-user publish RLS
-- (listings_insert_owner / listings_update_owner, 20260519120002) is UNTOUCHED.
```

### 1.10 `moderate_agency_internal` RPC (migration `20260531120010`)

```sql
-- Service-role-only. Mirrors the Phase 12 approve_reject_atomic_wrappers (20260523120005):
-- sets app.current_user_id so trg_agencies_audit_status + trg_agency_verification_audit
-- attribute the actor; transitions the agency + the open verification request in ONE transaction.
CREATE OR REPLACE FUNCTION public.moderate_agency_internal(
  p_agency_id UUID, p_actor_user_id UUID, p_action TEXT, p_reason_json TEXT DEFAULT NULL
) RETURNS TABLE(agency_id UUID, status TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_cur agency_status; v_name TEXT; v_new agency_status;
BEGIN
  PERFORM set_config('app.current_user_id', p_actor_user_id::text, true);

  IF p_action NOT IN ('approve','reject','suspend','reinstate') THEN
    RAISE EXCEPTION 'invalid_action' USING ERRCODE = '22023';
  END IF;

  SELECT a.status, a.name INTO v_cur, v_name FROM public.agencies a WHERE a.id = p_agency_id;
  IF v_cur IS NULL THEN RAISE EXCEPTION 'agency_not_found' USING ERRCODE = '23503'; END IF;

  -- approve/reject act on a pending verification request (the queue only surfaces those).
  IF p_action IN ('approve','reject')
     AND NOT EXISTS (SELECT 1 FROM public.agency_verification_requests
                     WHERE agency_id = p_agency_id AND decision = 'pending') THEN
    RAISE EXCEPTION 'no_pending_verification' USING ERRCODE = 'P0002';
  END IF;

  -- A reject MUST carry a reason (the agency_verification_reason_when_rejected CHECK requires it).
  IF p_action = 'reject'
     AND COALESCE(NULLIF(p_reason_json::jsonb->>'detail',''), p_reason_json::jsonb->>'preset') IS NULL THEN
    RAISE EXCEPTION 'rejection_reason_required' USING ERRCODE = '22023';
  END IF;

  IF p_action = 'approve' THEN
    IF v_cur <> 'pending' THEN RAISE EXCEPTION 'invalid_transition' USING ERRCODE='23514'; END IF;
    IF EXISTS (SELECT 1 FROM public.agencies a2
               WHERE lower(a2.name)=lower(v_name) AND a2.status='approved' AND a2.id <> p_agency_id) THEN
      RAISE EXCEPTION 'name_taken' USING ERRCODE='23505';                     -- R-145 / FR-008
    END IF;
    -- Concurrent backstop: if two approvals of the same name race past this check,
    -- ux_agencies_name_approved raises 23505 on the second commit; the Edge Function maps
    -- either 23505 to name_taken/409 (one approval wins, the other gets name_taken).
    v_new := 'approved';
  ELSIF p_action = 'reject' THEN
    IF v_cur <> 'pending' THEN RAISE EXCEPTION 'invalid_transition' USING ERRCODE='23514'; END IF;
    v_new := 'rejected';
  ELSIF p_action = 'suspend' THEN
    IF v_cur <> 'approved' THEN RAISE EXCEPTION 'invalid_transition' USING ERRCODE='23514'; END IF;
    v_new := 'suspended';
  ELSE  -- reinstate
    IF v_cur <> 'suspended' THEN RAISE EXCEPTION 'invalid_transition' USING ERRCODE='23514'; END IF;
    v_new := 'approved';
  END IF;

  UPDATE public.agencies SET status = v_new WHERE id = p_agency_id;          -- fires trg_agencies_audit_status

  IF p_action IN ('approve','reject') THEN
    UPDATE public.agency_verification_requests
       SET decision        = (CASE WHEN p_action='approve' THEN 'approved' ELSE 'rejected' END),
           decision_reason  = CASE WHEN p_action='reject'
                                   THEN COALESCE(NULLIF(p_reason_json::jsonb->>'detail',''),
                                                 p_reason_json::jsonb->>'preset') END,
           reviewed_by      = p_actor_user_id,
           reviewed_at      = now()
     WHERE agency_id = p_agency_id AND decision = 'pending';                 -- fires trg_agency_verification_audit
  END IF;

  RETURN QUERY SELECT p_agency_id, v_new::text;
END;
$$;

REVOKE ALL ON FUNCTION public.moderate_agency_internal(UUID,UUID,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.moderate_agency_internal(UUID,UUID,TEXT,TEXT) FROM anon;
REVOKE ALL ON FUNCTION public.moderate_agency_internal(UUID,UUID,TEXT,TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.moderate_agency_internal(UUID,UUID,TEXT,TEXT) TO service_role;
```

### 1.11 Audit triggers (migration `20260531120011`)

```sql
-- Reuse the Phase 4 log_audit() trigger fn (20260506120004). Actor from app.current_user_id
-- (set by moderate_agency_internal) or auth.uid() (member changes).
CREATE TRIGGER trg_agencies_audit_status
  AFTER UPDATE OF status ON public.agencies
  FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION log_audit('agency.status_changed', 'status', 'id');

-- Split INSERT/DELETE from UPDATE OF (combining an `OF column-list` with INSERT/DELETE in one
-- CREATE TRIGGER is ambiguous — two triggers is unambiguous). pk_col = 'user_id' (the affected
-- member); the column list includes agency_id + user_id so the composite identity survives in
-- before/after (a bare 'agency_id' pk_col would lose which member changed).
CREATE TRIGGER trg_agency_members_audit_ins_del
  AFTER INSERT OR DELETE ON public.agency_members
  FOR EACH ROW
  EXECUTE FUNCTION log_audit('agency_member.changed', 'agency_id,user_id,member_role,status', 'user_id');
CREATE TRIGGER trg_agency_members_audit_upd
  AFTER UPDATE OF member_role, status ON public.agency_members
  FOR EACH ROW
  WHEN (OLD.member_role IS DISTINCT FROM NEW.member_role OR OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION log_audit('agency_member.changed', 'agency_id,user_id,member_role,status', 'user_id');

CREATE TRIGGER trg_agency_verification_audit
  AFTER UPDATE OF decision ON public.agency_verification_requests
  FOR EACH ROW WHEN (OLD.decision IS DISTINCT FROM NEW.decision)
  EXECUTE FUNCTION log_audit('agency_verification.decided', 'decision,decision_reason,reviewed_by', 'id');
```

### 1.12 Advisor hardening (migration `20260531120012`)

Safety-net `ALTER FUNCTION … SET search_path` for all Phase 19 functions (the seven write RPCs, the two Vault helpers, the two membership predicates, `moderate_agency_internal`, and the amended `submit_listing`), re-assert the grants (write RPCs + Vault helpers + predicates → `authenticated`; `moderate_agency_internal` → `service_role`), re-assert `REVOKE INSERT, UPDATE, DELETE ON public.agencies, public.agency_members, public.agency_verification_requests FROM authenticated, anon`, and `GRANT SELECT ON public.v_agencies TO anon, authenticated` — matching the Phase 18 advisor-hardening files (`20260530120008` / `…011`).

### 1.13 Storage buckets + policies (migration `20260531120013`)

```sql
-- agency-assets (public logos/cover) + agency-documents (private verification files).
-- Per the plan's storage-placement note, this sibling migration depends on B's
-- public.agencies + public.agency_members for the ownership predicates.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('agency-assets',    'agency-assets',    true,  5242880,  ARRAY['image/jpeg']),
  ('agency-documents', 'agency-documents', false, 10485760, ARRAY['image/jpeg','application/pdf'])
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public, file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Public read of approved-agency logos (path shape: {agency_id}/filename).
DROP POLICY IF EXISTS "agency_assets_public_select" ON storage.objects;
CREATE POLICY "agency_assets_public_select" ON storage.objects FOR SELECT TO anon, authenticated
USING (
  bucket_id = 'agency-assets'
  AND EXISTS (SELECT 1 FROM public.agencies a
              WHERE a.id = split_part(name, '/', 1)::uuid AND a.status = 'approved')
);

-- Agency-admin write of own-agency assets (mirrors 20260522120003 path-shape + EXISTS gate).
DROP POLICY IF EXISTS "agency_assets_admin_write" ON storage.objects;
CREATE POLICY "agency_assets_admin_write" ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'agency-assets'
  AND name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/.+$'
  AND public.is_agency_admin(split_part(name, '/', 1)::uuid)
);

-- Private verification documents: agency-admin (own) OR agencies.view (platform admin) read; admin write.
DROP POLICY IF EXISTS "agency_documents_owner_admin_select" ON storage.objects;
CREATE POLICY "agency_documents_owner_admin_select" ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'agency-documents'
  AND (public.is_agency_admin(split_part(name, '/', 1)::uuid)
       OR public.current_user_has_permission('agencies.view'))
);
DROP POLICY IF EXISTS "agency_documents_admin_write" ON storage.objects;
CREATE POLICY "agency_documents_admin_write" ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'agency-documents'
  AND name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/.+$'
  AND public.is_agency_admin(split_part(name, '/', 1)::uuid)
);
```

### 1.14 RLS reader/writer matrix (load-bearing — Principle III)

| Actor | `agencies` SELECT | `agency_members` SELECT | `agency_verification_requests` SELECT | any table INSERT/UPDATE/DELETE | Vault id/registration |
|-------|-------------------|--------------------------|----------------------------------------|--------------------------------|------------------------|
| Anonymous | ✅ only `status='approved'` | ❌ | ❌ | ❌ | ❌ |
| Authenticated non-member | ✅ approved only | ✅ own invitation row only | ❌ | ❌ (RPC only) | ❌ |
| Owner / active member | ✅ own agency (any status) | ✅ own agency roster | agency-admins ✅ / agents ❌ | ❌ (RPC only) | ❌ (admin-decrypt only) |
| `agencies.view`/`approve`/`suspend` holder | ✅ ALL | ✅ ALL | ✅ ALL | ❌ (moderate_agency → service-role RPC only) | ✅ via `app_vault_secret_for_agency` |
| `service_role` (Edge Fn) | n/a (bypasses RLS) | n/a | n/a | via `moderate_agency_internal` only | n/a |

Reads go through the SECURITY DEFINER `v_agencies` view (which reproduces the rows-1–4 matrix via its WHERE); the base-table policies above govern the `v_listings_public` badge join + defense-in-depth. No client write on any of the three tables. This is IMPLEMENTATION_PLAN §6.4 for `agencies` + `agency_members`, extended to `agency_verification_requests` per ADR-0001.

---

## 2. Dart domain entities (Constitution IX — zero Supabase imports)

### 2.1 `lib/features/agency/domain/entities/agency_status.dart`

```dart
enum AgencyStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected'),
  suspended('suspended');

  const AgencyStatus(this.wireValue);
  final String wireValue;

  bool get isPublic => this == AgencyStatus.approved;
  bool get canPublishUnder => this == AgencyStatus.pending || this == AgencyStatus.approved;

  static AgencyStatus fromWire(String v) =>
      AgencyStatus.values.firstWhere((e) => e.wireValue == v);
}
```

### 2.2 `lib/features/agency/domain/entities/agency_member_role.dart` + `agency_member_status.dart`

```dart
enum AgencyMemberRole {
  admin('admin'),
  agent('agent');

  const AgencyMemberRole(this.wireValue);
  final String wireValue;
  bool get isAdmin => this == AgencyMemberRole.admin;
  static AgencyMemberRole fromWire(String v) =>
      AgencyMemberRole.values.firstWhere((e) => e.wireValue == v);
}

enum AgencyMemberStatus {
  pending('pending'),
  active('active'),
  removed('removed');

  const AgencyMemberStatus(this.wireValue);
  final String wireValue;
  bool get isActive => this == AgencyMemberStatus.active;
  static AgencyMemberStatus fromWire(String v) =>
      AgencyMemberStatus.values.firstWhere((e) => e.wireValue == v);
}
```

### 2.3 `lib/features/agency/domain/entities/agency.dart`

```dart
class Agency extends Equatable {
  const Agency({
    required this.id,
    required this.ownerUserId,
    required this.name,
    required this.status,
    required this.createdAt,
    this.description,
    this.phone,
    this.whatsapp,
    this.address,
    this.logoPath,
    this.coverPath,
  });

  final String id;
  final String ownerUserId;
  final String name;
  final AgencyStatus status;
  final DateTime createdAt;
  final String? description;
  final String? phone;
  final String? whatsapp;
  final String? address;
  final String? logoPath;
  final String? coverPath;

  @override
  List<Object?> get props => [id, ownerUserId, name, status];
}
```

### 2.4 `lib/features/agency/domain/entities/agency_member.dart`

```dart
class AgencyMember extends Equatable {
  const AgencyMember({
    required this.agencyId,
    required this.userId,
    required this.role,
    required this.status,
    this.invitedBy,
    this.joinedAt,
    // Optional joined display fields (full_name / phone) when the roster view provides them:
    this.displayName,
    this.phone,
  });

  final String agencyId;
  final String userId;
  final AgencyMemberRole role;
  final AgencyMemberStatus status;
  final String? invitedBy;
  final DateTime? joinedAt;
  final String? displayName;
  final String? phone;

  @override
  List<Object?> get props => [agencyId, userId, role, status];
}
```

### 2.5 `lib/features/agency/domain/entities/agency_verification_request.dart`

```dart
enum VerificationDecision {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const VerificationDecision(this.wireValue);
  final String wireValue;
  static VerificationDecision fromWire(String v) =>
      VerificationDecision.values.firstWhere((e) => e.wireValue == v);
}

class AgencyVerificationRequest extends Equatable {
  const AgencyVerificationRequest({
    required this.id,
    required this.agencyId,
    required this.decision,
    required this.submittedAt,
    this.decisionReason,
    this.evidenceUrls,
    this.reviewedAt,
  });

  final String id;
  final String agencyId;
  final VerificationDecision decision;
  final DateTime submittedAt;
  final String? decisionReason;
  final List<String>? evidenceUrls;
  final DateTime? reviewedAt;

  @override
  List<Object?> get props => [id, agencyId, decision, decisionReason];
}
```

### 2.6 `lib/features/admin/agencies/domain/entities/agency_verification_item.dart`

`AgencyVerificationItem` extends the `Agency` + `AgencyVerificationRequest` projection with the admin-only decrypted `idDocumentNumber` / `commercialRegistrationNumber` (populated by `app_vault_secret_for_agency`, visible only on the detail screen to `agencies.view` holders) and `ownerDisplayName`. `Equatable`, zero Supabase imports.

```dart
class AgencyVerificationItem extends Equatable {
  const AgencyVerificationItem({
    required this.agency,                 // the Agency profile (any status)
    required this.request,                // the AgencyVerificationRequest (decision/evidence)
    this.ownerDisplayName,
    this.idDocumentNumber,                // admin-only — decrypted via app_vault_secret_for_agency
    this.commercialRegistrationNumber,    // admin-only — decrypted via app_vault_secret_for_agency
  });

  final Agency agency;
  final AgencyVerificationRequest request;
  final String? ownerDisplayName;
  final String? idDocumentNumber;
  final String? commercialRegistrationNumber;

  @override
  List<Object?> get props => [agency, request];
}
```


### 2.7 Repository interfaces

- `lib/features/agency/domain/repositories/agency_repository.dart` — `createAgency`, `loadMyAgency`, `updateProfile`, `submitVerification`, `loadMembers`, `inviteMember`, `respondInvitation`, `setMemberRole`, `removeMember`, `loadMyInvitations`, `loadAgencyListings`, `loadAnalytics` (all return `Result<T>`).
- `lib/features/admin/agencies/domain/repositories/agencies_admin_repository.dart` — `loadQueue`, `loadDetail`, `approve`, `reject`, `suspend`, `reinstate` (all return `Result<T>`).

---

## 3. Per-FR verification map

| FR | Where satisfied |
|----|-----------------|
| FR-001 Create agency (approved publisher, one each) | §1.8 `create_agency` + Sub-Phase F/H |
| FR-002 Agency profile fields + edit (own) | §1.1 + §1.8 + H (`agency_home_page`/`agency_profile_page`) |
| FR-003 Public agency profile (approved only) | §1.6 `v_agencies` + H (`agency_profile_page`, `/agency/:id`) |
| FR-004 Submit verification (one open/agency) | §1.3 `ux_agency_open_verification` + §1.8 `submit_agency_verification` |
| FR-005 Vault ID + registration, admin-decrypt-only | §1.7 vault helpers |
| FR-006 Private verification document bucket | §1.13 `agency-documents` |
| FR-007 Admin verification queue gated on `agencies.view`/`approve` | §1.5 policy + A (`requireAgenciesManageRedirect`) + I |
| FR-008 Approve/reject via Edge Fn + service-role RPC; name-collision on approve | §1.10 + contracts/`moderate_agency` + §1.10 `name_taken` |
| FR-009 Reject reason surfaced to owner | §1.10 (decision_reason) + H (`agency_verification_page`) |
| FR-010 Suspend/reinstate via same path; destructive confirm | §1.10 + I (`agency_decision_dialog`) |
| FR-011 Suspension hides profile/badge, no mass listing change | §1.6 (approved-only views) + R-149 |
| FR-012 All status/member changes audit-logged | §1.11 audit triggers |
| FR-013 Invite by phone (existing account; user_not_found) | §1.8 `invite_agency_member` |
| FR-014 Pending invite + in-app accept/decline (invitee-only) | §1.8 `respond_agency_invitation` + H (`agency_invitations_cubit`) |
| FR-015 member_role + lifecycle; owner un-removable | §1.2 + §1.8 (`cannot_modify_owner`/`cannot_remove_owner`) |
| FR-016 Member-mgmt authorized by per-agency `member_role='admin'` | §1.2 `is_agency_admin` + §1.8 RPC gates |
| FR-017 All member writes via privileged RPCs | §1.5 REVOKE + §1.8 RPCs |
| FR-018 `listings.agency_id` FK ON DELETE SET NULL; no existing breakage | §1.4 |
| FR-019 "Publish under agency" control for active members | H4 (`publish_under_agency_field`, `step_basics`) |
| FR-020 Publish path validates membership; reuses per-user gate | §1.9 `submit_listing` amendment (R-143) |
| FR-021 agency_id settable in draft/rejected states | H4 (`listing_form_bloc` copyWith) + existing listings RLS |
| FR-022 Verified badge (approved only) on card + details | §1.6 `v_listings_public` amendment + H2/H3 (`agency_badge`) |
| FR-023 Surgical badge add (no reflow; CTAs untouched) | H2 (`property_card` optional param) + H3 |
| FR-024 `agency_status` enum (no listings-enum change) | §1.1 |
| FR-025 `public.agencies` columns + UNIQUE owner + name-among-approved | §1.1 + §1.5 `ux_agencies_name_approved` |
| FR-026 `public.agency_members` columns + PK | §1.2 |
| FR-027 `public.agency_verification_requests` columns + Vault note | §1.3 + §1.7 |
| FR-028 Indices (queue/roster/directory/dedup) | §1.1/§1.2/§1.3 |
| FR-029 `agencies` RLS (public-approved + owner/member + admin) via definer view | §1.5 + §1.6 |
| FR-030 `agency_members` RLS (member + admin; invitee own row) | §1.5 |
| FR-031 `agency_verification_requests` RLS (agency-admin + admin); Vault never in views | §1.5 + §1.6 + §1.7 |
| FR-032 Anon reads only approved public profile; no anon write | §1.5 (`agencies_select_anon`; REVOKE) |
| FR-033 Storage buckets (public logos + private documents) | §1.13 |
| FR-034 Bounded own-agency analytics | F (`loadAnalytics` count queries) + H (`agency_analytics_page`) |
| FR-035 All strings localized | J |
| FR-036 4-combination theme×locale render | H + I (token usage) |
| FR-037 Zero new deps | R-135 |
| FR-038 No hardcoded role branch (admin = `agencies.*`; self-service = membership row) | A + I (`PermissionKeys`) + §1.2 `is_agency_admin` |
| FR-039 Checks at both ends | §1.10 (service-role RPC) + contracts/`moderate_agency` (perm gate) + §1.5 REVOKE + §1.8 SECURITY DEFINER |
| FR-040 No listings-enum change; no `lead_events` change; FK no breakage | §1.1/§1.4 |
| FR-041 Reuse `audit_logs`/`log_audit` + Phase 12 Edge pattern + ADR-0001 Vault + account-approval template | §1.11 + §1.10 + §1.7 + §1.3 |

## 4. Per-SC verification map

| SC | Verification (see quickstart.md) |
|----|----------------------------------|
| SC-001 | Create agency < 60 s; one `agencies` row + owner `active`/`admin` member row within 2 s; non-publisher + 2nd-agency rejected |
| SC-002 | Submit verification → one request row + ID number Vault-only (not in any plaintext column / view) |
| SC-003 | `agencies.view` sees queue tile + queue (Vault-decrypted ID); non-admin sees neither at the wire |
| SC-004 | Approve → agency `approved` + request `approved`; reject → `rejected` + reason to owner; 1 `audit_logs` each |
| SC-005 | Suspend → profile/badge gone within one refresh + new publishing blocked; listings keep status; reinstate restores |
| SC-006 | Invite existing → `pending`; unregistered phone → `user_not_found`, no row; invitee accept → `active` |
| SC-007 | Active member publishes with `agency_id`; non-member (or crafted) rejected by `submit_listing`; no-membership → no control, `agency_id=NULL` |
| SC-008 | Approved-agency listing shows badge → profile; pending/suspended/NULL → no badge, no reflow |
| SC-009 | Wire-level read matrix: anon approved-only; owner/member own-any-status; non-admin no roster/verification |
| SC-010 | ID/registration numbers decryptable only by `agencies.view` via `app_vault_secret_for_agency`; no plaintext to owner/member/anon |
| SC-011 | Unauthorized moderate rejected at Edge Fn AND service-role RPC; no status change/audit |
| SC-012 | Forged `owner_user_id` + direct non-RPC `agency_members` write both rejected |
| SC-013 | 4-combination theme×locale render on 480 dp + 412 dp |
| SC-014 | Zero new deps; zero hardcoded role branch; no listings-enum / `lead_events` change |
| SC-015 | Queue + directory + roster + analytics issue bounded (LIMIT/cursor) queries |
