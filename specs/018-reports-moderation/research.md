# Phase 0 Research — Reports & Moderation (R-119..R-134)

**Feature**: `specs/018-reports-moderation/` | **Date**: 2026-05-29

All NEEDS-CLARIFICATION items from the Technical Context are resolved below. Each decision names the predecessor artifact it builds on so the plan's dependency graph stays auditable. The six product-shaping clarifications (Q1–Q6) live in `spec.md`'s Clarifications section; this file records the *plan-time* (R-) decisions, including the one the spec deferred (the `reporter_user_id` ON DELETE behavior → R-131).

---

## R-119 — Zero new dependencies

**Decision**: Add NO new pubspec package and NO new Postgres extension. Reports & moderation use the inherited Flutter/BLoC/`go_router`/`get_it`/`injectable`/`supabase_flutter` stack, two in-house Postgres tables, three PL/pgSQL functions, one view, and one Deno Edge Function reusing the `@supabase/supabase-js` import already present in `supabase/functions/approve_listing/index.ts`.

**Rationale**: FR-031 + Constitution XI. There is no moderation/abuse-detection package the MVP needs; the queue, sheet, and resolve flow are plain Material widgets.

**Alternatives rejected**: a third-party "report/flag" widget package (none Android-clean + Syria-safe + worth a dependency for a bottom sheet).

---

## R-120 — Two tables: `reports` + `moderation_actions`

**Decision**: Create `public.reports` and `public.moderation_actions` as separate tables per IMPLEMENTATION_PLAN §6.2, with the spec's additions: the `reviewing_by` / `reviewing_started_at` soft-claim columns (Q4=B) and the `resolved_by` / `resolved_at` / `resolution` columns on `reports`; the generic `target_type` / `target_id` + `before_state` / `after_state` shape on `moderation_actions`.

**Rationale**: §6.2 already specifies both tables. Keeping the moderation log a separate append-only table (rather than folding the action into `reports`) lets the log survive report deletion (R-131) and matches the §6.4 "moderation_actions … Write: System triggers only / Read: Admins" posture distinct from the reporter-readable `reports`.

**Alternatives rejected**: a single `reports` table carrying the action inline (loses the append-only audit guarantee and the admin-only read isolation for the action log).

---

## R-121 — Submit posture: `submit_report` SECURITY DEFINER RPC

**Decision**: Report creation flows through a `public.submit_report(p_listing_id uuid, p_reason text, p_note text)` SECURITY DEFINER RPC granted to `authenticated` only, mirroring the Phase 16 `record_lead_event` (`20260527120010`) and Phase 17 `add_favorite` (`20260529120004`) posture: `auth_required` check → approved-listing validation → insert with `reporter_user_id := auth.uid()`.

**Rationale**: FR-010. A SECURITY DEFINER RPC with no client INSERT grant on `public.reports` makes `reporter_user_id` un-forgeable (it is always `auth.uid()`), and centralizes the open-report dedup + approved-listing gate server-side.

**Alternatives rejected**: a direct client INSERT with a WITH-CHECK policy (would still need the dedup + approved gate in a trigger and exposes the insert surface; the RPC is the established pattern for the other two engagement writes).

---

## R-122 — Open-report dedup mechanism

**Decision**: Enforce "at most one OPEN report per (reporter, listing)" with BOTH a partial unique index `ux_reports_open_per_reporter_listing ON public.reports (reporter_user_id, listing_id) WHERE status IN ('new','reviewing')` AND an `EXISTS` guard inside `submit_report` that raises `already_reported` (ERRCODE `23505`).

**Rationale**: FR-004. The `EXISTS` guard gives a clean structured error for the normal path; the partial unique index is the race-safe backstop (two rapid submits cannot both commit). A terminal report (`resolved`/`dismissed`) is outside the index predicate, so re-reporting after resolution is allowed (FR spec US1 AS-4).

**Alternatives rejected**: a full unique index on `(reporter_user_id, listing_id)` (would block re-reporting a recurrence after resolution — contradicts US1 AS-4); RPC-only check with no index (a concurrent double-submit could create two open rows).

---

## R-123 — Resolve posture: Edge Function + service-role `_internal` RPC

