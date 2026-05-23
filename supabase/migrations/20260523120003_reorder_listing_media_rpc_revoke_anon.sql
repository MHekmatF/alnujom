-- Phase 11 follow-up — advisor hardening: revoke EXECUTE on the new
-- reorder_listing_media RPC from the anon role. The function is meant for
-- authenticated publishers/admins only; caller-authorization checks inside
-- the body already deny anonymous callers but the advisor flags the public
-- callability anyway. Mirror the Phase 7/9 advisor-hardening precedent.

REVOKE EXECUTE ON FUNCTION public.reorder_listing_media(UUID, UUID[]) FROM anon;
