-- Phase 14: Full-text search vector on public.listings
-- Covers title + address_text using 'simple' configuration (non-morphological, Arabic-compatible).
-- description is in listing_details (separate table) and is handled via ILIKE in the RPC (R-73).

ALTER TABLE public.listings
  ADD COLUMN IF NOT EXISTS search_vector tsvector
  GENERATED ALWAYS AS (
    to_tsvector(
      'simple',
      coalesce(title, '') || ' ' || coalesce(address_text, '')
    )
  ) STORED;

CREATE INDEX IF NOT EXISTS idx_listings_search_vector
  ON public.listings USING GIN(search_vector);
