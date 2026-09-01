-- 20260901120004_self_serve_account_deletion
--
-- Self-serve account deletion — `public.request_account_deletion()`.
--
-- WHY: Google Play policy requires every app that offers account creation to
-- offer in-app account deletion. The client surface is
-- `lib/features/profile/presentation/pages/account_deletion_page.dart`.
--
-- ⚠️  NOT YET APPLIED. The Supabase project was paused/unreachable when this
--     was written, so nothing here has run against a live database. Apply via
--     Supabase MCP `apply_migration(name='20260901120004_self_serve_account_deletion',
--     query='<this file body>')` — per the project gotcha, apply_migration does
--     NOT dedupe by name, so apply exactly ONCE. Everything below is idempotent
--     and re-runnable (create-if-not-exists / create-or-replace / drop-then-create
--     policy) if a re-run is ever needed.
--
-- ===========================================================================
-- DELETION SEMANTICS — soft-delete + anonymize (NOT a hard `DELETE FROM auth.users`)
-- ===========================================================================
-- A hard delete is the wrong tool here for four concrete reasons:
--
--   1. It destroys OTHER people's records. `conversations`, `viewings`,
--      `reviews`, `agencies` and `crm_leads` all CASCADE off auth.users, so a
--      hard delete silently removes a publisher's counterparty history along
--      with the leaver's.
--   2. It breaks the moderation/audit trail this project is built around
--      (`audit_logs`, `listing_status_history`, `moderation_actions`).
--      Listings deliberately soft-delete via `status='deleted'`, and
--      `inquiries`/`lead_events`/`reports` FK them with ON DELETE RESTRICT.
--   3. DATA-1 (docs/qa/e2e-2026-07-16): `crm_leads.contact_user_id` is
--      ON DELETE SET NULL but `crm_leads_identity` CHECKs that at least one of
--      (contact_user_id, source_inquiry_id) stays non-null, so a hard delete
--      throws 23514 for any user who ever messaged a listing. Handled below.
--   4. Deleting the `auth.users` row from a client-callable RPC is a foot-gun:
--      GoTrue owns those rows and the supported path is the admin API. (§3.11
--      does make one narrow, best-effort, exception-guarded WRITE to auth —
--      renaming the sign-in identifier, exactly what the existing
--      sync_auth_email_from_profile trigger already does — but never a DELETE.)
--
-- So this RPC performs an IMMEDIATE, IRREVERSIBLE, synchronous erasure of the
-- user's personal data and content, and tombstones the account so it can never
-- be used again:
--
--   * profiles          → full_name / username / phone / email / avatar_url
--                         nulled; account_status = publisher_status = 'deleted'.
--                         AuthBloc._stateFromProfile already maps 'deleted' to
--                         Unauthenticated, so the tombstone is a hard sign-out
--                         even if a stale session is replayed. Nulling the
--                         UNIQUE phone/username also RELEASES those identifiers
--                         for a future re-registration.
--   * vault.secrets     → the three `pii.<uid>.*` entries (legal name, national
--                         id, private contact methods) are DELETED outright.
--   * listings          → status='deleted' + expires_at=now() (drops out of
--                         every public read path: `listings_select_public`,
--                         `v_listings_public`, `search_listings`, `search_map`)
--                         and phone/whatsapp nulled.
--   * chat / viewings /
--     reviews / favorites /
--     saved_searches /
--     reports / notifications /
--     tokens / prefs /
--     roles / approval req.  → DELETED (free-text and behavioural data that
--                         cannot be meaningfully anonymized).
--   * inquiries         → kept as the publisher's business record but fully
--                         de-identified: sender_user_id nulled, sender_name
--                         replaced with a neutral marker, and the Vault-encrypted
--                         inquirer phone ciphertext DELETED.
--   * lead_events       → user_id + metadata ({ip,user_agent}) nulled; the
--                         publisher keeps the aggregate counts.
--   * crm_*             → owned pipeline deleted; the leaver's presence as a
--                         CONTACT on someone else's pipeline is scrubbed
--                         (DATA-1, see §3.3).
--   * auth.users        → the synthetic `<phone>@alnujom.local` sign-in address
--                         is renamed to a per-user tombstone and the identity
--                         payload scrubbed (§3.11), so the old credentials stop
--                         resolving and the PHONE NUMBER IS ACTUALLY RELEASED
--                         for a future signup. Best-effort — see §3.11.
--   * ad_impressions    → user_id nulled (behavioural tracking).
--   * agencies          → an owned agency is SUSPENDED (leaves the public
--                         directory; an admin can reassign or close it) and its
--                         contact numbers nulled; memberships in other agencies
--                         are marked 'removed'.
--
-- DELIBERATELY PRESERVED (this is the audit trail, not personal data):
--   audit_logs.actor_user_id, listing_status_history.changed_by,
--   moderation_actions.performed_by, account_approval_requests.reviewed_by,
--   exchange_rates.created_by, app_settings.updated_by, ads.created_by.
--   Every one of those is ON DELETE SET NULL, so they degrade gracefully if the
--   operator later purges the auth user.
--
-- OPERATOR FOLLOW-UP (out of scope for SQL): the `auth.users` ROW itself and
-- the user's Storage objects (avatars / listing-media / agency assets) are not
-- removed here — only the sign-in identifier on that row is neutralised.
-- `public.account_deletion_requests` (§1) is the durable work queue for the
-- final `auth.admin.deleteUser` + bucket sweep; it intentionally has NO FK to
-- auth.users so the record survives that purge. Flip `purge_status` to 'purged'
-- once done.

