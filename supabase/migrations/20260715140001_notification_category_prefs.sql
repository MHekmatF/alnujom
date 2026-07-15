-- Phase 035 — per-category notification preferences.
--
-- Additive columns on user_preferences honored by the dispatch_push edge
-- function (alongside the existing global notifications_enabled mute). Defaults
-- match the Settings design: new-matches ON, messages ON, marketing OFF.
-- Applied to the live project via Supabase MCP apply_migration on 2026-07-15.
ALTER TABLE public.user_preferences
  ADD COLUMN IF NOT EXISTS notif_new_matches boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notif_messages    boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notif_marketing   boolean NOT NULL DEFAULT false;
