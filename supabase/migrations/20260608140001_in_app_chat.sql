-- Wave G1 (growth) — in-app chat between a buyer and a listing's publisher.

CREATE TABLE IF NOT EXISTS public.conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id uuid NOT NULL REFERENCES public.listings(id) ON DELETE CASCADE,
  buyer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  publisher_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  last_message_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT conversations_no_self CHECK (buyer_user_id <> publisher_user_id),
  CONSTRAINT conversations_unique UNIQUE (listing_id, buyer_user_id)
);
CREATE INDEX IF NOT EXISTS idx_conversations_buyer ON public.conversations (buyer_user_id, last_message_at DESC);
CREATE INDEX IF NOT EXISTS idx_conversations_publisher ON public.conversations (publisher_user_id, last_message_at DESC);

CREATE TABLE IF NOT EXISTS public.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 2000),
  created_at timestamptz NOT NULL DEFAULT now(),
  read_at timestamptz
);
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON public.messages (conversation_id, created_at);
ALTER TABLE public.messages REPLICA IDENTITY FULL;

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY conversations_select_member ON public.conversations FOR SELECT TO authenticated
  USING (auth.uid() IN (buyer_user_id, publisher_user_id));
CREATE POLICY conversations_insert_buyer ON public.conversations FOR INSERT TO authenticated
  WITH CHECK (buyer_user_id = auth.uid() AND buyer_user_id <> publisher_user_id);

CREATE POLICY messages_select_member ON public.messages FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.conversations c
                 WHERE c.id = conversation_id AND auth.uid() IN (c.buyer_user_id, c.publisher_user_id)));
CREATE POLICY messages_insert_member ON public.messages FOR INSERT TO authenticated
  WITH CHECK (sender_user_id = auth.uid()
              AND EXISTS (SELECT 1 FROM public.conversations c
                          WHERE c.id = conversation_id AND auth.uid() IN (c.buyer_user_id, c.publisher_user_id)));
CREATE POLICY messages_update_member ON public.messages FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.conversations c
                 WHERE c.id = conversation_id AND auth.uid() IN (c.buyer_user_id, c.publisher_user_id)));

GRANT SELECT, INSERT ON public.conversations TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.messages TO authenticated;

CREATE OR REPLACE FUNCTION public.bump_conversation_last_message()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.conversations SET last_message_at = NEW.created_at WHERE id = NEW.conversation_id;
  RETURN NEW;
END; $$;
CREATE TRIGGER trg_messages_bump_conversation
AFTER INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.bump_conversation_last_message();

CREATE OR REPLACE FUNCTION public.get_or_create_conversation(p_listing_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_publisher uuid;
  v_buyer uuid := auth.uid();
  v_conv uuid;
BEGIN
  IF v_buyer IS NULL THEN RAISE EXCEPTION 'authentication required' USING errcode = '42501'; END IF;
  SELECT publisher_user_id INTO v_publisher FROM public.listings WHERE id = p_listing_id;
  IF v_publisher IS NULL THEN RAISE EXCEPTION 'listing not found' USING errcode = 'P0002'; END IF;
  IF v_publisher = v_buyer THEN RAISE EXCEPTION 'cannot message your own listing' USING errcode = '22023'; END IF;
  INSERT INTO public.conversations (listing_id, buyer_user_id, publisher_user_id)
  VALUES (p_listing_id, v_buyer, v_publisher)
  ON CONFLICT (listing_id, buyer_user_id) DO UPDATE SET listing_id = EXCLUDED.listing_id
  RETURNING id INTO v_conv;
  RETURN v_conv;
END; $$;

REVOKE ALL ON FUNCTION public.get_or_create_conversation(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_or_create_conversation(uuid) TO authenticated;

ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
