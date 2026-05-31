-- Phase 19 (spec/019-agencies) — Sub-Phase C, Migration 5
-- RLS SELECT policies for the three agency tables + name-unique-among-approved index
-- (data-model §1.5). This is the load-bearing reader/writer matrix (Principle III).
--
-- Reader/writer matrix (data-model §1.14):
--
--   | Actor                        | agencies SELECT          | agency_members SELECT     | agency_verification_requests SELECT | any-table write |
--   |------------------------------|--------------------------|---------------------------|--------------------------------------|-----------------|
--   | Anonymous                    | ✅ status='approved' only | ❌                        | ❌                                   | ❌              |
--   | Authenticated non-member     | ✅ approved only          | ✅ own invitation row only | ❌                                   | ❌ (RPC only)   |
--   | Owner / active member        | ✅ own agency (any status) | ✅ own agency roster       | agency-admins ✅ / agents ❌          | ❌ (RPC only)   |
--   | agencies.view holder         | ✅ ALL                    | ✅ ALL                    | ✅ ALL                               | ❌ (svc RPC)    |
--   | service_role (Edge Fn)       | bypasses RLS              | bypasses RLS              | bypasses RLS                         | via internal RPC|
--
-- The membership predicates is_agency_member / is_agency_admin (Migration …002)
-- are SECURITY DEFINER so they avoid the self-referential-RLS recursion an inline
-- EXISTS on agency_members would hit. No client write path on any table: creation
-- via create_agency / member RPCs / submit_agency_verification (Migration …008);
-- transitions/decisions via moderate_agency_internal (Migration …010).

-- ─── public.agencies ───
-- SELECT: public(approved) OR owner OR active member OR agencies.view.
CREATE POLICY agencies_select_authenticated ON public.agencies
  FOR SELECT TO authenticated
  USING (
    status = 'approved'
    OR owner_user_id = auth.uid()
    OR public.is_agency_member(id)
    OR public.current_user_has_permission('agencies.view')
  );
-- Anonymous sees only the approved public directory (FR-032).
CREATE POLICY agencies_select_anon ON public.agencies
  FOR SELECT TO anon
  USING (status = 'approved');
REVOKE INSERT, UPDATE, DELETE ON public.agencies FROM authenticated, anon;

-- ─── public.agency_members ───
-- SELECT: own row (an invitee sees their own pending row) OR same-agency active
-- member OR agencies.view. No anon policy.
CREATE POLICY agency_members_select ON public.agency_members
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_agency_member(agency_id)
    OR public.current_user_has_permission('agencies.view')
  );
REVOKE INSERT, UPDATE, DELETE ON public.agency_members FROM authenticated, anon;

-- ─── public.agency_verification_requests ───
-- SELECT: agency-admin of that agency (agents excluded) OR agencies.view. No anon policy.
CREATE POLICY agency_verification_select ON public.agency_verification_requests
  FOR SELECT TO authenticated
  USING (
    public.is_agency_admin(agency_id)
    OR public.current_user_has_permission('agencies.view')
  );
REVOKE INSERT, UPDATE, DELETE ON public.agency_verification_requests FROM authenticated, anon;

-- Name unique among APPROVED agencies only (Q2-clarify / R-145). Duplicate
-- pending names may coexist; the approve action's EXISTS pre-check + this index
-- are the two-layer backstop (a racing second approval of the same name gets 23505).
CREATE UNIQUE INDEX IF NOT EXISTS ux_agencies_name_approved
  ON public.agencies (lower(name)) WHERE status = 'approved';
