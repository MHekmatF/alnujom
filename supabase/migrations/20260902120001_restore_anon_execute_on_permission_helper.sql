-- Guests could not read the agencies directory.
--
-- public.v_agencies is a SECURITY DEFINER view, so its WHERE clause is the only
-- visibility gate — and that clause calls current_user_has_permission(). Function
-- EXECUTE is checked against the CALLING role even inside a definer view, and
-- `anon` held no EXECUTE on that helper, so every anonymous read of the view
-- failed outright:
--
--     42501: permission denied for function current_user_has_permission
--
-- The view is granted to anon and the agencies table carries a dedicated
-- function-free anon policy, so guest access was clearly intended; the helper's
-- missing grant is what broke it. Same shape as the guest-map defect fixed in
-- 20260901120001: a security pass revoked something a public read path needed.
--
-- Granting it back is safe. The helper is STABLE SECURITY DEFINER and answers
-- only "does the CURRENT user hold this permission", keyed on auth.uid(). For an
-- anonymous caller auth.uid() is NULL, the EXISTS is false, and it returns FALSE.
-- It accepts no user identifier and can reveal nothing about anyone else — which
-- is why the July security audit explicitly left the boolean RLS helpers alone,
-- noting that revoking them "risks 42501". This restores that intent.
--
-- Applied and verified live 2026-09-02: before, anon reading v_agencies raised
-- 42501; after, it returns the approved agencies. Every anon- and
-- authenticated-readable table and view in public was then probed as that role —
-- all read cleanly.
--
-- Idempotent.

GRANT EXECUTE ON FUNCTION public.current_user_has_permission(text) TO anon;

COMMENT ON FUNCTION public.current_user_has_permission(text) IS
  'Boolean RLS/view helper: does the CURRENT caller hold this permission key? '
  'Returns FALSE for anonymous callers (auth.uid() IS NULL) and reveals nothing '
  'about other users. EXECUTE is granted to anon on purpose — v_agencies is a '
  'SECURITY DEFINER view whose predicate calls this, and function EXECUTE is '
  'checked against the calling role, so revoking it breaks the public agencies '
  'directory with 42501.';
