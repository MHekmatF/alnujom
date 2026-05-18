-- Phase 9: add user_preferences.display_currency FK.
-- FR-019 + R-14.
-- Runs after currencies seed so existing 'SYP' defaults satisfy the FK.
-- Existing user_preferences rows are not modified by this migration.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'user_preferences_display_currency_fkey'
  ) THEN
    ALTER TABLE public.user_preferences
      ADD CONSTRAINT user_preferences_display_currency_fkey
      FOREIGN KEY (display_currency)
      REFERENCES public.currencies(code)
      ON DELETE SET NULL;
  END IF;
END $$;
