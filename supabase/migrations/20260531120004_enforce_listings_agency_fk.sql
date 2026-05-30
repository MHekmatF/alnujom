-- Phase 19 (spec/019-agencies) — Migration 4/13
-- Enforce the FK Phase 10 reserved (R-17): listings.agency_id → agencies(id).
-- ON DELETE SET NULL so a removed agency leaves its listings intact (they lose
-- only the badge). All existing listings have agency_id = NULL, so the constraint
-- validates instantly (R-144; FR-018 — no existing breakage).
-- Idempotent: guarded so a re-apply does not error on the existing constraint.
-- References: data-model.md §1.4; depends on 20260531120001 (public.agencies).

DO $$ BEGIN
  ALTER TABLE public.listings
    ADD CONSTRAINT fk_listings_agency
    FOREIGN KEY (agency_id) REFERENCES public.agencies(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
