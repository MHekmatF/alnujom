-- Phase 17 — Migration 2/5 — self-only RLS (FR-017, FR-018, Q5=A).

-- SELECT: a user reads only their own favorites.
CREATE POLICY favorites_select_self
  ON public.favorites
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- DELETE: a user removes only their own favorites (the client's un-favorite
-- path per Q5=A + FR-012). Removal emits NO lead event.
CREATE POLICY favorites_delete_self
  ON public.favorites
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- No INSERT policy and no INSERT grant: row creation is exclusively via the
-- add_favorite SECURITY DEFINER RPC (Migration 4). This makes it impossible
-- for a client to create a favorite that bypasses the favorite_added event
-- (FR-011 + FR-017). No UPDATE policy: favorites are insert/delete-only.
REVOKE INSERT, UPDATE ON public.favorites FROM authenticated, anon;

-- Anonymous reads are denied entirely (no policy TO anon; FR-018).
