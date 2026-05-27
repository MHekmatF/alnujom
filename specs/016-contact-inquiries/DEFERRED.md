# Phase 16 — Deferred Work

Tracks items that landed as `**⚠️ PARTIAL —**` in `tasks.md` or remain to be verified before squash-merge.

---

## D-001 — Manual AVD smoke tests (T075, T076, T082, T083, T084)

**Status**: Implementation complete; visual + flow verification pending.

**Owner**: Orchestrator post-merge or a dedicated follow-up session.

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

## D-002 — SC-003 ≤ 2s and SC-001/SC-002 ≤ 1s UX budgets

**Status**: Architectural feasibility confirmed; absolute wall-clock measurement deferred.

**Why**: Wall-clock numbers depend on the user's actual device + network. The Phase 4 backend smoke ran sub-second on the live Supabase project; the Flutter side is a `await Future<>` on a single PostgREST RPC call, which is bandwidth-bound. The AVD walk above will confirm subjective responsiveness; a future perf phase can introduce instrumentation.

**Acceptance criteria** (for the follow-up):
- During the AVD walk, time each of the 3 CTA paths (Call, WhatsApp, Send Inquiry) end-to-end. If any exceeds its budget (1s for Call/WhatsApp, 2s for Send Inquiry) on the Infinix Note 8, file a perf issue.

---

## D-003 — `lead_events.metadata.user_agent` populated from PostgREST headers

**Status**: Schema captures `user_agent`; `record_lead_event` and `submit_inquiry` RPCs read `current_setting('request.headers', true)::jsonb->>'user-agent'` from the trusted server context.

**Caveat noted in SC-016 verification**: When called via MCP `execute_sql` directly (NOT through the PostgREST gateway), `request.headers` is unset and `user_agent` lands as NULL. Real Flutter calls through PostgREST WILL populate the column.

**Why deferred**: Validating this from the actual app requires either (a) a Flutter dev build hitting the staging project and checking the row, or (b) a synthetic `curl` POST to the PostgREST endpoint with a custom UA header. Both are smoke tasks for the AVD follow-up.

**Acceptance criteria**: After D-001's AVD walk, query `SELECT metadata FROM lead_events WHERE created_at > <walk-start>` as admin; confirm both `ip` AND `user_agent` are populated with the device's real UA string (e.g., `Dart/3.x (dart:io)` or the Android WebView UA when PostgREST identifies the client).

---

## D-004 — Publisher filter dropdown on admin oversight is a stub

**Status**: Per Phase 7 deviation note + contracts/phase16-admin-oversight-overlay.md "Allowed" section, the `PublisherFilterDropdown` shows a single "All publishers" entry. The admin tier RLS already cross-unlocks every row; the filter is a UX-only refinement.

**Why deferred**: A real publisher-list query requires a `DISTINCT publisher_user_id JOIN profiles` data path that wasn't in the Phase 16 scope. Adding it now would be feature creep.

**Acceptance criteria** (for the follow-up): A future small spec or Phase 18 deliverable wires the real publisher list. Until then the admin sees all rows and can filter client-side if needed.
