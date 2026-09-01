-- 20260706172115_035_admin_set_listing_verification_rpc
--
-- RECONSTRUCTED 2026-07-17 from the live database (commit-only — already applied
-- via Supabase MCP on 2026-07-06 as tracker version 20260706172115). DO NOT
-- re-apply through MCP. Body below is the current live `pg_get_functiondef` output
-- (DB-1 fix). The follow-up migration 20260706172906 revokes anon EXECUTE.
--
-- Phase 035 Stage 3 — admin toggles a listing's field-verified status. Authorization
-- is enforced server-side via current_user_has_permission('listings.approve'); the
-- caller's params are never trusted for the permission decision.
create or replace function public.admin_set_listing_verification(
  p_listing_id uuid,
  p_verified   boolean
)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  if not public.current_user_has_permission('listings.approve') then
    raise exception using errcode = '42501', message = 'permission denied';
  end if;
  update public.listings
     set verification_status = case when p_verified then 'verified' else 'none' end,
         verified_at         = case when p_verified then now() else null end,
         updated_at          = now()
   where id = p_listing_id;
end;
$function$;
