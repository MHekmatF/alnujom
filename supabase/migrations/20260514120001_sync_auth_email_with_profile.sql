-- spec/005-auth-profile — Option B fix for US3 architectural defect
--
-- Problem: the synthetic-email login design stored `auth.users.email = <phone>@alnujom.local`
-- while `profiles.email` held the optional real email. Supabase's
-- `auth.admin.generateLink({type:'recovery'})` is keyed on auth.users.email, so reset
-- emails never reached the real address.
--
-- Fix: keep auth.users.email in sync with profiles. When profiles.email is a real
-- (non-synthetic) value, auth.users.email = that real value. Otherwise auth.users.email
-- = <phone>@alnujom.local (the synthetic form, recoverable from profiles.phone).
--
-- Login changes (Flutter side): the auth datasource now calls a new lookup Edge Function
-- (`lookup_email_by_phone`) before signInWithPassword, so users can sign in by phone
-- regardless of whether their auth email is real or synthetic.
--
-- Discovered during T084 manual verification (2026-05-14). The original contract in
-- request-password-reset-edge-fn.md assumed generateLink would deliver to the email
-- passed in; in reality it requires that email to match an existing auth user.

-- ─── 1. Sync trigger function ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.sync_auth_email_from_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_target_email TEXT;
  v_current_email TEXT;
BEGIN
  -- Determine target auth.users.email.
  -- Real email (non-synthetic) wins; otherwise fall back to <phone>@alnujom.local.
  IF NEW.email IS NOT NULL
     AND NEW.email <> ''
     AND NEW.email NOT LIKE '%@alnujom.local'
  THEN
    v_target_email := NEW.email;
  ELSIF NEW.phone IS NOT NULL AND NEW.phone <> '' THEN
    v_target_email := NEW.phone || '@alnujom.local';
  ELSE
    -- Nothing to sync (profile has neither real email nor phone yet).
    RETURN NEW;
  END IF;

  -- Read current auth.users.email; bail if user vanished (defensive).
  SELECT email INTO v_current_email FROM auth.users WHERE id = NEW.user_id;
  IF v_current_email IS NULL THEN
    RETURN NEW;
  END IF;

  -- Only update if the value actually changed.
  IF v_current_email IS DISTINCT FROM v_target_email THEN
    UPDATE auth.users
    SET email = v_target_email,
        email_confirmed_at = COALESCE(email_confirmed_at, now())
    WHERE id = NEW.user_id;

    -- Keep auth.identities (email provider) consistent so signInWithPassword
    -- looks up correctly under the new email. NOTE: auth.identities.email is a
    -- generated column derived from identity_data->>'email', so we only update
    -- identity_data; the email column recomputes automatically.
    UPDATE auth.identities
    SET identity_data = jsonb_set(
          jsonb_set(identity_data, '{email}', to_jsonb(v_target_email)),
          '{email_verified}', 'true'::jsonb
        )
    WHERE user_id = NEW.user_id AND provider = 'email';
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.sync_auth_email_from_profile() IS
  'Syncs auth.users.email + auth.identities to profiles.email (real) or '
  '<phone>@alnujom.local (synthetic). Fires on profiles INSERT or UPDATE OF email,phone.';

REVOKE EXECUTE ON FUNCTION public.sync_auth_email_from_profile() FROM PUBLIC, anon, authenticated;

-- ─── 2. Attach trigger to profiles ────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_profiles_sync_auth_email ON profiles;

CREATE TRIGGER trg_profiles_sync_auth_email
  AFTER INSERT OR UPDATE OF email, phone ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_auth_email_from_profile();

-- ─── 3. Lookup RPC for the login flow ─────────────────────────────────────
-- Called by the Edge Function `lookup_email_by_phone` (service-role only).
-- Returns the auth.users.email for a profile matching the given phone, or NULL.
CREATE OR REPLACE FUNCTION public.app_lookup_auth_email_by_phone(p_phone TEXT)
RETURNS TEXT
LANGUAGE SQL
SECURITY DEFINER
STABLE
SET search_path = public, auth
AS $$
  SELECT u.email
  FROM profiles p
  JOIN auth.users u ON u.id = p.user_id
  WHERE p.phone = p_phone
  LIMIT 1;
$$;

COMMENT ON FUNCTION public.app_lookup_auth_email_by_phone(TEXT) IS
  'Returns auth.users.email for the profile matching the given E.164 phone, or NULL. '
  'Service-role-only; consumed by the lookup_email_by_phone Edge Function.';

REVOKE EXECUTE ON FUNCTION public.app_lookup_auth_email_by_phone(TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_lookup_auth_email_by_phone(TEXT) TO service_role;

-- ─── 4. Backfill existing users ────────────────────────────────────────────
-- Any existing profile whose .email is a real address gets auth.users.email synced.
-- For profiles with synthetic-only or null email, no change (auth.users.email already
-- matches because that's what signUp set during registration).
UPDATE auth.users u
SET email = p.email,
    email_confirmed_at = COALESCE(u.email_confirmed_at, now())
FROM profiles p
WHERE p.user_id = u.id
  AND p.email IS NOT NULL
  AND p.email <> ''
  AND p.email NOT LIKE '%@alnujom.local'
  AND p.email <> u.email;

UPDATE auth.identities i
SET identity_data = jsonb_set(
      jsonb_set(i.identity_data, '{email}', to_jsonb(p.email)),
      '{email_verified}', 'true'::jsonb
    )
FROM profiles p
WHERE i.user_id = p.user_id
  AND i.provider = 'email'
  AND p.email IS NOT NULL
  AND p.email <> ''
  AND p.email NOT LIKE '%@alnujom.local'
  AND p.email <> i.email;
