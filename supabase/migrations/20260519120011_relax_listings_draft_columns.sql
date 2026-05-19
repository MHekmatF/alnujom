-- Phase 10 follow-up — allow drafts to be created with NULL purpose, property_type, title.
--
-- Bug uncovered by quickstart.md Step 6 device walk: opening the
-- multi-step form fires LoadOrCreateDraft → insertDraft which INSERTs a
-- row with only publisher_user_id set. The migration declared purpose,
-- property_type, title as NOT NULL with no DEFAULT, so the INSERT errored
-- with SQLSTATE 23502 "null value in column 'purpose' violates not-null
-- constraint".
--
-- The Dart code's comment ("the remaining columns default per schema")
-- was aspirational — the original migration didn't add DEFAULTs.
--
-- Design intent (per Phase 10 data-model.md): drafts are partial-by-design;
-- the submit_listing RPC's Q1 Full required-field validation is the gate
-- that catches NULLs at submit time. So the right fix is to drop NOT NULL
-- on these three columns and adjust their CHECK constraints to allow NULL.

ALTER TABLE public.listings ALTER COLUMN purpose DROP NOT NULL;
ALTER TABLE public.listings ALTER COLUMN property_type DROP NOT NULL;
ALTER TABLE public.listings ALTER COLUMN title DROP NOT NULL;

-- Adjust the three CHECK constraints to allow NULL (was rejected previously).
ALTER TABLE public.listings DROP CONSTRAINT IF EXISTS listings_purpose_check;
ALTER TABLE public.listings ADD CONSTRAINT listings_purpose_check
  CHECK (purpose IS NULL OR purpose = ANY (ARRAY['sale','rent','daily_rent','investment']));

ALTER TABLE public.listings DROP CONSTRAINT IF EXISTS listings_property_type_check;
ALTER TABLE public.listings ADD CONSTRAINT listings_property_type_check
  CHECK (property_type IS NULL OR property_type = ANY (ARRAY['apartment','villa','land','shop','office','farm','warehouse','other']));

ALTER TABLE public.listings DROP CONSTRAINT IF EXISTS listings_title_check;
ALTER TABLE public.listings ADD CONSTRAINT listings_title_check
  CHECK (title IS NULL OR length(trim(title)) > 0);
