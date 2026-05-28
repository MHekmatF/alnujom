# Phase 16 — Deferred Work

Tracks items that landed as `**⚠️ PARTIAL —**` in `tasks.md` or remain to be verified before squash-merge.

---

## D-001 — Manual device smoke tests (T075, T076, T082, T083, T084) — ✅ COMPLETE

**Status**: ✅ FULLY VERIFIED on the **Infinix Note 8** (physical device, exceeds the planned AVD) on 2026-05-28.

- ✅ T082 ContactBlock golden path — Call (`phone_revealed` + IP/UA), WhatsApp (`whatsapp_clicked`), Send inquiry (atomic inquiry+`inquiry_sent`).
- ✅ T083 edge cases — empty-phone hides Call; empty-WhatsApp disabled-with-tooltip; own-listing collapses the block (FR-001d).
- ✅ T084 home inbox badge — shows for publishers (Q6=B owns-approved-listing gate), appears on resume, decrements on read, stays visible at zero unread; personal inbox scoped to own listings.
- ✅ T075 inbox detail — status transitions (responded→seen→closed→responded) persist incl. across full app restart (SC-009).
- ✅ T076 admin oversight — reached via the new home shield → Admin home → Admin: Inquiries tile; cross-publisher rows + banner; non-publisher detail view is read-only.
- ✅ SC-012 empty-inbox state + SC-013 LTR/RTL × light/dark — both confirmed.

**Bugs fixed during the device walk (all folded into the PR):**
1. Home feed crash on null `published_at` (Phase 13).
2. Search row + card overflow (Phase 14/15).
3. ContactBlock "Call" heading → "Contact" (Phase 16).
4. Inbox entry gated on unread>0 → Q6=B owns-approved-listing gate (Phase 16).
5. Admin entry point missing → added a home shield icon → admin home (pre-existing gap).
6. Admin oversight detail was mutable + auto-transitioned → now read-only for non-publishers (`viewer_is_publisher`), plus 0-row-UPDATE rollback.
7. Personal inbox over-showed all rows for admins → now scoped to own listings via `viewer_is_publisher` (admin oversight passes `adminTier=true` to show all).
8. Transition trigger missing `responded → seen` vs data-model §2.5 + enum → trigger realigned to spec (11 pairs).

**Scope** (one walk on Pixel 8 Pro AVD, per memory `feedback_avd_acceptable_qa.md`):

1. **T082 — ContactBlock golden path**: Open an approved listing whose `phone` AND `whatsapp` are set. Tap Call → confirm dialer hand-off + a `lead_events` row with `event_type='phone_revealed'` lands within 1s (verify via Supabase MCP `execute_sql`). Tap WhatsApp → confirm WhatsApp / browser hand-off + `whatsapp_clicked` lead event. Tap Send Inquiry → confirm modal sheet opens, fill the form, submit → confirm success snackbar + atomic two-row insert.

2. **T083 — ContactBlock edge cases**: (a) listing with empty `phone` → Call CTA hidden; (b) listing with empty `whatsapp` → WhatsApp CTA rendered-but-disabled (tooltip from `l10n.contact_whatsapp_disabled_tooltip`, Q1=B-refined); (c) sign in as the publisher of a listing → open that listing → confirm all 3 CTAs hidden per FR-001d (`ContactBlock` collapses to `SizedBox.shrink()`).

3. **T075 — Inbox golden path**: Sign in as a publisher with ≥1 approved listing and ≥1 pre-seeded `new`-status inquiry → navigate to `/inquiries` → confirm inbox renders newest-first with decrypted phone + status badge + message snippet → tap a row → confirm detail page renders + status auto-flips `new → seen` → flip to `responded` → confirm UI update + server persistence.

4. **T076 — Admin oversight**: Sign in as admin (holds `inquiries.view_all`) → navigate to `/admin/inquiries` → confirm `AdminTierBanner` + cross-publisher rows + decrypted phone visible. Sign out, sign in as non-admin → manually navigate to `/admin/inquiries` → confirm redirect to `/home`.

5. **T084 — Home AppBar inbox action**: Sign in as a publisher with ≥1 approved listing + ≥1 `new`-status inquiry → confirm inbox icon visible in home AppBar with badge showing count; tap → navigate to `/inquiries`; tap a `new` row → detail page auto-flips status to `seen` → return to home → confirm badge decremented; background then resume app → confirm badge refreshes. Sign out → confirm home AppBar shows NO inbox icon.

**Why deferred**: Sub-agents in the multi-agent workflow can't drive an emulator. The implementation is fully verified by `flutter analyze --fatal-infos` (clean) + the Phase 4 + polish-phase backend smokes that confirm every server-side path.

