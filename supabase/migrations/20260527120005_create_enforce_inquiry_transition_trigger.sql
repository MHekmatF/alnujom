-- Phase 16 (spec/016-contact-inquiries) — Sub-Phase B Migration 3/3
-- BEFORE UPDATE OF status trigger enforcing the inquiry-status transition
-- allowlist per FR-021a + Q2=B + Q3=B.
--
-- Allowed pairs (11 total — per data-model.md §2.5 + §3.1 InquiryStatus enum):
--   new       -> seen
--   new       -> spam
--   seen      -> responded
--   seen      -> closed
--   seen      -> spam
--   responded -> closed
--   responded -> seen        (undo: publisher reverts an accidental "responded")
--   responded -> spam
--   closed    -> seen        (soft-terminal reopen per Q2=B)
--   closed    -> responded   (soft-terminal reopen per Q2=B)
--   closed    -> spam
--
-- Forbidden (notable):
--   closed    -> new         (Q2=B — `new` semantics preserved; no UI affordance)
--   seen      -> new         (no regression to `new`)
--   spam      -> *           (spam is a terminal-ish side branch in Phase 16)
--
-- A no-op (OLD.status = NEW.status) is permitted so that callers may issue
-- idempotent UPDATEs without triggering the rejection.
--
-- Failure mode: invalid transition raises SQLSTATE 23514 (check_violation)
-- with detail naming the disallowed pair, surfaced as `Failure.transitionInvalid`
-- on the Flutter side.
--
-- SECURITY DEFINER + hardened search_path defends against Constitution III
-- search-path-injection attacks.

CREATE OR REPLACE FUNCTION public.enforce_inquiry_transition()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  -- No-op: status unchanged. Allow.
  IF OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;

  -- Allowed transitions (11 pairs per data-model.md §2.5 + §3.1).
  IF (OLD.status, NEW.status) IN (
    ('new',       'seen'),
    ('new',       'spam'),
    ('seen',      'responded'),
    ('seen',      'closed'),
    ('seen',      'spam'),
    ('responded', 'closed'),
    ('responded', 'seen'),
    ('responded', 'spam'),
    ('closed',    'seen'),
    ('closed',    'responded'),
    ('closed',    'spam')
  ) THEN
    RETURN NEW;
  END IF;

  -- Everything else: reject. Notable forbidden pairs include closed->new
  -- (Q2=B) and seen->new / spam->* (no regression to new; spam terminal).
  RAISE EXCEPTION
    'invalid_inquiry_transition: % -> %', OLD.status, NEW.status
    USING ERRCODE = '23514';
END;
$$;

DROP TRIGGER IF EXISTS trg_inquiries_enforce_transition ON public.inquiries;
CREATE TRIGGER trg_inquiries_enforce_transition
  BEFORE UPDATE OF status ON public.inquiries
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_inquiry_transition();
