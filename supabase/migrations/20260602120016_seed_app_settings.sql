-- Migration: Seed the closed v1 app_settings catalog (8 keys)
-- Phase 23 — App Settings (specs/023-app-settings)
-- See: data-model.md §1.3/§1.5, contracts/phase23-settings-seed-and-catalog.md
-- Apply via: Supabase MCP apply_migration(name='20260602120016_seed_app_settings', query='<file body>')
--
-- Exactly 8 keys, all is_public=true. NO supported_currencies key — Phase 9
-- currencies.is_active owns supported currencies (R-198). default_currency MUST be
-- an ACTIVE currencies.code (Phase 9); enforced by the editor picker, not an FK.
-- Idempotent: ON CONFLICT (key) DO NOTHING — re-running is a no-op.

INSERT INTO public.app_settings (key, value, description, is_public) VALUES
  ('default_language',                  '"ar"'::jsonb,
     'Default UI language seeded to new users at registration', true),
  ('default_currency',                  '"SYP"'::jsonb,
     'Default display currency seeded to new users at registration', true),
  ('default_publisher_name_visibility', '"public"'::jsonb,
     'Default contact_name_visibility pre-selected on new listings', true),
  ('default_location_visibility',       '"approximate"'::jsonb,
     'Default location_visibility pre-selected on new listings', true),
  ('maintenance_mode',                  '{"on": false, "message": {"ar": null, "en": null}}'::jsonb,
     'App-wide maintenance gate + optional bilingual message', true),
  ('support_contact',                   '{"phone": null, "whatsapp": null, "email": null}'::jsonb,
     'Support contact channels surfaced in-app + on the maintenance screen', true),
  ('terms_url',                         'null'::jsonb, 'Terms-of-service URL',   true),
  ('privacy_url',                       'null'::jsonb, 'Privacy-policy URL',     true)
ON CONFLICT (key) DO NOTHING;