-- ===========================================================================
-- 1. TABLE public.account_deletion_requests — the operator's purge work queue
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.account_deletion_requests (
  id                     UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  -- No FK to auth.users ON PURPOSE: this row is the operator's work item for
  -- the final auth-user purge and must outlive it.
  user_id                UUID        NOT NULL,
  requested_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  listings_removed       INTEGER     NOT NULL DEFAULT 0,
  conversations_removed  INTEGER     NOT NULL DEFAULT 0,
  crm_leads_removed      INTEGER     NOT NULL DEFAULT 0,
  purge_status           TEXT        NOT NULL DEFAULT 'pending_auth_purge'
                           CHECK (purge_status IN ('pending_auth_purge','purged')),
  purged_at              TIMESTAMPTZ
);

-- One request per user (the RPC is idempotent and returns early on a re-call;
-- this index is the race backstop, matching the reports/dedup precedent).
CREATE UNIQUE INDEX IF NOT EXISTS ux_account_deletion_requests_user
  ON public.account_deletion_requests (user_id);

-- The operator's "what still needs purging" scan.
CREATE INDEX IF NOT EXISTS ix_account_deletion_requests_pending
  ON public.account_deletion_requests (requested_at DESC)
  WHERE purge_status = 'pending_auth_purge';

ALTER TABLE public.account_deletion_requests ENABLE ROW LEVEL SECURITY;

-- Supabase grants ALL on new public tables to anon+authenticated via default
-- privileges — strip that first, then re-grant read only.
REVOKE ALL ON public.account_deletion_requests FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.account_deletion_requests TO authenticated;

-- Read gate mirrors the audit-log viewer (20260601120004). Scoped TO
-- authenticated so the anon-calling-current_user_has_permission 42501 footgun
-- cannot fire; anon holds no grant at all.
DROP POLICY IF EXISTS account_deletion_requests_select_audit
  ON public.account_deletion_requests;
CREATE POLICY account_deletion_requests_select_audit
  ON public.account_deletion_requests
  FOR SELECT TO authenticated
  USING (public.current_user_has_permission('audit_logs.view'));

COMMENT ON TABLE public.account_deletion_requests IS
  'Self-serve account deletions. Written only by public.request_account_deletion(). '
  'No FK to auth.users so the row survives the operator''s final auth-user purge.';

