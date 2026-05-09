-- Migration 3: Create User Preferences + auto-provision trigger
-- Phase 4 — Supabase Foundation (FR-002, FR-004, FR-019, Q1)
-- See: research.md R-07 (atomic profile + user_preferences provisioning).
-- Apply via: Supabase MCP apply_migration(name='20260506120003_create_user_preferences', query='<file body>')

-- (a) user_preferences table
CREATE TABLE IF NOT EXISTS user_preferences (
  user_id               UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  locale                TEXT NOT NULL DEFAULT 'ar'
                        CHECK (locale IN ('ar','en')),
  theme_mode            TEXT NOT NULL DEFAULT 'system'
                        CHECK (theme_mode IN ('system','light','dark')),
  display_currency      TEXT NOT NULL DEFAULT 'SYP',
  notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- (b) updated_at trigger reusing the helper from 0002
DROP TRIGGER IF EXISTS trg_user_preferences_set_updated_at ON user_preferences;
CREATE TRIGGER trg_user_preferences_set_updated_at
  BEFORE UPDATE ON user_preferences
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- (c) handle_new_auth_user() — atomic profile + user_preferences provisioning
CREATE OR REPLACE FUNCTION handle_new_auth_user() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO profiles (user_id, account_status, publisher_status)
    VALUES (NEW.id, 'pending', 'pending')
    ON CONFLICT (user_id) DO NOTHING;
  INSERT INTO user_preferences (user_id, locale, theme_mode, display_currency, notifications_enabled)
    VALUES (NEW.id, 'ar', 'system', 'SYP', TRUE)
    ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- (d) auto-provision trigger on auth.users
DROP TRIGGER IF EXISTS trg_auth_users_handle_new ON auth.users;
CREATE TRIGGER trg_auth_users_handle_new
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_auth_user();
