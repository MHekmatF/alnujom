-- 20260901120003_normalize_auth_emails_to_synthetic
--
-- AUTH-M2 (docs/qa/e2e-2026-07-16/SECURITY_AUDIT.md §Technical finding index).
--
-- THE LEAK: `lookup_email_by_phone` is a PUBLIC, pre-login Edge Function — the
-- Flutter client calls it with a phone and gets back the account's
-- `auth.users.email` so it can then `signInWithPassword`. Migration
-- `20260514120001` made `auth.users.email` MIRROR a real `profiles.email` when
-- one is on file, so for those accounts (the audit found 3 of 12) the endpoint
-- hands any anonymous caller a phone → real-email mapping, AND the real-vs-
-- synthetic shape of the answer is an existence oracle: a synthetic reply means
-- "no account, or an account without a real email", a real reply means "this
-- number is registered". The other 9 (synthetic-email) accounts already leaked
-- nothing.
--
-- THE FIX (as scoped by the audit): `auth.users.email` becomes ALWAYS the
-- synthetic `<E.164 phone>@alnujom.local`; the real address lives only in
-- `profiles.email`. The lookup then returns a value that is a pure function of
-- its own input — identical for registered and unregistered numbers — so there
-- is nothing left to disclose and nothing left to probe.
--
-- LOGIN IS PRESERVED — verified against the client before writing this:
--   `lib/features/auth/data/datasources/supabase_auth_datasource.dart`
--   signs in with whatever `lookup_email_by_phone` returns, and already
--   DEFAULTS to `syntheticEmailFor(phone)` (`…/data/internal/synthetic_email.dart`,
--   same `<e164>@alnujom.local` format) when the call fails. After this
--   migration the lookup returns exactly that default, so every account signs in
--   on the path the other 9 accounts already used. Passwords are untouched, and
--   `auth.identities.identity_data->>'email'` is moved in the same transaction
--   so GoTrue resolves the credential under the new address. Signup was already
--   synthetic-only (`signUp(email: syntheticEmailFor(phone))`).
--   ⇒ NO Edge Function redeploy and NO app change are required.
--
-- ⚠️ KNOWN TRADE-OFF — READ BEFORE APPLYING (operator decision):
--   `request_password_reset` calls `auth.admin.generateLink({type:'recovery',
--   email: profiles.email})`, and generateLink resolves the user BY
--   `auth.users.email`. Once that column is synthetic, the real address no
--   longer matches any auth user, so in-app "reset password by email" stops
--   working for the accounts that have a real email (the same 3). The Edge
--   Function already treats that as a soft failure — it logs
--   `generate_link_failed` and still returns the uniform `{ok:true}`, so nothing
--   breaks or starts leaking; the reset mail simply is not sent.
--   Per SECURITY_AUDIT.md that flow is already "limited today" (most accounts
--   are phone-only, spec-005 deferral L6) and the 3 affected accounts are
--   non-end-user. If email reset must keep working for a specific staff account,
--   apply this migration and then re-exempt just that one, e.g.:
--     update auth.users u set email = p.email
--       from public.profiles p
--      where p.user_id = u.id and p.phone = '+9639XXXXXXXX';
--     update auth.identities i
--        set identity_data = jsonb_set(i.identity_data, '{email}', to_jsonb(p.email))
--       from public.profiles p
--      where i.user_id = p.user_id and i.provider = 'email'
--        and p.phone = '+9639XXXXXXXX';
--   — accepting that this re-opens the disclosure for that one number.
--
-- ⚠️ AUTH-SCHEMA CAVEAT: sections 3 and 4 write to `auth.users` /
--   `auth.identities`, which the project does not own. They are the SAME
--   statements migration `20260514120001` already ran successfully in the other
--   direction, so the privileges are known-good; if a future Supabase platform
--   change makes them fail, sections 1 and 2 are still the durable fix (no NEW
--   account can get a real auth email, and the lookup discloses nothing) and the
--   backfill can be re-run later — this file is idempotent and safe to re-apply.
--
-- BACKUP FIRST: sections 3/4 overwrite `auth.users.email` in place. The prior
-- value is always recoverable from `profiles.email`, but take a snapshot anyway.
-- To preview the blast radius before applying, run section 5's SELECT on its own.