-- ===========================================================================
-- 2. AMENDED public.enforce_profile_status_admin_only()
-- ===========================================================================
-- Re-based CREATE OR REPLACE amendment (the 20260602120004 idiom). Base body:
-- 20260515120009_fix_enforce_profile_status_search_path.sql — every existing
-- line, the LANGUAGE/SECURITY INVOKER/search_path header, the predicate and the
-- 42501 raise are preserved VERBATIM. Exactly ONE branch is added.
--
-- WHY IT IS NEEDED: the live trigger allows a status change only when
-- `current_user_is_admin()` OR `auth.role() = 'service_role'`. Neither is true
-- for a user deleting their own account, and SECURITY DEFINER does NOT help —
-- the current body no longer consults `current_user`, so the definer-owner
-- bypass that existed in the Phase-4/5 versions is gone. Without this branch
-- the tombstone UPDATE in §3 fails with 42501.
--
-- WHY IT IS SAFE: the branch fires only when (a) BOTH status columns are moving
-- to 'deleted' — no other status is reachable through it — and (b) a
-- TRANSACTION-SCOPED GUC names this exact row's owner. The GUC is set by
-- request_account_deletion() immediately before its UPDATE (the same
-- session-variable handoff idiom as `set_app_user_id_for_session`,
-- 20260523120004) and `set_config` lives in pg_catalog, so PostgREST never
-- exposes it to a client. Even if a caller could set it, `profiles_update_self`
-- restricts a client UPDATE to their own row and the branch requires
-- NEW.user_id to equal the GUC value — the widest reachable outcome is
-- self-deletion, which the RPC already grants. It confers no cross-user power.
CREATE OR REPLACE FUNCTION public.enforce_profile_status_admin_only()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, auth
AS $$
BEGIN
  -- Self-serve account deletion (20260901120001) — the single narrow allowance.
  IF NEW.account_status = 'deleted'
     AND NEW.publisher_status = 'deleted'
     AND nullif(current_setting('app.account_self_deletion', true), '') = NEW.user_id::text
  THEN
    RETURN NEW;
  END IF;

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
-- CREATE OR REPLACE rebinds the body; the existing
-- trg_profiles_enforce_status_admin_only trigger keeps firing (no DROP needed).

