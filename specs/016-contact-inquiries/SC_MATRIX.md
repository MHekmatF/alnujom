# Phase 16 — Success Criteria Matrix

Final verification matrix for the 17 success criteria declared in [spec.md](spec.md). Each row maps a SC to where it was verified.

Legend:
- ✅ **VERIFIED** — automated check passed; cite the artifact / query / command.
- ⚠️ **AVD-DEFERRED** — implementation complete; manual smoke test (Pixel 8 Pro AVD walk per memory `feedback_avd_acceptable_qa.md`) deferred to a follow-up session. Not a blocker for the PR per the project's MVP testing posture.
- 🛈 **NOTED** — verified in design / migration body / by virtue of the existing schema. Lower confidence than full smoke; called out for follow-up if it ever drifts.

| SC | Description (one-line) | Status | Evidence |
|----|------------------------|--------|----------|
| **SC-001** | Call CTA opens dialer + records `phone_revealed` lead event within 1s | ✅ VERIFIED (device) | **Infinix Note 8 walk (2026-05-28)**: tapped Call on "Luxury HOuse in AlMaza" → dialer opened; `lead_events` row `phone_revealed` landed with `ip=::1/128` + `user_agent=Dart/3.9 (dart:io)`. |
| **SC-002** | WhatsApp CTA opens WhatsApp + records `whatsapp_clicked` event within 1s | ✅ VERIFIED (device) | **Infinix Note 8 walk**: tapped WhatsApp → app/browser opened; `lead_events` row `whatsapp_clicked` landed with IP + UA. Render-but-disabled gate also confirmed on a listing with no WhatsApp number (Q1=B-refined). |
| **SC-003** | Inquiry form submit → success snackbar within 2s + atomic 2-row insert | ✅ VERIFIED (device) | **Infinix Note 8 walk**: filled + submitted the inquiry form → success; `inquiries` row + companion `inquiry_sent` `lead_events` row landed at the **identical** `created_at` timestamp → confirms the atomic two-row insert through the real client path (not just the Phase 4 MCP smoke). |
| **SC-004** | Wire-level: `inquirer_phone` never appears plaintext in any SELECT unless caller is publisher/sender/admin | ✅ VERIFIED | Phase 4 T036 three-tier decrypt smoke: publisher → `+963991234567`; unrelated user → NULL; admin → `+963991234567`. The `v_inquiries_inbox` view calls `decrypt_inquirer_phone(i.id)` which self-gates. |
| **SC-005** | `pg_dump` + grep plaintext phone → 0 matches | ✅ VERIFIED | MCP-side equivalent: `SELECT count(*) WHERE sender_name/message/metadata/encode(bytea) ILIKE '%+963991234567%'` → 0 across all four. Ciphertext bytes don't contain the plaintext. |
| **SC-006** | Cross-tenant publisher SELECT isolation | ✅ VERIFIED | T085(a) wire smoke: publisher A (owner) sees 1 row; unrelated user `22222222…` (neither sender nor publisher) sees 0 rows. **Fixed during polish**: migration `20260527120013` set `security_invoker = true` on `v_inquiries_inbox` after T085 caught the RLS-bypass. |
| **SC-007** | Anonymous direct table SELECT denied | ✅ VERIFIED | T085(b) wire smoke: `anon` → `SELECT FROM public.inquiries` ERROR 42501; `SELECT FROM v_inquiries_inbox` ERROR 42501; same for `lead_events` and both lead-events views. **Fixed during polish**: migration `20260527120013` REVOKEd anon's Supabase-default-granted view privileges. |
| **SC-008** | Admin sees all inquiries with decrypted phone | ✅ VERIFIED | Phase 4 T036 third arm: admin `6583a883…` (holds `inquiries.view_all`) calling `decrypt_inquirer_phone` → returns `+963991234567`. View body in `v_inquiries_inbox` projects the call. |
| **SC-009** | Status mutation persists across restart | ⚠️ AVD-DEFERRED | `update_status` repository method maps SQLSTATE 23514 → `TransitionInvalidFailure`; data lands via the column-restricted `UPDATE (status)` GRANT. Cross-restart persistence is the natural Postgres durability guarantee. |
| **SC-010** | Dep manifest: zero in-app calling / VoIP / chat-protocol libs | ✅ VERIFIED | T087 grep: `flutter_phone_direct_caller\|firebase_messaging\|sentry\|amplitude\|mixpanel` in `pubspec.yaml` → 0 matches. New deps in this phase: `url_launcher` only. |
| **SC-011** | No hardcoded `user.role == 'admin'` anywhere | ✅ VERIFIED | T087 grep: `user\.role\s*==\s*'admin'` in `lib/` → 0 matches. Admin gate is `getIt<PermissionChecker>().has('inquiries.view_all')` on the `/admin/inquiries` route. |
| **SC-012** | Empty inbox shows localized empty state | ✅ VERIFIED (impl) / ⚠️ AVD-DEFERRED (visual) | `InquiryInboxPage` renders `Center(Text(l10n.inquiry_inbox_empty_state))` when `state.inquiries.isEmpty`. ARB keys present in both `app_ar.arb` + `app_en.arb`. |
| **SC-013** | LTR/RTL × light/dark renders correctly | ⚠️ AVD-DEFERRED | All Phase 16 widgets use design tokens + ARB getters (T087 confirmed no inline strings / hex literals). Visual smoke pending Pixel 8 Pro AVD walk. |
| **SC-014** | Decrypt failure → "Phone unavailable" placeholder, no crash | ✅ VERIFIED | T088 polish smoke: corrupted `inquirer_phone_encrypted = '\x00'::bytea`; `decrypt_inquirer_phone` returned NULL (FR-026 try/catch); `v_inquiries_inbox` row rendered with all other columns intact and `inquirer_phone_decrypted IS NULL = true`. |
| **SC-015** | Cross-tenant UPDATE denied | ✅ VERIFIED | T085(c) wire smoke: user `22222222…` attempting `UPDATE inquiries SET status='closed' WHERE id='444f71ce…'` → 0 rows affected. The `inquiries_update_publisher` RLS USING predicate hides the row. |
| **SC-016** | Lead-events metadata visible to admins only | ✅ VERIFIED | T085(d) wire smoke: (1) `v_lead_events_publisher` columns = `id, listing_id, user_id, event_type, created_at` (NO `metadata`); (2) publisher querying `v_lead_events_admin` → 0 rows (defensive WHERE); (3) admin querying `v_lead_events_admin` → returns `metadata->>'ip' = '2600:1f18:...'`. **Note on `user_agent`**: returned NULL when the smoke call originated from MCP `execute_sql` (PostgREST gateway is the only path that populates `request.headers`). Live Flutter calls through PostgREST will include UA. |
| **SC-017** | Home AppBar inbox entry: visible iff publisher owns ≥1 approved listing, badge = unread count, decrements on read | ✅ VERIFIED (device) | **Infinix Note 8 walk**: badge showed "1" after foreground-resume; reading the inquiry auto-flipped `new→seen` and the badge cleared in real time. **Spec-correction during the walk**: the Phase 7 `canShowEntry = count > 0` shortcut was replaced with the Q6=B-faithful "owns ≥1 approved listing" gate (new RPC `publisher_owns_approved_listing` + `CheckOwnsApprovedListing` use case) — the inbox icon now stays visible at zero unread, confirmed on device. |

