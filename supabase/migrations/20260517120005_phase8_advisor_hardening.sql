-- Phase 8: Advisor hardening for the locations catalog.
-- Source: specs/008-locations/research.md R-04 (anon SELECT carve-out) + R-16 (documented in migration comments).
-- Pattern: codify the anon GRANT explicitly + REVOKE the write surfaces from anon as defense-in-depth on top of the RLS policies.

GRANT SELECT ON public.governorates TO anon, authenticated;
GRANT SELECT ON public.cities       TO anon, authenticated;
GRANT SELECT ON public.areas        TO anon, authenticated;

REVOKE INSERT, UPDATE, DELETE ON public.governorates FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.cities       FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.areas        FROM anon;

-- Harden immutability trigger functions: remove SECURITY DEFINER (not needed — triggers only
-- read OLD.* and raise exceptions; no elevated privileges required).
-- Pattern: Phase 6 applied the same treatment to enforce_role_system_immutability.
CREATE OR REPLACE FUNCTION public.enforce_governorate_system_immutability()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, auth
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.is_system THEN
      RAISE EXCEPTION 'governorate_system_immutable: cannot delete a system governorate (key=%)', OLD.key
        USING ERRCODE = '42501';
    END IF;
    RETURN OLD;
  END IF;
  IF TG_OP = 'UPDATE' THEN
    IF OLD.is_system AND NEW.key IS DISTINCT FROM OLD.key THEN
      RAISE EXCEPTION 'governorate_system_immutable: cannot rename a system governorate''s key (was %, attempted %)', OLD.key, NEW.key
        USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.enforce_city_system_immutability()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, auth
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.is_system THEN
      RAISE EXCEPTION 'city_system_immutable: cannot delete a system city (key=%)', OLD.key
        USING ERRCODE = '42501';
    END IF;
    RETURN OLD;
  END IF;
  IF TG_OP = 'UPDATE' THEN
    IF OLD.is_system AND NEW.key IS DISTINCT FROM OLD.key THEN
      RAISE EXCEPTION 'city_system_immutable: cannot rename a system city''s key (was %, attempted %)', OLD.key, NEW.key
        USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;
  RETURN NEW;
END;
$$;
