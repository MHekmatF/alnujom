-- Phase 10: Listing Creation - alter public.areas with centroid columns.
-- FR-013a, R-07, Q2 resolution: area-centroid auto-fill from OpenStreetMap-sourced seed data.
-- Remote Phase 8 sealed schema uses key/display_name JSON; seed by stable area id.

ALTER TABLE public.areas
  ADD COLUMN IF NOT EXISTS centroid_lat NUMERIC(9, 6),
  ADD COLUMN IF NOT EXISTS centroid_lng NUMERIC(9, 6);

UPDATE public.areas SET centroid_lat = 33.486389, centroid_lng = 36.348278 WHERE id = '1eff37c6-6ca3-4d3f-8be6-0390e555b34b'; -- Jaramana Center, Damascus
UPDATE public.areas SET centroid_lat = 33.509573, centroid_lng = 36.309509 WHERE id = 'd0c64e78-156a-4251-94fa-1892d7bb184e'; -- Old City Damascus, Damascus
UPDATE public.areas SET centroid_lat = 33.527448, centroid_lng = 36.211842 WHERE id = '428f880d-0f20-4c55-bfca-f891a92d2e27'; -- Mashrouh Dummar, Damascus
UPDATE public.areas SET centroid_lat = 33.502155, centroid_lng = 36.245687 WHERE id = 'a2d402fa-7aab-4ed8-a42a-3533a8ce6b3f'; -- Mezzeh, Damascus
UPDATE public.areas SET centroid_lat = 36.216548, centroid_lng = 37.159055 WHERE id = '6f2b870b-9aa2-4d77-9d7f-e6c86b4bf8fe'; -- Sulaymaniyah, Aleppo
UPDATE public.areas SET centroid_lat = 36.199469, centroid_lng = 37.163613 WHERE id = '3b50a365-1c33-48cf-988b-6abf9251042a'; -- Aleppo Old City, Aleppo
UPDATE public.areas SET centroid_lat = 34.725181, centroid_lng = 36.724225 WHERE id = '4939c36f-605f-4469-bbbf-9496ade113b8'; -- Homs Old City, Homs
UPDATE public.areas SET centroid_lat = 35.520997, centroid_lng = 35.801044 WHERE id = 'ef048e5b-4496-4e6f-bdc7-74e1029189ff'; -- Latakia Corniche, Latakia
UPDATE public.areas SET centroid_lat = 34.873137, centroid_lng = 35.882914 WHERE id = 'a5d399c4-b7db-405e-bb90-d2f6ec2195b8'; -- Tartus Corniche, Tartus
UPDATE public.areas SET centroid_lat = 35.135055, centroid_lng = 36.768125 WHERE id = '76d218cb-8670-420d-837d-01c0f95c4abe'; -- Hama Norias, Hama

DO $$
DECLARE
  missing_count INT;
BEGIN
  SELECT COUNT(*) INTO missing_count FROM public.areas WHERE centroid_lat IS NULL OR centroid_lng IS NULL;
  IF missing_count > 0 THEN
    RAISE EXCEPTION 'Cannot enforce NOT NULL: % areas missing centroid', missing_count;
  END IF;
END $$;

ALTER TABLE public.areas
  ALTER COLUMN centroid_lat SET NOT NULL,
  ALTER COLUMN centroid_lng SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_schema = 'public'
      AND table_name = 'areas'
      AND constraint_name = 'areas_centroid_syria_bounds'
  ) THEN
    ALTER TABLE public.areas
      ADD CONSTRAINT areas_centroid_syria_bounds
      CHECK (centroid_lat BETWEEN 32 AND 37 AND centroid_lng BETWEEN 35 AND 43);
  END IF;
END $$;
