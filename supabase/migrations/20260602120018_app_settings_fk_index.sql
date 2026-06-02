-- Migration: app_settings FK covering index (advisor hygiene)
-- Phase 23 — App Settings (specs/023-app-settings)
-- Clears the `unindexed_foreign_keys` INFO advisor on app_settings_updated_by_fkey,
-- matching the project's FK-index-hardening convention
-- (cf. 20260518120007_phase9_fk_index_hardening.sql, favorites_listing_fk_index).
-- Idempotent: CREATE INDEX IF NOT EXISTS.

CREATE INDEX IF NOT EXISTS idx_app_settings_updated_by
  ON public.app_settings (updated_by);
