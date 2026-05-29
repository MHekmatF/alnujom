-- Phase 17 (spec/017-favorites) — Migration 7/7 — follow-up: explicit anon revoke.
-- Verification during the DB-apply tail showed `anon` retained EXECUTE on
-- add_favorite via Supabase default function privileges (REVOKE ... FROM PUBLIC
-- did not strip it). The body's `auth_required` (28000) check already blocked
-- anonymous callers, but FR-011 specifies anon receives NO execute grant.
-- This makes the grant posture explicit (anon → 42501 permission denied) and
-- adds defense-in-depth.
REVOKE EXECUTE ON FUNCTION public.add_favorite(UUID) FROM anon;
