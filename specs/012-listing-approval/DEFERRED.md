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

## Human-Gated Verifications (Phase 3)

- [ ] **T019** — Smoke-test `approve_listing` happy path.

      The Phase 3 worktree agent deployed the Edge Function via Supabase MCP
      but cannot hand-craft an admin JWT. Manual verification:

      1. Obtain a valid admin JWT (sign in via the AlNujom app as a user
         holding `listings.approve`, then read the access token from the
         Supabase session — e.g. via the Flutter DevTools Network tab or
         `Supabase.instance.client.auth.currentSession?.accessToken`).
      2. Have a `pending_review` listing's UUID handy (create one via the
         Phase 10 publisher form on the Infinix Note 8 if needed).
      3. Run:
         ```bash
         curl -X POST "$SUPABASE_URL/functions/v1/approve_listing" \
              -H "Authorization: Bearer <admin JWT>" \
              -H "Content-Type: application/json" \
              -d '{"listing_id":"<the pending_review listing id>"}'
         ```
      4. Expect HTTP 200 with body
         `{"status":"approved","published_at":"<ISO>","expires_at":null}`.
      5. Retrieve the Edge Function logs via Supabase MCP
         `get_logs(service="edge-function")` and capture the
         `duration_ms` for the SC-029 latency baseline (target: ≤ 2000ms p95
         across ≥ 10 invocations).

      **Blocks**: SC-029 baseline (formal p95 latency probe runs in Phase 9
      / T101 once the UI path has produced ≥ 10 real invocations).

- [ ] **T044** — Manual UI verification of the US1 approve flow.

      The agent cannot operate the Pixel 8 Pro emulator or hold an admin
      session. Manual recipe on Pixel 8 Pro emulator:

      **Pre-flight**: grep `lib/core/routing/app_router.dart` for Phase 10's
      existing publisher-edit route path; confirm it is
      `/publisher/listings/:id/edit` (matches the value Phase 4's T058
      Resubmit button will deep-link to). If the actual route differs,
      update T058's `context.push(...)` AND the moderation-history contract's
      deep-link string before proceeding.

      **Verification** (`flutter run -d <pixel 8 pro emulator>
      --dart-define-from-file=.env.json` per `project_dart_defines.md`):

      1. Sign in as an admin holding `listings.approve`.
      2. From the home screen, navigate to Admin → confirm the new
         "Pending review" tile renders (gated by `listings.approve` OR
         `listings.reject` per T041).
      3. Tap the Pending review tile → confirm the queue page loads ≥ 1
         pending listing oldest-first.
      4. Tap a card → confirm the preview renders gallery + price +
         location + amenities + description at full fidelity.
      5. Tap Approve → confirm the dialog appears → tap Approve.
      6. Confirm the success snackbar shows and the page pops back to the
         queue.
      7. Confirm the approved listing no longer appears in the queue (the
         status guard removed it from the `pending_review` set).
      8. From an anonymous Supabase client (e.g. `curl` with the anon key,
         no `Authorization` header), confirm
         `GET /rest/v1/listings?id=eq.<that id>&select=status,published_at,expires_at`
         returns one row with `status="approved"`, `published_at` non-null,
         `expires_at=null` (SC-002 + SC-023).

      **Closes**: SC-001 (2-min admin journey timing), SC-003 (approve
      writes correct rows — paired with T070 SQL check), SC-009 (media
      anonymous-readable on approve — paired with T067), SC-011 (preview
      full-fidelity), SC-026 partial (route guard — paired with T103).
