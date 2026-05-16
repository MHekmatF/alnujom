-- Phase 7: Advisor hardening for SECURITY DEFINER RPCs.
-- Source: specs/007-super-admin-roles/contracts/*-rpc.md
-- R-12 pattern carry-forward: revoke PUBLIC/anon execute and grant authenticated.

REVOKE EXECUTE ON FUNCTION public.mutate_role(TEXT, UUID, TEXT, JSONB, TEXT, TEXT[], TIMESTAMPTZ) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.assign_role_to_user(UUID, UUID, TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.revoke_role_from_user(UUID, UUID) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.mutate_role(TEXT, UUID, TEXT, JSONB, TEXT, TEXT[], TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_role_to_user(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_role_from_user(UUID, UUID) TO authenticated;
