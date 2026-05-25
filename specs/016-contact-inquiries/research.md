# Phase 16 — Research Decisions

> **Continues the project-wide research-decision numbering** from Phase 15 (R-85..R-96). Phase 16 owns R-97..R-108.

Each entry follows the same shape: Decision (the locked answer), Rationale (why this and not the alternatives), Alternatives considered (what was rejected and why).

---

## R-97 — URL launcher package

**Decision**: `url_launcher: ^6.3.0` from the Flutter team's official packages, added to `pubspec.yaml` in Sub-Phase A.

**Rationale**:

- The `tel:` and `https:` URI launches are the only two new external-hand-off requirements Phase 16 introduces (Call → Android system dialer; WhatsApp → `wa.me/` web URL or WhatsApp app). Both are standard URI scheme launches that `url_launcher` handles via a single `launchUrl(Uri)` call.
- `url_launcher` is maintained by the Flutter team itself, has stable Android support since pre-1.0, ships no native iOS-only code paths that would block our Android-only constitution (Principle XI), and has zero Google Play Services dependency — important for Phase 15 R-88's direct-APK distribution rule which Phase 16 inherits.
- The package is widely used in the broader Flutter ecosystem (3000+ pub.dev "Likes", 100k+ stars across reverse-dep projects) so risk of abandonment is minimal.
- Version `^6.3.0` is the current stable major; the 6.x line is API-stable.

**Alternatives considered**:

- `flutter_phone_direct_caller` — calls phones directly without the system dialer intermediate step. Rejected because it would require `CALL_PHONE` permission on Android (intrusive privacy escalation; the user would see "Allow AlNujom to make and manage phone calls?" at install time) and bypasses the user's "confirm before dialing" intent that the system dialer provides naturally. The spec's intent is "intent-to-call, not call-completion" per FR-002 — system dialer hand-off is the right semantic.
- `flutter_open_whatsapp` / `whatsapp_unilink` — niche packages that build `wa.me/` URLs. Rejected because `url_launcher` does the same thing for the `https://` scheme with a stable maintainership story; introducing a one-purpose package for URL string construction is over-investment.
- `android_intent_plus` — for raw Android intents. Rejected as overkill — we don't need custom intent construction; the standard `tel:` and `https:` URIs cover everything.

---

## R-98 — Inquiry form presentation shape

**Decision**: Modal bottom sheet via `showModalBottomSheet(context, isScrollControlled: true, ...)` anchored to the listing details page.

**Rationale**:

- The inquiry form is **secondary to the listing details flow** — the user is mid-browse, sees a listing they like, wants to ask one question, and then expects to return to where they were. A modal sheet preserves the listing details page underneath; a push-route would dismount the listing details state and force a re-load on return.
- The form has exactly 3 fields (name + phone + message). A bottom sheet sized to the typed-content viewport renders comfortably on the Infinix Note 8 (480 dp width) without scroll for the common case.
- `isScrollControlled: true` allows the sheet to grow to full height when the keyboard opens — needed for the message field on a small device. This matches the Phase 13 / Phase 14 modal pattern (filter sheet in `SearchPage`).
- The dismiss gesture (drag down, tap outside, system back) is the universal "cancel" affordance — no extra UI chrome needed.

**Alternatives considered**:

- Full push-route to `/listings/:id/inquire` — Rejected. Higher implementation cost (new route, new BLoC scope, new back-navigation handling), worse UX (full-page swap interrupts the browse flow), and pure overhead for a 3-field form.
- Inline expansion within the listing details page (e.g., the ContactBlock expands to reveal the form) — Rejected. Would require restructuring the listing details page composition, which conflicts with FR-001's preservation rule. Also makes scrolling awkward (the form has variable height).
- AlertDialog — Rejected. AlertDialog is not designed for forms with multiple input fields and a free-form text area on mobile; the layout breaks on small viewports.

---

## R-99 — Transition allowlist enforcement

**Decision**: BEFORE UPDATE trigger on `public.inquiries.status` with a static allowed-pair lookup table embedded in the trigger function body. Invalid transitions raise `EXCEPTION` with SQLSTATE 23514 (CHECK violation).

**Rationale**:

- The transition rules per FR-021a + Q2=B (`new → seen`; `seen → responded`/`closed`; `responded → closed`/`seen`; `closed → seen`/`responded`; `* → spam` for future admin use) MUST be enforced **server-side** per the spec's "not merely hidden in UI" requirement. A client-side check is insufficient because a malicious client could POST any state.
- BEFORE UPDATE triggers are the canonical Postgres mechanism for "validate this row mutation before it commits." They fire under RLS, run inside the same transaction as the UPDATE, and reject with a structured error that the Supabase JS/Dart client surfaces as a `PostgrestException`.
- The static allowed-pair lookup is a small CASE/IN expression (~8 entries); no separate config table is needed. Embedding the allowlist in the function keeps it co-located with the rest of the transition logic and version-controlled in the migration file.
- SQLSTATE 23514 maps naturally to the Dart `Failure.transitionInvalid` shape so the Flutter client can localize the error.

