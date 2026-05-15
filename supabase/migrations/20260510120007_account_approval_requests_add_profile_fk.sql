-- Phase 5 (spec/005-auth-profile) — Migration 7/7
-- Adds a foreign key from account_approval_requests.user_id → profiles.user_id.
--
-- Why: PostgREST embedded select (queue + profile snippets in one HTTPS call)
-- requires an FK relationship. account_approval_requests.user_id already FK'd
-- to auth.users(id), and profiles.user_id is the PK of profiles, so this FK
-- is redundant in referential terms but lets PostgREST infer the join path,
-- avoiding a second HTTPS request that HiOS-throttled devices block.
--
-- Consumed by: lib/features/admin/account_approvals/data/datasources/supabase_account_approvals_datasource.dart
-- via `.select('*, profiles(phone, email, full_name)')`.
--
-- Idempotent: ADD CONSTRAINT IF NOT EXISTS is not standard, so we use a DO block.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'fk_account_approval_requests_profile'
      AND conrelid = 'public.account_approval_requests'::regclass
  ) THEN
    ALTER TABLE public.account_approval_requests
      ADD CONSTRAINT fk_account_approval_requests_profile
      FOREIGN KEY (user_id) REFERENCES public.profiles(user_id);
  END IF;
END
$$;