**Decision**: Resolution mirrors Phase 12 exactly — a `resolve_report` Edge Function (`supabase/functions/resolve_report/index.ts`) JWT-gates on `current_user_has_permission('reports.manage')` then invokes a service-role-only `public.resolve_report_internal(...)` SECURITY DEFINER RPC.

**Rationale**: FR-012 + Principle III "checks at both ends" + Principle VII. The Phase 12 `approve_listing`/`reject_listing` Edge Functions (`supabase/functions/approve_listing/index.ts`) established this exact pattern for permission-gated admin mutations; `resolve_report` is the same shape. The service-role-only grant means even a bypassed front-end cannot resolve a report (SC-010).

**Alternatives rejected**: a pure client RPC self-gating on `current_user_has_permission` (works, but loses the second enforcement layer the constitution mandates for sensitive admin mutations, and diverges from the Phase 12 precedent the reviewer expects); resolving via direct client UPDATE under an admin RLS policy (cannot atomically write the moderation action + listing transition + audit, and exposes the UPDATE surface).

---

## R-124 — Moderation action → listing status mapping (Q1=A)

**Decision**: `dismiss` = listing unchanged (report → `dismissed`); `hide` → listing `paused`; `mark_duplicate` → listing `rejected` with `app.current_rejection_reason='duplicate'`; `delete` → listing `deleted`. No new value is added to the Phase 10 `listings.status` CHECK; the transitions reuse the Phase 12 `set_config('app.current_user_id'/'app.current_rejection_reason')` machinery so `listing_status_transition_trigger_fn` + `listings_audit_trigger_fn` fire.

**Rationale**: Q1=A + FR-014. Public/anonymous read is gated to `status='approved'`, so any non-approved transition removes the listing from the home feed/search/map with no extra code (FR-015). Reusing `rejected` for duplicates surfaces the outcome to the publisher exactly as a Phase 12 rejection does, with a "duplicate" reason in `listing_status_history`.

**Integration check (load-bearing)**: `resolve_report_internal` performs `approved→{paused,rejected,deleted}` transitions. The existing `listing_status_transition_trigger_fn` (`supabase/migrations/20260519120006_create_listing_status_history.sql`) MUST permit these admin-driven transitions. Sub-Phase E's FIRST task is to read that migration and confirm the guard allows them; if it rejects an `approved→paused` (etc.) transition, E amends the guard in `20260530120007` (adding the moderation transitions) — this is the only place Phase 18 may touch a Phase 10 trigger, and it is called out so the executor verifies before writing the RPC body.

