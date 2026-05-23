# Phase 12 — Deferred Work

Tracks intentional gaps and human-gated verifications for the Phase 12
Listing Approval Workflow spec. Per `project_deferred_work.md`, an item here
means the spec is NOT fully shipped until either the item is closed or
explicitly downgraded to forward-state for a later phase.

## Human-Gated Verifications (Phase 2)

- [ ] **T012** — Smoke-verify Phase 10 `submit_listing` still attributes
      correctly under the amended trigger.

      A worktree agent cannot operate the emulator. Manual on Infinix Note 8:

      1. Sign in as a publisher on the Infinix Note 8 emulator.
      2. Submit a fresh draft via the existing Phase 10 listing form.
      3. Run via Supabase MCP `execute_sql`:
         ```sql
         SELECT changed_by
         FROM public.listing_status_history
         WHERE listing_id = '<new id>' AND new_status = 'pending_review';
         ```
      4. Expect a non-NULL UUID matching the publisher's `auth.users.id`.

      **Why this matters**: verifies the FR-024 amendment's
      `coalesce(...session var..., auth.uid())` fallback works for direct-JWT
      callers — `submit_listing` runs as the publisher under their own JWT
      with the session variable UNSET, so `auth.uid()` must populate
      `changed_by`. A NULL `changed_by` would indicate the COALESCE order is
      wrong or the auth.uid() resolution broke.

      **Blocks**: SC-030 (correct admin UID in `changed_by` + `actor_user_id`).
      Do not declare SC-030 closed until this verification is recorded.