-- ─── 1. Sync trigger: real emails must never reach auth.users again ────────
-- Body is 20260514120001 §1 verbatim EXCEPT the target-email branch, which no
-- longer prefers NEW.email. Recreated in full (never rewritten from memory —
-- `pg_get_functiondef` the live copy first if you suspect drift; the only
-- committed definition is 20260514120001, verified across supabase/migrations).
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
  -- AUTH-M2: auth.users.email is ALWAYS the synthetic <phone>@alnujom.local.
  -- The real address (if any) stays in profiles.email and is never mirrored
  -- here — mirroring it is what made lookup_email_by_phone a phone→email
  -- disclosure + existence oracle.
  IF NEW.phone IS NOT NULL AND NEW.phone <> '' THEN
    v_target_email := NEW.phone || '@alnujom.local';
  ELSE
    -- Nothing to sync (profile has no phone yet). Deliberately does NOT fall
    -- back to NEW.email any more.
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
  'AUTH-M2: forces auth.users.email + auth.identities to the synthetic '
  '<phone>@alnujom.local. profiles.email keeps the real address and is never '
  'mirrored into auth (that mirroring turned lookup_email_by_phone into a '
  'phone->email disclosure). Fires on profiles INSERT or UPDATE OF email,phone.';

-- Trigger definition is unchanged; re-asserted so a from-scratch replay of this
-- file alone still wires it up.
DROP TRIGGER IF EXISTS trg_profiles_sync_auth_email ON public.profiles;
CREATE TRIGGER trg_profiles_sync_auth_email
  AFTER INSERT OR UPDATE OF email, phone ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_auth_email_from_profile();

-- ─── 2. Lookup RPC: answer from the INPUT, never from auth.users ───────────
-- Replaces the `SELECT u.email FROM profiles p JOIN auth.users u …` body. The
-- reply is now a pure function of p_phone, so it is byte-identical for a
-- registered and an unregistered number — no disclosure, no existence oracle,
-- no timing difference from a table lookup. The Edge Function contract is
-- unchanged (it still receives a non-empty string and still falls back to the
-- same synthetic form on NULL/error), so it does NOT need redeploying.
-- Kept rather than dropped so the deployed function keeps resolving its RPC.
CREATE OR REPLACE FUNCTION public.app_lookup_auth_email_by_phone(p_phone TEXT)
RETURNS TEXT
LANGUAGE SQL
IMMUTABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT CASE
           WHEN p_phone IS NULL OR p_phone = '' THEN NULL
           ELSE p_phone || '@alnujom.local'
         END;
$$;

COMMENT ON FUNCTION public.app_lookup_auth_email_by_phone(TEXT) IS
  'AUTH-M2: returns the synthetic auth email <e164>@alnujom.local for the given '
  'E.164 phone. Derived purely from the argument — it no longer reads auth.users, '
  'so it cannot disclose a real address or confirm that a number is registered. '
  'Service-role-only; consumed by the lookup_email_by_phone Edge Function.';

REVOKE EXECUTE ON FUNCTION public.app_lookup_auth_email_by_phone(TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_lookup_auth_email_by_phone(TEXT) TO service_role;

-- ─── 3. Backfill auth.identities (BEFORE auth.users) ──────────────────────
-- Ordered first because `auth.identities.email` is GENERATED from
-- identity_data->>'email'; doing it after the users update would leave a window
-- where the two disagree. Idempotent: the WHERE skips rows already synthetic.
-- Scoped to profiles that HAVE a phone — an account with no phone has no
-- synthetic form and is left exactly as it is.
UPDATE auth.identities i
SET identity_data = jsonb_set(
      jsonb_set(i.identity_data, '{email}', to_jsonb(p.phone || '@alnujom.local')),
      '{email_verified}', 'true'::jsonb
    )
FROM public.profiles p
WHERE i.user_id = p.user_id
  AND i.provider = 'email'
  AND p.phone IS NOT NULL
  AND p.phone <> ''
  AND i.identity_data->>'email' IS DISTINCT FROM (p.phone || '@alnujom.local');

-- ─── 4. Backfill auth.users ───────────────────────────────────────────────
-- No unique-index risk: `public.profiles.phone` is UNIQUE (20260506120002), so
-- `phone || '@alnujom.local'` is unique too and cannot collide with another
-- account's already-synthetic address.
UPDATE auth.users u
SET email = p.phone || '@alnujom.local',
    email_confirmed_at = COALESCE(u.email_confirmed_at, now())
FROM public.profiles p
WHERE p.user_id = u.id
  AND p.phone IS NOT NULL
  AND p.phone <> ''
  AND u.email IS DISTINCT FROM (p.phone || '@alnujom.local');

-- ─── 5. Post-apply verification (expect 0 rows) ───────────────────────────
-- Any row returned here is an account still carrying a non-synthetic auth email
-- — i.e. one this migration could not normalize (no phone on its profile, or a
-- deliberate exemption per the trade-off note above). Phones are NOT selected,
-- so the result is safe to paste into a ticket.
DO $$
DECLARE
  v_remaining integer;
BEGIN
  SELECT count(*) INTO v_remaining
  FROM auth.users u
  WHERE u.email IS NOT NULL
    AND u.email NOT LIKE '%@alnujom.local';
  RAISE NOTICE 'AUTH-M2: % auth user(s) still hold a non-synthetic email.', v_remaining;
END $$;
