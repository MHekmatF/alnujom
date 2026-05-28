-- Phase 17 (spec/017-favorites) — Migration 1/5
-- public.favorites — a user's private saved listings.
--
-- Privacy: self-only. A row belongs to exactly one user and is readable /
-- deletable only by that user (policies in Migration 2). NO publisher, NO
-- admin, NO anonymous reader path (FR-017..FR-019). There is no
-- favorites.view_all permission anywhere in the system.
--
-- Write model:
--   - INSERT: only via public.add_favorite(uuid) SECURITY DEFINER RPC
--     (Migration 4). No direct client INSERT grant — so a client cannot
--     create a favorite that bypasses the co-transactional favorite_added
--     lead event (FR-011).
--   - DELETE: direct, via the favorites_delete_self self-only policy (Q5=A).
--   - UPDATE: none — favorites are insert/delete-only.
--
-- Keys / FKs:
--   - PRIMARY KEY (user_id, listing_id): a user cannot double-save (FR-007);
--     also the ON CONFLICT target for the idempotent RPC insert.
--   - user_id -> auth.users ON DELETE CASCADE: deleting an account removes
--     its favorites (user_preferences precedent, 20260506120003).
--   - listing_id -> listings ON DELETE RESTRICT (Q4=C): listings soft-delete
--     via status='deleted', so RESTRICT never fires normally; it defends
--     against accidental hard-deletes and preserves the favorite for the
--     "no longer available" FavoritesPage indicator (FR-025).

CREATE TABLE IF NOT EXISTS public.favorites (
  user_id     UUID        NOT NULL REFERENCES auth.users(id)     ON DELETE CASCADE,
  listing_id  UUID        NOT NULL REFERENCES public.listings(id) ON DELETE RESTRICT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, listing_id)
);

ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;

-- FavoritesPage newest-first read (FR-013 / FR-021 / R-117).
CREATE INDEX IF NOT EXISTS idx_favorites_user_created
  ON public.favorites (user_id, created_at DESC);