**Alternatives rejected**: a dedicated `hidden` listing status (Q1 Option B — unnecessary schema churn + public-read-filter change for v1); dismiss+delete-only (Q1 Option C — narrower than the plan's stated four-action set).

---

## R-125 — Sibling auto-resolve (Q5=A)

**Decision**: Inside `resolve_report_internal`, when `p_action <> 'dismiss'`, auto-resolve every OTHER open report on the same listing (`UPDATE … WHERE listing_id = v_listing_id AND id <> p_report_id AND status IN ('new','reviewing')`) to `resolved`, and insert one `moderation_actions` row per auto-resolved sibling referencing the triggering resolution. `dismiss` affects only its own report.

**Rationale**: Q5=A + FR-016. Once a listing is hidden/duplicated/deleted, the other reports about it are moot; auto-resolving them keeps the queue honest and saves repetitive admin work, while every report keeps an auditable disposition. All in the one transaction so the queue is never transiently inconsistent.

**Alternatives rejected**: leave siblings open (queue clutter); auto-resolve only on `delete` (a `hide`/`mark_duplicate` equally moots the others).

---

## R-126 — Reviewing claim (Q4=B advisory soft lock)

**Decision**: `public.start_report_review(p_report_id uuid)` SECURITY DEFINER RPC, granted to `authenticated`, self-gates on `current_user_has_permission('reports.manage')`, and `UPDATE public.reports SET status='reviewing', reviewing_by = auth.uid(), reviewing_started_at = now() WHERE id = p_report_id AND status='new'`. The lock is advisory: if a report is already `reviewing` under another admin, the claim no-ops and the UI surfaces the current reviewer but still allows take-over/resolve.

**Rationale**: Q4=B + FR-036. A lightweight RPC (no listing change, no GUC-driven trigger needed) is sufficient; resolution remains valid from either `new` or `reviewing`, so the claim is optional signposting.

**Alternatives rejected**: a hard lock blocking other admins (Q4 Option B's strict reading — rejected per the user's "can be disabled / overridable" steer); auto-claim on open (Q4 Option A — ambiguous ownership with multiple admins); dropping `reviewing` (Q4 Option C — loses contention-avoidance).

---

## R-127 — Reporter visibility surfaces (Q3=Both)

**Decision**: Ship BOTH a `/reports` "My Reports" page (reached from a Profile tile, route guarded like `/favorites`) and a reporter-only inline status banner on the Phase 13 listing details page. Both read `public.v_reports` and are self-scoped by the base-table RLS.

**Rationale**: Q3=Both + FR-022/FR-023. The page is the consolidated review surface; the banner gives in-context feedback when the reporter revisits the listing.

**Alternatives rejected**: page-only or banner-only (Q3 Options A/B — the user chose both).

---

## R-128 — `v_reports` view shape

**Decision** (amended after device QA — migration `20260530120010`): `public.v_reports` is a `SECURITY DEFINER` view joining `reports` → `listings` (+ main-image LATERAL + governorate/city display-name joins) projecting the queue/My-Reports card fields plus `listing_status`, with an **explicit self-scoping WHERE** `r.reporter_user_id = auth.uid() OR public.current_user_has_permission('reports.manage')`. It does NOT filter on `l.status`. One view serves both the reporter ("My Reports") and the admin (queue) with the WHERE enforcing visibility.

**Rationale**: FR-024/FR-025/FR-026 + R-129. The view was ORIGINALLY `SECURITY INVOKER` (the Phase 16 `20260527120013` precedent), but device QA proved that under invoker the INNER JOIN to `listings` re-applies the listings RLS (public read only for `approved`), so a reporter LOST their own report the moment the reported listing left `approved` (hide/mark_duplicate/delete) — the exact post-moderation case SC-007/SC-008 require. A definer view bypasses the listings RLS for the display join; `auth.uid()` / `current_user_has_permission` still resolve to the caller, so the explicit WHERE reproduces the reader matrix without leak.

**Alternatives rejected**: SECURITY INVOKER (the original — drops reporters' reports on non-approved listings); LEFT JOIN under invoker (keeps the report row but nulls `listing_status`/`title`, losing the very listing context the reporter wants); a definer helper function for the listing fields (keeps the view invoker but exposes any listing's title/status to any authenticated caller via the RPC — a wider leak surface). **Trade-off accepted**: the definer view is flagged by the `security_definer_view` advisor, consistent with the existing `v_listings_public` / `v_lead_events_*` definer views in this repo.

---

## R-129 — RLS posture

**Decision**: `reports` SELECT = `USING (reporter_user_id = auth.uid() OR public.current_user_has_permission('reports.manage'))`; NO client INSERT/UPDATE/DELETE (REVOKE-d). `moderation_actions` SELECT = `USING (public.current_user_has_permission('reports.manage'))`; NO client write. Neither table has an `anon` policy.

**Rationale**: FR-025/FR-026/FR-027 + §6.4. Creation is RPC-only; resolution/claim is privileged-path-only; the moderation log is admin-read-only. This is the IMPLEMENTATION_PLAN §6.4 matrix verbatim.

**Alternatives rejected**: a publisher-readable report path (FR-028 forbids it); an admin UPDATE policy enabling direct resolution (loses atomicity + the dual-layer gate).

---

## R-130 — Submit listing-status gate (Q6=A)

**Decision**: `submit_report` requires the target listing exist AND be `status='approved'`, rejecting otherwise with a structured error.

**Rationale**: Q6=A + FR-010. Consistent with `record_lead_event`/`add_favorite`; a normal user can only surface `approved` listings. Does not block `already_sold_or_rented` (filed while the listing is still shown as `approved`).

**Alternatives rejected**: existence-only (Q6 Option B — inconsistent with the other two engagement RPCs; accepts crafted calls against non-public listings).

---

## R-131 — FK delete behaviors (the spec's deferred item)

**Decision**:
- `reports.reporter_user_id` — `NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE`.
- `reports.resolved_by`, `reports.reviewing_by` — `NULL REFERENCES auth.users(id) ON DELETE SET NULL`.
- `reports.listing_id` — `NOT NULL REFERENCES public.listings(id) ON DELETE RESTRICT`.
- `moderation_actions.report_id` — `NULL REFERENCES public.reports(id) ON DELETE SET NULL`.
- `moderation_actions.performed_by` — `NULL REFERENCES auth.users(id) ON DELETE SET NULL`.
- `moderation_actions.target_id` — plain `uuid` column, NO FK.

**Rationale**: Resolves the one item `spec.md` Assumptions left plan-time. Deleting a reporter CASCADE-removes their reports (no orphaned reporter identity, keeps `reporter_user_id` NOT NULL per FR-008); the paired `moderation_actions.report_id` then SET-NULLs so the **moderation log survives** (target_id/action/before/after intact). Admin deletion SET-NULLs `resolved_by`/`reviewing_by`/`performed_by` so neither the report nor the log vanishes. `target_id` is a plain column (not an FK) so the append-only audit is decoupled from listing lifecycle. `listing_id` RESTRICT matches the Phase 16/17 precedent (listings soft-delete, so RESTRICT never fires in normal operation).

**Alternatives rejected**: `reporter_user_id` nullable + `ON DELETE SET NULL` (conflicts with FR-008 NOT NULL); `moderation_actions.report_id` CASCADE (would delete the moderation log when the reporter is deleted — loses the audit trail).

---

## R-132 — Report sheet UI

**Decision**: A modal bottom sheet (`showModalBottomSheet`) with a `DropdownButtonFormField<ReportReason>` over the eight reasons, an optional multiline note `TextField` (≤1000 chars, matching the DB CHECK), and submit/cancel buttons — all reading Phase 2 tokens. The Report CTA's anonymous branch (signed-out tap) shows the localized `report_sign_in_prompt` snackbar + `context.push(AppRoutes.login)` BEFORE opening the sheet, mirroring the Phase 17 Favorite-CTA `_onFavoriteTap` branch in `per_listing_action_block.dart` (lines 69–80).

**Rationale**: FR-002 + Q2=A + FR-006/FR-007. A bottom sheet is the idiomatic Material pattern for a short reason+note form; the anonymous-prompt-before-sheet keeps a signed-out tap side-effect-free.

**Alternatives rejected**: a full-page report form (heavier than needed); a dialog (cramped for the note field on small Syrian devices).

---

## R-133 — Migration timestamps

**Decision**: Phase 18 migrations are `20260530120001`–`20260530120008` (next-day prefix after Phase 17's last applied migration `20260529120007`).

**Rationale**: The repo orders migrations by timestamp filename; a strictly-later prefix keeps `supabase db reset` deterministic and avoids collision with Phase 17's `20260529` series (which shipped seven migrations `…001`–`…007`, two more than its plan originally listed).

**Alternatives rejected**: continuing the `20260529120008+` series (works, but a fresh day prefix reads more clearly as a distinct phase).

---

## R-134 — Reports resolution audit

**Decision**: `CREATE TRIGGER trg_reports_audit_resolution AFTER UPDATE OF status ON public.reports … WHEN (NEW.status IN ('resolved','dismissed') AND OLD.status IS DISTINCT FROM NEW.status) EXECUTE FUNCTION log_audit('report.resolved', 'status,resolution,resolved_by', 'id')`, reusing the Phase 4 `log_audit()` trigger function (`20260506120004`). Actor attribution comes from the `app.current_user_id` GUC set by `resolve_report_internal`; the listing transitions additionally fire the existing Phase 10/12 listing audit triggers.

**Rationale**: §6.4 ("reports … Audit-logged: Resolution") + Principle VII. Reusing `log_audit()` (the same trigger the `profiles` status-change audit uses) avoids a parallel audit mechanism (FR-035) and auto-captures before/after + actor.

**Alternatives rejected**: an explicit `INSERT INTO audit_logs` inside `resolve_report_internal` (works, but duplicates logic the trigger function already provides and diverges from the established trigger-based audit convention).