-- ===========================================================================
-- 3. RPC public.request_account_deletion()
-- ===========================================================================
-- NO PARAMETERS BY DESIGN: the target is always `auth.uid()`, so it is
-- structurally impossible to delete anyone else's account. SECURITY DEFINER +
-- pinned search_path (Constitution III). Runs as one implicit transaction — a
-- failure anywhere rolls the whole erasure back.
CREATE OR REPLACE FUNCTION public.request_account_deletion()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, vault
AS $$
DECLARE
  v_uid              UUID        := auth.uid();
  v_now              TIMESTAMPTZ := now();
  v_listings         INTEGER     := 0;
  v_conversations    INTEGER     := 0;
  v_leads_owned      INTEGER     := 0;
  v_leads_as_contact INTEGER     := 0;
  v_agency_id        UUID;
  v_secret_name      TEXT;
  v_auth_released    BOOLEAN     := FALSE;
  v_summary          JSONB;
  -- Neutral marker left in a publisher's inbox / CRM where a row is kept as
  -- their business record but the person behind it is erased. Arabic-first
  -- (Principle V) — these surfaces are publisher-facing and Arabic in practice.
  c_anon_label CONSTANT TEXT := 'حساب محذوف';
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501';
  END IF;

  -- ── Idempotency: a repeat call is a no-op that reports the original request.
  IF EXISTS (
    SELECT 1 FROM public.profiles p
     WHERE p.user_id = v_uid AND p.account_status = 'deleted'
  ) THEN
    SELECT jsonb_build_object(
             'status',       'already_deleted',
             'requested_at', adr.requested_at
           )
      INTO v_summary
      FROM public.account_deletion_requests adr
     WHERE adr.user_id = v_uid;
    RETURN coalesce(v_summary, jsonb_build_object('status', 'already_deleted'));
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = v_uid) THEN
    RAISE EXCEPTION 'profile not found' USING ERRCODE = 'P0002';
  END IF;

  -- ── 3.1 Listings: soft-delete + strip the owner's contact PII ─────────────
  -- 'deleted' fails every public predicate (status='approved'), so the listings
  -- leave browse/search/map immediately. The listings audit + status-history
  -- triggers fire on this UPDATE and record the transition for us.
  UPDATE public.listings l
     SET status     = 'deleted',
         phone      = NULL,
         whatsapp   = NULL,
         expires_at = v_now,
         updated_at = v_now
   WHERE l.publisher_user_id = v_uid
     AND l.status <> 'deleted';
  GET DIAGNOSTICS v_listings = ROW_COUNT;

  DELETE FROM public.listing_revisions lr WHERE lr.publisher_user_id = v_uid;

  -- ── 3.2 CRM — the leaver's OWN pipeline ──────────────────────────────────
  -- Notes/reminders cascade off crm_leads, but delete them explicitly first so
  -- the erasure is legible (spec 021 DATA-1 names all four tables).
  DELETE FROM public.crm_reminders cr WHERE cr.publisher_user_id = v_uid;
  DELETE FROM public.crm_notes     cn WHERE cn.publisher_user_id = v_uid;
  DELETE FROM public.crm_leads     cl WHERE cl.publisher_user_id = v_uid;
  GET DIAGNOSTICS v_leads_owned = ROW_COUNT;

  -- ── 3.3 CRM — the leaver as a CONTACT on someone else's pipeline (DATA-1) ─
  -- `crm_leads_identity` CHECKs (contact_user_id IS NOT NULL OR
  -- source_inquiry_id IS NOT NULL). A lead whose ONLY identity is this contact
  -- therefore cannot be anonymized — it must go. A lead that is also anchored
  -- to a source inquiry keeps a valid identity, so scrub the person instead and
  -- leave the publisher their lead. This is the fix DATA-1 asked for.
  DELETE FROM public.crm_leads cl
   WHERE cl.contact_user_id = v_uid
     AND cl.source_inquiry_id IS NULL;
  GET DIAGNOSTICS v_leads_as_contact = ROW_COUNT;

  UPDATE public.crm_leads cl
     SET contact_user_id = NULL,
         display_name    = c_anon_label,
         updated_at      = v_now
   WHERE cl.contact_user_id = v_uid;

  -- ── 3.4 Inquiries the leaver sent — de-identify, keep the record ──────────
  -- inquiries.listing_id is ON DELETE RESTRICT and the row is the publisher's
  -- business record, so it stays; the person is erased from it, including the
  -- Vault-encrypted phone ciphertext. (Only non-status columns change, so the
  -- enforce_inquiry_transition trigger is not involved.)
  UPDATE public.inquiries i
     SET sender_user_id           = NULL,
         sender_name              = c_anon_label,
         inquirer_phone_encrypted = NULL,
         updated_at               = v_now
   WHERE i.sender_user_id = v_uid;

  -- ── 3.5 Engagement signals — keep the publisher's counts, drop the person ─
  UPDATE public.lead_events le
     SET user_id  = NULL,
         metadata = NULL          -- {ip, user_agent}
   WHERE le.user_id = v_uid;

  UPDATE public.ad_impressions ai
     SET user_id = NULL
   WHERE ai.user_id = v_uid;

  -- ── 3.6 Free-text / behavioural data that cannot be anonymized ────────────
  -- Chat bodies routinely carry names, phone numbers and addresses; there is no
  -- meaningful anonymization, so the threads go (messages cascade off
  -- conversations). Viewings and reviews have NOT NULL CASCADE user FKs on both
  -- sides, so they cannot be de-identified either.
  DELETE FROM public.messages m WHERE m.sender_user_id = v_uid;
  DELETE FROM public.conversations c
   WHERE c.buyer_user_id = v_uid OR c.publisher_user_id = v_uid;
  GET DIAGNOSTICS v_conversations = ROW_COUNT;

  DELETE FROM public.viewings v
   WHERE v.requester_user_id = v_uid OR v.publisher_user_id = v_uid;

  DELETE FROM public.reviews r
   WHERE r.reviewer_user_id = v_uid OR r.target_user_id = v_uid;

  -- ── 3.7 Purely personal account rows ─────────────────────────────────────
  -- reports: moderation_actions.report_id is ON DELETE SET NULL, so the
  -- moderation trail survives the report's removal.
  DELETE FROM public.favorites                 f  WHERE f.user_id           = v_uid;
  DELETE FROM public.saved_searches            s  WHERE s.user_id           = v_uid;
  DELETE FROM public.reports                   rp WHERE rp.reporter_user_id = v_uid;
  DELETE FROM public.notification_tokens       nt WHERE nt.user_id          = v_uid;
  DELETE FROM public.notifications             n  WHERE n.recipient_user_id = v_uid;
  DELETE FROM public.account_approval_requests ar WHERE ar.user_id          = v_uid;
  DELETE FROM public.user_roles                ur WHERE ur.user_id          = v_uid;
  DELETE FROM public.user_preferences          up WHERE up.user_id          = v_uid;

  -- ── 3.8 Agency ───────────────────────────────────────────────────────────
  -- Memberships elsewhere: mark removed (keeps the other agency's roster
  -- history without leaving a live member pointing at a dead account).
  UPDATE public.agency_members am
     SET status     = 'removed',
         updated_at = v_now
   WHERE am.user_id = v_uid
     AND am.status <> 'removed';

  -- An owned agency cannot be transferred from here (agencies.owner_user_id is
  -- NOT NULL UNIQUE). Suspend it: it drops out of the public directory and an
  -- admin can reassign or close it. Its contact numbers are the owner's PII.
  SELECT a.id INTO v_agency_id
    FROM public.agencies a
   WHERE a.owner_user_id = v_uid;

  IF v_agency_id IS NOT NULL THEN
    UPDATE public.agencies a
       SET status     = 'suspended',
           phone      = NULL,
           whatsapp   = NULL,
           updated_at = v_now
     WHERE a.id = v_agency_id;
  END IF;

  -- ── 3.9 Vault PII purge (ADR-0001 store) ─────────────────────────────────
  -- Primary path: delete the three `pii.<uid>.*` rows outright. `vault.secrets`
  -- is owned by supabase_admin and the grants it exposes to `postgres` have
  -- varied across Supabase releases, so fall back to overwriting each existing
  -- secret in place through the Vault's own definer API (the exact call the PII
  -- WRITE path already uses — 20260510120004) when DELETE is not permitted.
  -- Either way the plaintext is destroyed; any OTHER error propagates and rolls
  -- the whole erasure back rather than half-succeeding.
  BEGIN
    DELETE FROM vault.secrets s
     WHERE s.name IN (
             format('pii.%s.legal_name',               v_uid),
             format('pii.%s.national_id',              v_uid),
             format('pii.%s.private_contact_methods',  v_uid)
           );
  EXCEPTION WHEN insufficient_privilege OR undefined_table THEN
    FOREACH v_secret_name IN ARRAY ARRAY[
      format('pii.%s.legal_name',              v_uid),
      format('pii.%s.national_id',             v_uid),
      format('pii.%s.private_contact_methods', v_uid)
    ] LOOP
      -- Only touch secrets that actually exist — never create empty ones.
      IF public.app_vault_secret(v_secret_name) IS NOT NULL THEN
        PERFORM vault.create_secret(
          '', v_secret_name, 'AlNujom PII — erased by account deletion'
        );
      END IF;
    END LOOP;
  END;

  -- ── 3.10 Tombstone the profile ───────────────────────────────────────────
  -- Nulling the UNIQUE phone/username releases those identifiers (Postgres
  -- UNIQUE permits many NULLs) so the person may register again later.
  -- The GUC is transaction-scoped (third arg true) — see §2.
  PERFORM set_config('app.account_self_deletion', v_uid::text, true);

  UPDATE public.profiles p
     SET full_name        = NULL,
         username         = NULL,
         phone            = NULL,
         email            = NULL,
         avatar_url       = NULL,
         account_status   = 'deleted',
         publisher_status = 'deleted',
         updated_at       = v_now
   WHERE p.user_id = v_uid;
  -- trg_profiles_audit_status writes the 'profile.status_changed' audit row.
  -- trg_profiles_sync_auth_email also fires here, but both NEW.email and
  -- NEW.phone are now NULL so it returns early without touching auth.

  -- Close the window immediately (the GUC would expire with the transaction
  -- anyway — this just keeps the allowance scoped to the one statement above).
  PERFORM set_config('app.account_self_deletion', '', true);

  -- ── 3.11 Release the auth-side identifier ────────────────────────────────
  -- Nulling profiles.phone alone does NOT free the number: sign-in resolves the
  -- synthetic `<phone>@alnujom.local` address on auth.users (20260514120001),
  -- so the row would keep the phone reserved forever and the old credentials
  -- would keep resolving. Rename it to a per-user tombstone address and scrub
  -- the identity payload — the same two tables, in the same order, that
  -- sync_auth_email_from_profile() already maintains.
  --
  -- Best-effort ON PURPOSE: the `auth` schema belongs to GoTrue and its shape
  -- moves between releases. A surprise here must not cost the user their
  -- deletion — the profile is already tombstoned above, and AuthBloc maps
  -- account_status='deleted' to Unauthenticated, so a replayed session is inert
  -- either way. `auth_identifier_released` in the return value + audit row tells
  -- the operator whether the final auth.users purge still has work to do.
  BEGIN
    UPDATE auth.users u
       SET email              = format('deleted-%s@deleted.alnujom.local', v_uid),
           phone              = NULL,
           raw_user_meta_data = '{}'::jsonb
     WHERE u.id = v_uid;

    -- auth.identities.email is generated from identity_data->>'email', so only
    -- identity_data is written (mirrors sync_auth_email_from_profile()).
    UPDATE auth.identities i
       SET identity_data = jsonb_set(
             i.identity_data,
             '{email}',
             to_jsonb(format('deleted-%s@deleted.alnujom.local', v_uid))
           )
     WHERE i.user_id = v_uid AND i.provider = 'email';

    v_auth_released := TRUE;
  EXCEPTION WHEN OTHERS THEN
    v_auth_released := FALSE;
  END;

  -- ── 3.12 Durable record + explicit audit entry ───────────────────────────
  INSERT INTO public.account_deletion_requests
    (user_id, requested_at, listings_removed, conversations_removed, crm_leads_removed)
  VALUES
    (v_uid, v_now, v_listings, v_conversations, v_leads_owned + v_leads_as_contact)
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.audit_logs
    (actor_user_id, action, target_type, target_id, before_state, after_state)
  VALUES (
    v_uid,
    'account.self_deleted',
    'profiles',
    v_uid::text,
    NULL,
    jsonb_build_object(
      'listings_removed',          v_listings,
      'conversations_removed',     v_conversations,
      'crm_leads_removed',         v_leads_owned + v_leads_as_contact,
      'auth_identifier_released',  v_auth_released
    )
  );

  RETURN jsonb_build_object(
    'status',                   'deleted',
    'requested_at',             v_now,
    'listings_removed',         v_listings,
    'conversations_removed',    v_conversations,
    'crm_leads_removed',        v_leads_owned + v_leads_as_contact,
    'auth_identifier_released', v_auth_released
  );
