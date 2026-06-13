-- Phase 030 (spec/030-storage-search-crm-nav) — W3: auto-create CRM leads.
--
-- Until now a publisher had to TAP "Add to CRM" on an inquiry / chat / viewing
-- to materialize a lead (the crm_upsert_lead_from_* RPCs in
-- 20260613120002). This migration makes lead creation AUTOMATIC: an AFTER
-- INSERT trigger on each source table (inquiries / conversations / viewings)
-- mirrors that upsert logic so a lead exists the moment a contact first
-- reaches the publisher. The client "Add to CRM" button is relabelled
-- "View in CRM" — the RPC still runs (idempotent) and returns the now-existing
-- lead for navigation.
--
-- Dedup rule MIRRORS the RPCs and the table constraints
-- (20260613120001): a lead is unique per (publisher, source inquiry)
-- [crm_leads_uniq_inq] and per (publisher, real contact)
-- [partial idx crm_leads_uniq_user]. We deliberately do NOT use ON CONFLICT —
-- the per-contact unique is a PARTIAL index (WHERE contact_user_id IS NOT NULL
-- AND contact_user_id <> publisher_user_id), which makes arbiter inference
-- fragile. Instead each trigger and the backfill guard with IF NOT EXISTS /
-- WHERE NOT EXISTS over the same predicates.
--
-- All functions: SECURITY DEFINER, SET search_path = public, every table
-- aliased + every column qualified. They are trigger functions (run as the
-- table owner via the trigger), so they need no GRANT; we REVOKE EXECUTE FROM
-- PUBLIC, anon for hygiene.

-- ── Auto-create from an inquiry ────────────────────────────────────────────────
-- Resolve the listing's publisher; insert a lead for the inquiry's sender unless
-- one already exists for this source inquiry OR (for signed-in senders) for this
-- same contact. display_name falls back to the inquiry sender_name.
CREATE OR REPLACE FUNCTION public.auto_create_lead_from_inquiry()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_publisher uuid;
BEGIN
  SELECT l.publisher_user_id
    INTO v_publisher
    FROM public.listings l
    WHERE l.id = NEW.listing_id;

  IF v_publisher IS NULL THEN
    RETURN NEW;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.crm_leads cl
    WHERE cl.publisher_user_id = v_publisher
      AND (
        cl.source_inquiry_id = NEW.id
        OR (NEW.sender_user_id IS NOT NULL AND cl.contact_user_id = NEW.sender_user_id)
      )
  ) THEN
    INSERT INTO public.crm_leads
      (publisher_user_id, contact_user_id, source_inquiry_id, listing_id, display_name)
    VALUES (
      v_publisher,
      NEW.sender_user_id,
      NEW.id,
      NEW.listing_id,
      coalesce(nullif(trim(NEW.sender_name), ''), 'Lead')
    );
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.auto_create_lead_from_inquiry() FROM PUBLIC, anon;

DROP TRIGGER IF EXISTS trg_auto_create_lead_from_inquiry ON public.inquiries;
CREATE TRIGGER trg_auto_create_lead_from_inquiry
  AFTER INSERT ON public.inquiries
  FOR EACH ROW EXECUTE FUNCTION public.auto_create_lead_from_inquiry();

-- ── Auto-create from a conversation ────────────────────────────────────────────
-- contact = buyer, publisher = NEW.publisher_user_id; title from the listing.
-- Dedup per (publisher, contact).
CREATE OR REPLACE FUNCTION public.auto_create_lead_from_conversation()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_title text;
BEGIN
  IF NEW.publisher_user_id IS NULL OR NEW.buyer_user_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT l.title
    INTO v_title
    FROM public.listings l
    WHERE l.id = NEW.listing_id;

  IF NOT EXISTS (
    SELECT 1
    FROM public.crm_leads cl
    WHERE cl.publisher_user_id = NEW.publisher_user_id
      AND cl.contact_user_id = NEW.buyer_user_id
  ) THEN
    INSERT INTO public.crm_leads
      (publisher_user_id, contact_user_id, listing_id, display_name)
    VALUES (
      NEW.publisher_user_id,
      NEW.buyer_user_id,
      NEW.listing_id,
      coalesce(nullif(trim(coalesce(v_title, '')), ''), 'Lead')
    );
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.auto_create_lead_from_conversation() FROM PUBLIC, anon;

DROP TRIGGER IF EXISTS trg_auto_create_lead_from_conversation ON public.conversations;
CREATE TRIGGER trg_auto_create_lead_from_conversation
  AFTER INSERT ON public.conversations
  FOR EACH ROW EXECUTE FUNCTION public.auto_create_lead_from_conversation();

-- ── Auto-create from a viewing ─────────────────────────────────────────────────
-- contact = requester, publisher = NEW.publisher_user_id; title from the
-- listing. Dedup per (publisher, contact).
CREATE OR REPLACE FUNCTION public.auto_create_lead_from_viewing()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_title text;
BEGIN
  IF NEW.publisher_user_id IS NULL OR NEW.requester_user_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT l.title
    INTO v_title
    FROM public.listings l
    WHERE l.id = NEW.listing_id;

  IF NOT EXISTS (
    SELECT 1
    FROM public.crm_leads cl
    WHERE cl.publisher_user_id = NEW.publisher_user_id
      AND cl.contact_user_id = NEW.requester_user_id
  ) THEN
    INSERT INTO public.crm_leads
      (publisher_user_id, contact_user_id, listing_id, display_name)
    VALUES (
      NEW.publisher_user_id,
      NEW.requester_user_id,
      NEW.listing_id,
      coalesce(nullif(trim(coalesce(v_title, '')), ''), 'Lead')
    );
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.auto_create_lead_from_viewing() FROM PUBLIC, anon;

