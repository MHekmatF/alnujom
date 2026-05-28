# Phase 16 — Deferred Work

Tracks items that landed as `**⚠️ PARTIAL —**` in `tasks.md` or remain to be verified before squash-merge.

---

## D-001 — Manual device smoke tests (T075, T076, T082, T083, T084)

**Status**: PARTIALLY COMPLETE — verified on the **Infinix Note 8** (physical device, better than the planned AVD) on 2026-05-28.

**Verified on device (2026-05-28 walk):**
- ✅ T082 ContactBlock golden path — Call (dialer + `phone_revealed` event), WhatsApp (`whatsapp_clicked` event), Send inquiry (form → success + atomic inquiry+`inquiry_sent` rows).
- ✅ T083 edge cases — empty-phone listing hides Call; empty-WhatsApp listing renders WhatsApp disabled (tooltip); own-listing hides the entire contact block (FR-001d).
- ✅ T084 home inbox badge — appears on foreground-resume; reading an inquiry auto-flips `new→seen` and clears the badge; the icon now stays visible at zero unread (Q6=B fix).

**Still pending (next session):**
- ⏳ T075 inbox detail — status mutation buttons ("Mark responded"/"Mark closed"/reopen) round-trip + persistence across app restart (SC-009 cross-restart leg).
- ⏳ T076 admin oversight — `/admin/inquiries` banner + cross-publisher rows + non-admin redirect (needs an admin account on the device).
- ⏳ SC-012 empty-inbox state + SC-013 LTR/RTL × light/dark visual pass.

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

**Status**: ✅ RESOLVED — confirmed on the 2026-05-28 Infinix walk. The `phone_revealed` + `whatsapp_clicked` rows produced by the real Flutter client carried `metadata.user_agent = "Dart/3.9 (dart:io)"` (and `metadata.ip`). The earlier MCP-side NULL was purely an artifact of calling via `execute_sql` instead of the PostgREST gateway.

**(historical note)** Schema captures `user_agent`; `record_lead_event` and `submit_inquiry` RPCs read `current_setting('request.headers', true)::jsonb->>'user-agent'` from the trusted server context.

**Caveat noted in SC-016 verification**: When called via MCP `execute_sql` directly (NOT through the PostgREST gateway), `request.headers` is unset and `user_agent` lands as NULL. Real Flutter calls through PostgREST WILL populate the column.

**Why deferred**: Validating this from the actual app requires either (a) a Flutter dev build hitting the staging project and checking the row, or (b) a synthetic `curl` POST to the PostgREST endpoint with a custom UA header. Both are smoke tasks for the AVD follow-up.

**Acceptance criteria**: After D-001's AVD walk, query `SELECT metadata FROM lead_events WHERE created_at > <walk-start>` as admin; confirm both `ip` AND `user_agent` are populated with the device's real UA string (e.g., `Dart/3.x (dart:io)` or the Android WebView UA when PostgREST identifies the client).

---

## D-004 — Publisher filter dropdown on admin oversight is a stub

**Status**: Per Phase 7 deviation note + contracts/phase16-admin-oversight-overlay.md "Allowed" section, the `PublisherFilterDropdown` shows a single "All publishers" entry. The admin tier RLS already cross-unlocks every row; the filter is a UX-only refinement.

**Why deferred**: A real publisher-list query requires a `DISTINCT publisher_user_id JOIN profiles` data path that wasn't in the Phase 16 scope. Adding it now would be feature creep.

**Acceptance criteria** (for the follow-up): A future small spec or Phase 18 deliverable wires the real publisher list. Until then the admin sees all rows and can filter client-side if needed.
