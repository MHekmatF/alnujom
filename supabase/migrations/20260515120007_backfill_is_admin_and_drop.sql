-- Phase 6 — Backfill is_admin column to user_roles and drop the column.
-- Contract: contracts/is-admin-backfill-migration.md
-- FR-011, R-11, R-12, US2
-- Single transactional migration; all four effects land atomically or roll back together.

-- Step 1: Backfill the `admin` role for every prior is_admin=true user.
INSERT INTO public.user_roles (user_id, role_id, granted_by, granted_at)
SELECT p.user_id, (SELECT id FROM public.roles WHERE key = 'admin'), NULL, now()
FROM public.profiles p
WHERE p.is_admin = TRUE
ON CONFLICT (user_id, role_id) DO NOTHING;

-- Step 2: Backfill the `user` role for every existing profile.
INSERT INTO public.user_roles (user_id, role_id, granted_by, granted_at)
SELECT p.user_id, (SELECT id FROM public.roles WHERE key = 'user'), NULL, now()
FROM public.profiles p
ON CONFLICT (user_id, role_id) DO NOTHING;

-- Step 3: Drop the column (IF EXISTS ensures idempotency).
ALTER TABLE public.profiles DROP COLUMN IF EXISTS is_admin;

-- Step 4: Rewrite the trigger function so it no longer references is_admin.
-- current_user_is_admin() now resolves to the role-membership check (post migration 6).
CREATE OR REPLACE FUNCTION public.enforce_profile_status_admin_only()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, auth
AS $$
BEGIN
  IF (
    (NEW.account_status IS DISTINCT FROM OLD.account_status
     OR NEW.publisher_status IS DISTINCT FROM OLD.publisher_status)
    AND NOT public.current_user_is_admin()
    AND auth.role() <> 'service_role'
  ) THEN
    RAISE EXCEPTION 'only admins may change account_status or publisher_status'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;