DROP TRIGGER IF EXISTS trg_auto_create_lead_from_viewing ON public.viewings;
CREATE TRIGGER trg_auto_create_lead_from_viewing
  AFTER INSERT ON public.viewings
  FOR EACH ROW EXECUTE FUNCTION public.auto_create_lead_from_viewing();

-- ── Backfill (idempotent) ──────────────────────────────────────────────────────
-- Materialize leads for source rows that predate these triggers. Each INSERT …
-- SELECT guards with WHERE NOT EXISTS over the same dedup predicate so re-running
-- this migration inserts nothing new. Tables aliased, columns qualified.

-- Inquiries (signed-in senders): one lead per (publisher, contact). The partial
-- index crm_leads_uniq_user dedups real contacts, so DISTINCT ON keeps a single
-- inquiry (the most recent) per contact to avoid colliding within this batch.
INSERT INTO public.crm_leads
  (publisher_user_id, contact_user_id, source_inquiry_id, listing_id, display_name)
SELECT DISTINCT ON (l.publisher_user_id, i.sender_user_id)
  l.publisher_user_id,
  i.sender_user_id,
  i.id,
  i.listing_id,
  coalesce(nullif(trim(i.sender_name), ''), 'Lead')
FROM public.inquiries i
JOIN public.listings l ON l.id = i.listing_id
WHERE l.publisher_user_id IS NOT NULL
  AND i.sender_user_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM public.crm_leads cl
    WHERE cl.publisher_user_id = l.publisher_user_id
      AND (
        cl.source_inquiry_id = i.id
        OR cl.contact_user_id = i.sender_user_id
      )
  )
ORDER BY l.publisher_user_id, i.sender_user_id, i.created_at DESC;

-- Inquiries (anonymous senders): no contact, so dedup is per source inquiry only
-- (crm_leads_uniq_inq). Each anonymous inquiry materializes its own lead.
INSERT INTO public.crm_leads
  (publisher_user_id, contact_user_id, source_inquiry_id, listing_id, display_name)
SELECT
  l.publisher_user_id,
  i.sender_user_id,
  i.id,
  i.listing_id,
  coalesce(nullif(trim(i.sender_name), ''), 'Lead')
FROM public.inquiries i
JOIN public.listings l ON l.id = i.listing_id
WHERE l.publisher_user_id IS NOT NULL
  AND i.sender_user_id IS NULL
  AND NOT EXISTS (
    SELECT 1
    FROM public.crm_leads cl
    WHERE cl.publisher_user_id = l.publisher_user_id
      AND cl.source_inquiry_id = i.id
  );

-- Conversations: anchor to the buyer contact; skip if a lead already exists for
-- the same (publisher, contact). DISTINCT ON collapses a contact that has
-- multiple conversations with the same publisher to one row, so the batch does
-- not trip the crm_leads_uniq_user partial index on its own uncommitted rows.
INSERT INTO public.crm_leads
  (publisher_user_id, contact_user_id, listing_id, display_name)
SELECT DISTINCT ON (c.publisher_user_id, c.buyer_user_id)
  c.publisher_user_id,
  c.buyer_user_id,
  c.listing_id,
  coalesce(nullif(trim(coalesce(l.title, '')), ''), 'Lead')
FROM public.conversations c
LEFT JOIN public.listings l ON l.id = c.listing_id
WHERE c.publisher_user_id IS NOT NULL
  AND c.buyer_user_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM public.crm_leads cl
    WHERE cl.publisher_user_id = c.publisher_user_id
      AND cl.contact_user_id = c.buyer_user_id
  )
ORDER BY c.publisher_user_id, c.buyer_user_id, c.last_message_at DESC;

-- Viewings: anchor to the requester contact; skip if a lead already exists for
-- the same (publisher, contact). DISTINCT ON collapses a contact with multiple
-- viewings under the same publisher to one row (same partial-index guard as
-- above).
INSERT INTO public.crm_leads
  (publisher_user_id, contact_user_id, listing_id, display_name)
SELECT DISTINCT ON (v.publisher_user_id, v.requester_user_id)
  v.publisher_user_id,
  v.requester_user_id,
  v.listing_id,
  coalesce(nullif(trim(coalesce(l.title, '')), ''), 'Lead')
FROM public.viewings v
LEFT JOIN public.listings l ON l.id = v.listing_id
WHERE v.publisher_user_id IS NOT NULL
  AND v.requester_user_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM public.crm_leads cl
    WHERE cl.publisher_user_id = v.publisher_user_id
      AND cl.contact_user_id = v.requester_user_id
  )
ORDER BY v.publisher_user_id, v.requester_user_id, v.scheduled_at DESC;
