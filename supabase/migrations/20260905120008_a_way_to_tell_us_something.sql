-- A way to tell us something.
--
-- Review 2026-09-05 §4 G11 (plan A34). Support today is the founder's own
-- phone number and Gmail on the About screen (B3); there was no way to send a
-- problem or an idea from inside the app, and nothing to file it under. This
-- is the smallest useful version: a table, one RPC, and a status column an
-- admin can move by hand from the dashboard until an admin screen is worth
-- building. Nobody is notified on insert on purpose — the founder reads the
-- table (documented in HANDOVER §11's queues) and the row count is a better
-- signal than a push per message.

CREATE TABLE IF NOT EXISTS public.feedback (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  category    text NOT NULL CHECK (category IN ('bug', 'idea', 'question', 'other')),
  message     text NOT NULL CHECK (char_length(message) BETWEEN 1 AND 2000),
  app_build   text,
  platform    text,
  status      text NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'seen', 'done')),
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_feedback_status_created ON public.feedback (status, created_at DESC);
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.feedback FROM PUBLIC, anon, authenticated;

-- Admins may read it from the app one day; today the dashboard is the reader.
DROP POLICY IF EXISTS feedback_select_admin ON public.feedback;
CREATE POLICY feedback_select_admin ON public.feedback
  FOR SELECT TO authenticated
  USING (public.current_user_has_permission('settings.manage'));
GRANT SELECT ON public.feedback TO authenticated;

CREATE OR REPLACE FUNCTION public.submit_feedback(p_category text, p_message text, p_app_build text DEFAULT NULL::text, p_platform text DEFAULT NULL::text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_id     uuid;
  v_recent integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501';
  END IF;
  IF p_category NOT IN ('bug', 'idea', 'question', 'other') THEN
    RAISE EXCEPTION 'invalid_category' USING ERRCODE = '22023';
  END IF;
  IF p_message IS NULL OR char_length(btrim(p_message)) < 1 OR char_length(p_message) > 2000 THEN
    RAISE EXCEPTION 'invalid_message_length' USING ERRCODE = '23514';
  END IF;
  -- Runaway-script guard, same spirit as the other throttles.
  SELECT count(*) INTO v_recent FROM public.feedback f
   WHERE f.user_id = auth.uid() AND f.created_at > now() - interval '1 hour';
  IF v_recent >= 10 THEN
    RAISE EXCEPTION 'rate_limited' USING ERRCODE = '23514';
  END IF;

  INSERT INTO public.feedback (user_id, category, message, app_build, platform)
  VALUES (auth.uid(), p_category, btrim(p_message), left(p_app_build, 40), left(p_platform, 40))
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$function$;
REVOKE ALL ON FUNCTION public.submit_feedback(text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_feedback(text, text, text, text) TO authenticated;
COMMENT ON TABLE public.feedback IS 'In-app feedback (plan A34). Written only through submit_feedback(); read by admins (settings.manage) and from the dashboard. Move status by hand: new -> seen -> done.';

NOTIFY pgrst, 'reload schema';