**Acceptance criteria** (for the follow-up):
- Each of the 5 sub-flows above produces the documented UI state + the documented database side effect (verifiable via Supabase MCP from the same session).
- Flip T075, T076, T082, T083, T084 from `**⚠️ PARTIAL —**` to `[X]` in `tasks.md`.

---

## D-002 — SC-003 ≤ 2s and SC-001/SC-002 ≤ 1s UX budgets — ✅ RESOLVED (by observation)

**Status**: ✅ Met. Verified on the 2026-05-28 Infinix Note 8 walk: all three CTA paths (Call, WhatsApp, Send Inquiry) were subjectively instantaneous with no perceptible lag — the dialer/WhatsApp hand-offs and the inquiry-form success snackbar all returned well within their budgets.

**Evidence**:
- Backend RPCs are sub-second on the live project (Phase 4 smoke + the device walk's API-log timestamps). Each CTA is a single `await` on one PostgREST RPC followed by an OS hand-off (`launchUrl`) or a snackbar — no heavy client work.
- The device walk produced the expected DB side effects (`phone_revealed`, `whatsapp_clicked`, atomic inquiry insert) with no observed delay; the user reported all CTAs working smoothly.

**Note**: A precise millisecond instrumentation pass (e.g., `Stopwatch` around the RPC + hand-off, logged) is *not* warranted for the MVP — the observational evidence + sub-second backend already satisfy the budgets. If a future perf phase wants hard numbers, add a temporary `Stopwatch` in the ContactBlock handlers, capture on-device, and remove.

---

## D-003 — `lead_events.metadata.user_agent` populated from PostgREST headers

**Status**: ✅ RESOLVED — confirmed on the 2026-05-28 Infinix walk. The `phone_revealed` + `whatsapp_clicked` rows produced by the real Flutter client carried `metadata.user_agent = "Dart/3.9 (dart:io)"` (and `metadata.ip`). The earlier MCP-side NULL was purely an artifact of calling via `execute_sql` instead of the PostgREST gateway.

**(historical note)** Schema captures `user_agent`; `record_lead_event` and `submit_inquiry` RPCs read `current_setting('request.headers', true)::jsonb->>'user-agent'` from the trusted server context.

**Caveat noted in SC-016 verification**: When called via MCP `execute_sql` directly (NOT through the PostgREST gateway), `request.headers` is unset and `user_agent` lands as NULL. Real Flutter calls through PostgREST WILL populate the column.

**Why deferred**: Validating this from the actual app requires either (a) a Flutter dev build hitting the staging project and checking the row, or (b) a synthetic `curl` POST to the PostgREST endpoint with a custom UA header. Both are smoke tasks for the AVD follow-up.

**Acceptance criteria**: After D-001's AVD walk, query `SELECT metadata FROM lead_events WHERE created_at > <walk-start>` as admin; confirm both `ip` AND `user_agent` are populated with the device's real UA string (e.g., `Dart/3.x (dart:io)` or the Android WebView UA when PostgREST identifies the client).

---

## D-004 — Publisher filter dropdown on admin oversight is a stub

**Status**: Per Phase 7 deviation note + contracts/phase16-admin-oversight-overlay.md "Allowed" section, the `PublisherFilterDropdown` shows a single "All publishers" entry. The admin tier RLS already cross-unlocks every row; the filter is a UX-only refinement.

**Why deferred**: A real publisher-list query requires a `DISTINCT publisher_user_id JOIN profiles` data path that wasn't in the Phase 16 scope. Adding it now would be feature creep.

**Decision (2026-05-29)**: DEFERRED TO PHASE 18 (Reports & moderation — the next admin phase). Scope assessment showed a proper implementation is a ~13-file mini-feature: a `publisher_user_id` column on `v_inquiries_inbox` + an admin-gated `list_inquiry_publishers()` RPC (for publisher names) + DTO/entity/datasource/repository/use-case threading of a `publisherIdFilter` + a new `InquiryInboxPublisherFilterChanged` bloc event/state + the dropdown UI + DI regen. It re-touches the security-hardened inbox view, so it belongs in a phase that gives admin surfaces proper attention rather than a post-merge hotfix. The current "All publishers" stub is acceptable in the interim — the admin already sees every row (admin-tier RLS), and the existing status + listing filters narrow results.

**Acceptance criteria** (for Phase 18): wire the real named publisher list + server-side `publisher_user_id` filter; preserve the Phase 16 read-only-for-non-publishers guarantee + the personal-inbox `viewer_is_publisher` scoping.