**Alternatives considered**:

- CHECK constraint on the `status` column itself — Rejected. CHECK constraints in Postgres apply to the new row's value in isolation; they cannot consult the OLD row's value to validate a transition. They'd permit `new → spam` directly bypassing the workflow.
- Application-layer validation only — Rejected per Constitution Principle III ("no application-layer-only security"). The trigger is the load-bearing check; the UI hide is a UX nicety on top of it.
- Stored-procedure transition wrappers (separate function per allowed transition, e.g., `mark_inquiry_seen(uuid)`, `mark_inquiry_responded(uuid)`) — Rejected as more verbose for no benefit; the trigger handles all transitions uniformly.

---

## R-100 — Privileged decrypt path shape

**Decision**: SECURITY DEFINER function `public.decrypt_inquirer_phone(p_inquiry_id uuid) RETURNS text`. Inlined into the `v_inquiries_inbox` view's projection. The function body evaluates the three-tier visibility rule (publisher / signed-in sender / admin with `inquiries.view_all`) on EVERY call and returns NULL for unauthorized callers.

**Rationale**:

- The Phase 5 `vault.decrypt(...)` pattern for `profiles.legal_name` / `profiles.national_id` / `profiles.private_contact_methods` (in `supabase/migrations/20260510120004_profiles_vault_pii_helpers.sql`) is the project's established convention: a SECURITY DEFINER function with the visibility check baked into the body. Phase 16 follows the same pattern for consistency.
- Inlining the function call into the view's projection (`SELECT ..., decrypt_inquirer_phone(i.id) AS inquirer_phone_decrypted FROM inquiries i`) means the data layer reads a single view row and gets the decrypted phone for authorized callers and NULL for unauthorized — the application code is uniform.
- Returning NULL (rather than RAISE EXCEPTION) for unauthorized callers means the inbox row still renders with the "Phone unavailable" placeholder per FR-026 — even in edge cases where the view's RLS lets a row through but the decrypt function's tier check fails (defense-in-depth).
- A separate `v_inquiries_decrypted` view was considered but adds API surface without value; a single view with a per-row decrypt function is simpler.

**Alternatives considered**:

- A separate `v_inquiries_decrypted` view gating with its own RLS predicate, plus the unprefixed view masking the phone — Rejected. Adds two views to the data layer's mental model; the per-call function self-gating is simpler and equally secure.
- Storing the phone as plaintext gated only by RLS — Rejected explicitly per ADR-0001's "defense in depth against backup theft and log exposure" rationale.
- Client-side decryption (encrypt with a key the publisher's app holds locally) — Rejected because (a) the admin tier needs to decrypt cross-publisher data, (b) keys would have to ship with the client, (c) Phase 5's pattern already uses server-side Vault decryption — consistency matters.

---

## R-101 — Unread-count read path

**Decision**: SECURITY DEFINER RPC `public.get_inbox_unread_count() RETURNS integer`. Body: `SELECT COUNT(*) FROM public.inquiries i JOIN public.listings l ON l.id = i.listing_id WHERE l.publisher_user_id = auth.uid() AND i.status = 'new'`. Backed by the `idx_inquiries_listing_status` partial index (`WHERE status IN ('new','seen','responded')`) for cheap execution.

**Rationale**:

- The home AppBar action needs a single integer (the current unread count for the signed-in user). A full-row SELECT would be wasteful (we don't need any inquiry data, just a count).
- A dedicated RPC lets us optimize the query independently from the inbox-listing query (different access pattern: count-only vs paginated row-list).
- The partial index `idx_inquiries_listing_status` includes only the active-funnel statuses (`new`, `seen`, `responded`) which is a tiny fraction of total inquiries in a mature catalog — the count query is index-only.
- Returning a single integer keeps the Dart client trivially simple (`Future<int>` return type from the data layer).

**Alternatives considered**:

- Compute the count client-side from the full inbox SELECT — Rejected. Forces the home AppBar to load the entire inbox at app launch just to count; wasteful bandwidth and rendering cost.
- Subscribe to a Postgres NOTIFY channel for real-time count updates — Rejected. Phase 22 owns Realtime; Phase 16 ships polling on AppLifecycleState.resumed per FR-019a, which is the simpler v1 pattern.
- A view `v_inbox_unread_count` returning a single row — Rejected. Postgres lets views return one row but the syntactic overhead vs an RPC is the same; an RPC is more idiomatic for "scalar return."

---

## R-102 — IP + user-agent capture source

**Decision**: Server-side trusted context. IP via `inet_client_addr()` (built-in Postgres function returning the IP of the connecting client); user-agent via `current_setting('request.headers', true)::jsonb->>'user-agent'` (Supabase's request-headers GUC, set by PostgREST for each request). Both captured inside the `submit_inquiry` and `record_lead_event` SECURITY DEFINER RPC bodies and persisted to `lead_events.metadata` as `{ip: "<v4/v6>", user_agent: "<string>"}`.

**Rationale**:

- The IP/UA capture rule per Q5=B + IMPLEMENTATION_PLAN §6.7 MUST source from the trusted server context — never from client-supplied headers — otherwise a malicious client could spoof the IP and defeat the abuse-investigation use case.
- `inet_client_addr()` is the canonical Postgres function for this; `request.headers` is Supabase's standard pattern (used by Phase 11's `record_lead_event` precursor and by Phase 10's listing-creation audit logging).
- Capturing inside the RPC body (rather than via a separate trigger) keeps the capture atomic with the insert — there's no window where the row exists but the metadata isn't yet populated.

**Alternatives considered**:

- Client passes `ip` and `user_agent` as RPC parameters — Rejected. Spoofable, undermines the abuse-investigation use case.
- Trigger-based capture (BEFORE INSERT trigger reads the same server context) — Rejected. The trigger function and the RPC body would both need the same GUC reads; folding into the RPC body is simpler.
- Capture only the user-agent (no IP) — Rejected. IP is the stronger signal for abuse pattern detection (e.g., one IP firing 50 inquiries across the platform in an hour); UA alone is too generic.

---

## R-103 — Home AppBar inbox action placement

**Decision**: An `IconButton` in the home page's `AppBar.actions:` slot, positioned **between** the existing `LocaleToggleAction` (currently the first action) and the existing sign-in/profile `IconButton` (currently the second action). The new entry becomes the second action; the sign-in/profile icon shifts to third. Visibility-gated: the entry renders `SizedBox.shrink()` when the signed-in user owns zero approved listings (computed by `InquiriesUnreadCubit.state.canShowEntry`). An `UnreadCountBadge` overlay shows the count when > 0.

**Rationale**:

- Phase 15's Q8=B precedent established the convention: high-leverage publisher-facing entries belong in the home shell, not buried in profile sub-pages. The Phase 15 map tile sits in the home body; Phase 16's inbox sits in the home AppBar — different surfaces but the same prominence philosophy.
- The home AppBar is **consistently visible** across every home-feed scroll position, every refresh, every locale toggle. A buyer who is also a publisher checking listings can glance at the badge while browsing.
- AppBar actions are the standard "global verb" pattern in Material design (notifications, search, account). The inbox fits naturally.
- Placing it between `LocaleToggleAction` (i18n affordance) and the sign-in/profile icon (account affordance) groups it visually with the account/personal section while keeping the broader "app-level" verb of locale toggle on the leading side.
- The visibility gate (`canShowEntry`) prevents UI clutter for non-publisher visitors — they see exactly what they saw in Phase 15 (LocaleToggleAction + sign-in icon).

**Alternatives considered**:

- A drawer-based navigation — Rejected. AlNujom has no drawer yet; introducing one for a single new entry would be over-investment and force a UI redesign across all pages.
- A bottom-nav tab — Rejected for the same reason Phase 15 rejected it for the map (the constitution + Phase 15 Q8=B already declined to introduce a bottom-nav shell).
- A tile in the home body next to the Phase 15 map tile — Rejected. Two large tiles in the home body would consume too much above-the-fold real estate; the inbox is a publisher-only affordance (smaller audience) and belongs in the AppBar where it doesn't compete for the buyer's attention.
- The publisher's own profile page as the entry — Rejected per Q6=B explicitly ("Option A: too buried; risks 'missed inquiry' anti-pattern").

---

## R-104 — Inbox pagination

**Decision**: Cursor-based pagination on `(created_at DESC, id DESC)` matching the Phase 13 home-feed cursor convention. Page size 30. The client sends an opaque cursor (the last-seen row's `created_at` + `id`); the data source's `loadInbox(..., String? cursor)` decodes it and adds `WHERE (created_at, id) < ($cursor_created_at, $cursor_id)` to the query.

**Rationale**:

- Phase 13 already established the cursor pattern in `lib/features/home/data/datasources/supabase_listings_datasource.dart`'s home-feed query; reusing the convention reduces cognitive load for future maintainers.
- Cursor pagination is stable under inserts (new inquiries arrive at the top; existing cursor positions remain valid). Offset pagination would skip rows or duplicate them as new inquiries land.
- Page size 30 is a balance between (a) one page covering most publishers' daily inquiry volume in a single fetch, and (b) avoiding over-fetch for the empty-state common case. Matches Phase 13's home-feed page size.
- The compound `(created_at DESC, id DESC)` ordering breaks ties when two inquiries share the exact same `created_at` (rare but possible with rapid-fire submissions); `id` is the unambiguous tiebreaker.

**Alternatives considered**:

- Offset pagination (`LIMIT 30 OFFSET $n`) — Rejected. Unstable under inserts; offset-based queries scan-and-skip which gets slower as the offset grows.
- "Load more" with timestamp-only cursor — Rejected. Ambiguous when two rows share a timestamp.
- Auto-load-on-scroll without explicit "load more" button — Accepted as the UX shape (the BLoC's `MoreLoaded` event fires when the user scrolls past the 80% mark) but the pagination MECHANISM is still cursor-based.

---

## R-105 — Self-contact CTA hide rule

**Decision**: Computed at `ContactCtaCubit` construction time. The cubit takes `publisherUserId` (from the listing) and reads `auth.uid()` (from the existing `AuthBloc` / Supabase session). `isSelfContact = (publisherUserId == auth.uid())`. When true, `ContactBlock` short-circuits to `SizedBox.shrink()` — no Call, no WhatsApp, no Send Inquiry buttons rendered.

**Rationale**:

- FR-001d requires self-contact CTAs to be HIDDEN (not merely disabled) — a publisher seeing their own listing should not be tempted to inquire on themselves or have lead events polluted by self-taps.
- Computing `isSelfContact` at cubit construction time means the check happens once per listing details page open; no per-frame recomputation. Cheap.
- Defense-in-depth: the `submit_inquiry` RPC ALSO validates `listing.publisher_user_id <> auth.uid()` server-side per Sub-Phase D step 2 — if the UI hide were ever bypassed, the server still rejects.
- Anonymous viewers have `auth.uid() = NULL`, so `isSelfContact` is always false for them — all three CTAs render normally for anonymous visitors per US1, US2, US3.

**Alternatives considered**:

- Server-side rejection only (let UI show CTAs and rely on the RPC to refuse) — Rejected. Lousy UX: the publisher would see live "Send Inquiry" affordance, tap it, fill out a form, then get a confusing error. Hide-at-source is clearer.
- Hide via a route-guard at the listing details page (no contact block at all for self-viewed listings) — Rejected. The publisher needs to see their own listing's contact details (to verify they're correct) and the location block etc. Only the CTAs need hiding, not the rest of the page.

---

## R-106 — Admin oversight surface design

**Decision**: A thin reuse of `InquiryInboxPage` styled as `AdminInquiryOversightPage` at the route `/admin/inquiries`. Same widget tree, same `InquiryInboxBloc` (configured with `tier: AdminTier()` so it reads cross-publisher), plus an `AdminTierBanner` widget overlaid at the top of the body and an additional per-publisher filter dropdown in the AppBar actions slot.

**Rationale**:

- The admin oversight surface (US7) shows the SAME data shape as the publisher inbox — a list of inquiries with the same columns (sender, decrypted phone, message snippet, listing reference, status, timestamp). Building a separate page would duplicate ~90% of the widget tree.
- The cross-publisher data path is governed by RLS (the `inquiries_select_admin` policy unlocks it for callers with `inquiries.view_all`); no separate data source is needed — the existing `SupabaseInquiriesDatasource.loadInbox(...)` query against `v_inquiries_inbox` returns the right rows when the caller is an admin.
- The `AdminTierBanner` is the visual indicator that the admin is viewing cross-publisher data (so they don't confuse it with their own publisher inbox if they happen to also own listings).
- The per-publisher filter dropdown is the only structural difference vs the publisher inbox — added as an additional `AppBar.actions[]` entry visible only on the admin route.

**Alternatives considered**:

- A separate `AdminInquiriesPage` with its own BLoC, repository methods, and data path — Rejected. Duplicates the widget tree and the BLoC logic; harder to keep in sync if the inbox UX evolves.
- A read-only `AdminInquiriesListWidget` embedded in the existing admin dashboard (Phase 20) — Rejected. Phase 20 hasn't landed yet; Phase 16 must ship admin oversight without depending on a future-phase composition surface. A dedicated `/admin/inquiries` route is shippable now.
- No admin oversight surface at all in Phase 16 (defer to Phase 20) — Rejected. US7 is P3 but the spec commits to it; shipping the read path now (cheap given the reuse) avoids a future ramp-up cost when Phase 20 needs it.

---

## R-107 — Write path: Edge Function vs SECURITY DEFINER RPC

**Decision**: SECURITY DEFINER PL/pgSQL RPCs (4 of them: `submit_inquiry`, `record_lead_event`, `decrypt_inquirer_phone`, `get_inbox_unread_count`). No Edge Function for Phase 16.

**Rationale**:

- The Phase 9 / 10 / 12 / 14 / 15 precedent is consistent: SECURITY DEFINER RPCs are the project's chosen pattern for "atomic multi-step writes with permission checks" when the workflow is purely DB-bound. Edge Functions are reserved for cases that need non-Postgres side effects (HTTP calls, file IO, scheduled tasks) or that need to bundle multiple atomic blocks.
- Every Phase 16 write needs are DB-bound: validate inputs against the schema, encrypt a column via `vault.encrypt`, INSERT one or two rows, capture server-side IP/UA from Postgres GUCs. All this is one PL/pgSQL function body away.
- SECURITY DEFINER RPCs run inside Postgres, so the atomic transaction guarantee for the two-row insert (inquiry + lead_event) is automatic — no try/catch / saga / two-phase-commit gymnastics needed.
- Performance: RPC dispatch via PostgREST is a single round-trip; an Edge Function would add a second round-trip (client → Edge → Postgres) for the same operation.
- Test surface: SECURITY DEFINER RPCs are testable via SQL alone (the quickstart.md `psql` smoke checks); Edge Functions need a Deno test harness.

**Alternatives considered**:

- Edge Function `submit_inquiry_edge` doing the input validation in TypeScript before calling Postgres — Rejected. Adds a layer with no value; the same validation rules belong on the schema (CHECK constraints, regex validation) for defense-in-depth anyway.
- Edge Function for the notification fan-out only — Out of scope. Phase 22 owns push notifications; Phase 16 ships data, not push.

---

## R-108 — Character counter trigger threshold

**Decision**: The `inquiry_form_message_counter` ARB-localized counter (e.g., "1842 / 2000") becomes visible only when the typed length reaches **80% of the cap** (1600 chars). Below that threshold, the form chrome stays clean with no counter shown.

**Rationale**:

- The common-case inquiry message length is ~50–300 chars (a few questions, polite phrasing). Showing a counter at 50 chars adds chrome the user doesn't need.
- The 80% threshold gives the user ~400 chars of warning before they hit the cap — enough time to wind up their thought or break the message into two inquiries.
- Showing the counter ONLY when nearing the cap matches the Gmail / Twitter / X compose pattern (counter appears only in the last 20-character window).
- The 1600-char threshold is a localized constant (no need to expose as an app setting); plan-time-decided here so the implementation doesn't need to re-litigate.

**Alternatives considered**:

- Always-on counter — Rejected. Adds chrome for no common-case benefit; gives the impression that the form expects a long message when most inquiries are short.
- Counter appears at 50% threshold (1000 chars) — Rejected. Too early; gives a false sense that the cap is closer than it is for typical messages.
- Counter at exactly the cap minus 100 — Rejected. Doesn't scale: a 200-char cap (if the limit ever changes) would have a too-narrow warning window.

---

## Summary

| ID | Area | Locked answer |
|----|------|--------------|
| R-97 | URL launcher | `url_launcher: ^6.3.0` |
| R-98 | Inquiry form shape | Modal bottom sheet |
| R-99 | Transition enforcement | BEFORE UPDATE trigger w/ static allowlist |
| R-100 | Decrypt path | SECURITY DEFINER `decrypt_inquirer_phone(uuid)` inlined into `v_inquiries_inbox` |
| R-101 | Unread-count | SECURITY DEFINER `get_inbox_unread_count()` |
| R-102 | IP/UA source | `inet_client_addr()` + `request.headers` GUC |
| R-103 | Home AppBar action | `actions:` slot between Locale + Profile; gated; badge overlay |
| R-104 | Pagination | Cursor on `(created_at DESC, id DESC)`, page size 30 |
| R-105 | Self-contact hide | Cubit-computed `isSelfContact`, `SizedBox.shrink()` |
| R-106 | Admin oversight | Thin reuse of inbox page + `AdminTierBanner` + per-publisher filter |
| R-107 | Write path | SECURITY DEFINER RPCs (no Edge Function in Phase 16) |
| R-108 | Char counter | Visible at ≥ 80% of cap (≥ 1600 chars) |