END;
$$;

COMMENT ON FUNCTION public.request_account_deletion() IS
  'Self-serve account deletion (Google Play requirement). Takes no parameters — '
  'always acts on auth.uid(). Erases the caller''s personal data, removes their '
  'listings from every public surface, and tombstones the profile as ''deleted''. '
  'Irreversible. Authenticated callers only.';

-- ===========================================================================
-- 4. Grants — authenticated ONLY
-- ===========================================================================
-- Project gotcha: a new public function is granted EXECUTE to PUBLIC (which
-- includes anon) by default. Strip it explicitly before granting.
REVOKE EXECUTE ON FUNCTION public.request_account_deletion() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.request_account_deletion() FROM anon;
GRANT  EXECUTE ON FUNCTION public.request_account_deletion() TO authenticated;

-- ===========================================================================
-- 5. Post-apply assertion
-- ===========================================================================
-- The RPC bypasses RLS by running as its owner (Supabase's `postgres` owns the
-- public tables and holds BYPASSRLS). If it somehow lands on a role that does
-- not, the erasure would silently no-op on RLS-protected tables — fail the
-- migration loudly instead.
DO $$
DECLARE
  v_owner TEXT;
  v_anon  BOOLEAN;
BEGIN
  SELECT pg_get_userbyid(p.proowner) INTO v_owner
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname = 'request_account_deletion';

  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'public.request_account_deletion() was not created';
  END IF;

  IF v_owner NOT IN ('postgres', 'supabase_admin', 'service_role') THEN
    RAISE EXCEPTION
      'public.request_account_deletion() is owned by %, which is not a privileged '
      'role — it will not bypass RLS on the tables it must erase. Re-apply as postgres.',
      v_owner;
  END IF;

  SELECT has_function_privilege('anon', 'public.request_account_deletion()', 'EXECUTE')
    INTO v_anon;
  IF v_anon THEN
    RAISE EXCEPTION 'anon still holds EXECUTE on public.request_account_deletion()';
  END IF;
END $$;