## Summary

**Verified automatically (SQL/RLS/wire)**: 11 of 17 (SC-003, 004, 005, 006, 007, 008, 010, 011, 014, 015, 016)

**Verified on physical device (Infinix Note 8, 2026-05-28 walk)**: SC-001, SC-002, SC-003, SC-017 + FR-001d self-contact hiding. The walk also confirmed `lead_events.metadata.user_agent` IS populated through the real client (`Dart/3.9 (dart:io)`), closing deferred item D-003.

**Still deferred**: SC-009 (status persistence across full app restart — auto `new→seen` was confirmed, but the cross-restart/cross-device leg is unverified), SC-012 (empty-inbox state — the test inbox had ≥1 row), SC-013 (LTR/RTL × light/dark visual pass), and admin oversight (SC-008 UI). Tracked in DEFERRED.md §D-001.

### Device-session fixes (2026-05-28, folded into this PR)

The physical-device walk surfaced bugs that were fixed in-session:
- **Home feed crash** (pre-existing Phase 13): a signed-in publisher's own rejected listings (null `published_at`) leaked into the public feed query via owner-RLS and crashed `DateTime.parse(null)`, breaking the whole feed. Fixed by filtering the feed to `published_at IS NOT NULL` (published rows only — not a status-column filter).
- **Search row + card overflow** (pre-existing Phase 14/15): "Show on map" button → icon-only; `SearchResultCard` height 100→116.
- **ContactBlock "Call" header** (Phase 16): the section heading reused `cta_call` ("Call"); replaced with a proper `contact_section_title` ("Contact"/"التواصل").
- **Inbox visibility** (Phase 16, SC-017): see the SC-017 row — `count > 0` gate corrected to the Q6=B "owns ≥1 approved listing" gate.

**Critical polish-phase discoveries**:
- T085 caught a real RLS-bypass + anon-grant leak on the views — fixed via two follow-up migrations:
  - `20260527120013_phase16_view_invoker_lockdown.sql` (set `security_invoker = true` on `v_inquiries_inbox`; REVOKE all from anon + PUBLIC)
  - `20260527120014_phase16_view_invoker_policy_fix.sql` (re-create `v_lead_events_publisher` with publisher-scoped WHERE; revert lead-events views to `security_invoker = false` so they can read the REVOKEd `lead_events` table via the owner-postgres path; impose row filters inside the view bodies)
- This is exactly the failure mode the Final-Phase Polish exists to catch. Both fixes were applied and re-verified.

## Status

Phase 16 is **ready for end-of-spec PR** to `main`. AVD-deferred items are tracked in [DEFERRED.md](DEFERRED.md) and will be smoke-tested in a follow-up session before squash-merge.
