-- Phase 029 (spec/029-crm-reels-growth) — F1 (W1): CRM for publishers.
--
-- A personal lead pipeline layered over the existing inquiries / chats /
-- viewings surfaces. Three tables, all RLS-scoped to the owning publisher:
--   - public.crm_leads      — one lead (a contact in the publisher's pipeline)
--   - public.crm_notes      — private notes on a lead
--   - public.crm_reminders  — follow-up reminders (device-local notifications)
--
-- Conventions mirror the chat/viewings growth migrations (20260608140001 /
-- 20260608150001): publisher_user_id DB-defaulted to auth.uid(), the shared
-- public.set_updated_at() trigger (defined in 20260506120002_create_profiles),
-- direct PostgREST CRUD GRANTed to authenticated (RLS does the gating).
--
-- Identity (crm_leads_identity): a lead is anchored either to a contact user
-- (chat / viewing / signed-in inquirer) OR to a source inquiry. A "manual"
-- lead anchors to the publisher themselves (contact_user_id = auth.uid()) so it
-- still satisfies the identity check; the per-contact unique index excludes
-- that self-anchored case so a publisher may add many manual leads.

-- ── crm_leads ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.crm_leads (
  id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  publisher_user_id  uuid        NOT NULL DEFAULT auth.uid()
                                   REFERENCES auth.users(id) ON DELETE CASCADE,
  contact_user_id    uuid        NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  source_inquiry_id  uuid        NULL REFERENCES public.inquiries(id) ON DELETE SET NULL,
  listing_id         uuid        NULL REFERENCES public.listings(id) ON DELETE SET NULL,
  display_name       text        NOT NULL CHECK (length(trim(display_name)) BETWEEN 1 AND 100),
  stage              text        NOT NULL DEFAULT 'new'
                                   CHECK (stage IN ('new','contacted','viewing','negotiation','won','lost')),
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT crm_leads_identity
    CHECK (contact_user_id IS NOT NULL OR source_inquiry_id IS NOT NULL),
  -- Per-source unique: at most one lead per (publisher, source inquiry).
  CONSTRAINT crm_leads_uniq_inq UNIQUE (publisher_user_id, source_inquiry_id)
);

-- Per-contact unique for REAL contacts only. Manual leads anchor to the
-- publisher themselves (contact_user_id = publisher_user_id); excluding that
-- case here lets a publisher add many manual leads without colliding, while
-- still deduping genuine chat/viewing/inquiry contacts one lead per contact.
CREATE UNIQUE INDEX IF NOT EXISTS crm_leads_uniq_user
  ON public.crm_leads (publisher_user_id, contact_user_id)
  WHERE contact_user_id IS NOT NULL AND contact_user_id <> publisher_user_id;

-- Pipeline read: the owner's leads filtered by stage, most-recently-touched.
CREATE INDEX IF NOT EXISTS idx_crm_leads_owner_stage
  ON public.crm_leads (publisher_user_id, stage, updated_at DESC);
-- Plain FK indexes (advisor habit).
CREATE INDEX IF NOT EXISTS idx_crm_leads_contact
  ON public.crm_leads (contact_user_id) WHERE contact_user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_crm_leads_source_inquiry
  ON public.crm_leads (source_inquiry_id) WHERE source_inquiry_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_crm_leads_listing
  ON public.crm_leads (listing_id) WHERE listing_id IS NOT NULL;

-- ── crm_notes ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.crm_notes (
  id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id            uuid        NOT NULL REFERENCES public.crm_leads(id) ON DELETE CASCADE,
  publisher_user_id  uuid        NOT NULL DEFAULT auth.uid()
                                   REFERENCES auth.users(id) ON DELETE CASCADE,
  body               text        NOT NULL CHECK (char_length(body) BETWEEN 1 AND 2000),
  created_at         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_crm_notes_lead
  ON public.crm_notes (lead_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_crm_notes_owner
  ON public.crm_notes (publisher_user_id);

-- ── crm_reminders ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.crm_reminders (
  id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id            uuid        NOT NULL REFERENCES public.crm_leads(id) ON DELETE CASCADE,
  publisher_user_id  uuid        NOT NULL DEFAULT auth.uid()
                                   REFERENCES auth.users(id) ON DELETE CASCADE,
  title              text        NOT NULL CHECK (length(trim(title)) BETWEEN 1 AND 200),
  due_at             timestamptz NOT NULL,
  completed_at       timestamptz NULL,
  created_at         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_crm_reminders_lead
  ON public.crm_reminders (lead_id);
-- Partial index backing the "open future reminders" reschedule query + banner.
CREATE INDEX IF NOT EXISTS idx_crm_reminders_open
  ON public.crm_reminders (publisher_user_id, due_at)
  WHERE completed_at IS NULL;

-- ── set_updated_at trigger on crm_leads ───────────────────────────────────────
DROP TRIGGER IF EXISTS trg_crm_leads_set_updated_at ON public.crm_leads;
CREATE TRIGGER trg_crm_leads_set_updated_at
  BEFORE UPDATE ON public.crm_leads
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── RLS ────────────────────────────────────────────────────────────────────────
ALTER TABLE public.crm_leads     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_notes     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_reminders ENABLE ROW LEVEL SECURITY;

-- crm_leads — owner-only read/update/delete; insert must be by the owner and,
-- when anchored to a source inquiry, that inquiry must be on a listing the
-- caller publishes (prevents attaching to someone else's inquiry).
CREATE POLICY crm_leads_select_owner ON public.crm_leads
  FOR SELECT TO authenticated
  USING (publisher_user_id = auth.uid());
CREATE POLICY crm_leads_insert_owner ON public.crm_leads
  FOR INSERT TO authenticated
  WITH CHECK (
    publisher_user_id = auth.uid()
    AND (
      source_inquiry_id IS NULL
      OR EXISTS (
        SELECT 1
        FROM public.inquiries i
        JOIN public.listings l ON l.id = i.listing_id
        WHERE i.id = source_inquiry_id
          AND l.publisher_user_id = auth.uid()
      )
    )
  );
CREATE POLICY crm_leads_update_owner ON public.crm_leads
  FOR UPDATE TO authenticated
  USING (publisher_user_id = auth.uid());
CREATE POLICY crm_leads_delete_owner ON public.crm_leads
  FOR DELETE TO authenticated
  USING (publisher_user_id = auth.uid());

-- crm_notes — owner-only; insert also requires the parent lead is owned.
CREATE POLICY crm_notes_select_owner ON public.crm_notes
  FOR SELECT TO authenticated
  USING (publisher_user_id = auth.uid());
CREATE POLICY crm_notes_insert_owner ON public.crm_notes
  FOR INSERT TO authenticated
  WITH CHECK (
    publisher_user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.crm_leads cl
      WHERE cl.id = lead_id AND cl.publisher_user_id = auth.uid()
    )
  );
CREATE POLICY crm_notes_update_owner ON public.crm_notes
  FOR UPDATE TO authenticated
  USING (publisher_user_id = auth.uid());
CREATE POLICY crm_notes_delete_owner ON public.crm_notes
  FOR DELETE TO authenticated
  USING (publisher_user_id = auth.uid());

-- crm_reminders — owner-only; insert also requires the parent lead is owned.
CREATE POLICY crm_reminders_select_owner ON public.crm_reminders
  FOR SELECT TO authenticated
  USING (publisher_user_id = auth.uid());
CREATE POLICY crm_reminders_insert_owner ON public.crm_reminders
  FOR INSERT TO authenticated
  WITH CHECK (
    publisher_user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.crm_leads cl
      WHERE cl.id = lead_id AND cl.publisher_user_id = auth.uid()
    )
  );
CREATE POLICY crm_reminders_update_owner ON public.crm_reminders
  FOR UPDATE TO authenticated
  USING (publisher_user_id = auth.uid());
CREATE POLICY crm_reminders_delete_owner ON public.crm_reminders
  FOR DELETE TO authenticated
  USING (publisher_user_id = auth.uid());

-- Direct PostgREST CRUD (mirrors the chat/viewings grants; RLS gates rows).
GRANT SELECT, INSERT, UPDATE, DELETE ON public.crm_leads     TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.crm_notes     TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.crm_reminders TO authenticated;
