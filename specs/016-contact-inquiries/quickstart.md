# Phase 16 — Quickstart (manual verification recipe)

End-to-end manual verification recipe for Phase 16 — Contact, Inquiries & Lead Events.

The recipe assumes the project is set up per `docs/dev/android-emulator-windows.md` and the developer has `psql` / Supabase MCP access to the live project.

---

## 0. Prerequisites

- The repo is checked out on branch `016-contact-inquiries`.
- The `.env.json` file is in place per memory `project_dart_defines.md`.
- Phase 15 has merged (this branch was cut from a Phase 15 commit).
- At least 1 publisher account is approved with ≥ 1 approved listing whose `phone` AND `whatsapp` are populated.
- A second publisher account is approved with ≥ 1 approved listing (for cross-tenant RLS testing).
- An admin account holding the `inquiries.view_all` permission is available (default `admin` role per IMPLEMENTATION_PLAN §9.1).

---

## 1. One-time Vault key setup

Run once on the live Supabase project, idempotently:

```sql
SELECT vault.create_secret(
  gen_random_uuid()::text,   -- the actual key value
  'app-inquirer-phone-key',  -- the name we look up by
  'Symmetric key for inquirer_phone column encryption in public.inquiries (Phase 16, ADR-0001)'
);
```

Verify:

```sql
SELECT name, description FROM vault.secrets WHERE name = 'app-inquirer-phone-key';
-- Expected: 1 row.
```

If the row already exists from a prior run, the second `vault.create_secret(...)` raises a uniqueness violation — that's fine; the key is already there.

---

## 2. Apply migrations

```bash
supabase db push
# OR via Supabase MCP `apply_migration` for each of the 12 migration files
# in ascending filename order:
#   20260527120001_create_inquiries_table.sql
#   20260527120002_create_lead_events_table.sql
#   20260527120003_create_inquiries_policies.sql
#   20260527120004_create_lead_events_policies.sql
#   20260527120005_create_enforce_inquiry_transition_trigger.sql
#   20260527120006_create_decrypt_inquirer_phone_fn.sql
#   20260527120007_create_v_inquiries_inbox_view.sql
#   20260527120008_create_v_lead_events_views.sql
#   20260527120009_create_submit_inquiry_rpc.sql
#   20260527120010_create_record_lead_event_rpc.sql
#   20260527120011_create_get_inbox_unread_count_rpc.sql
#   20260527120012_phase16_advisor_hardening.sql
```

Verify:

```sql
\d+ public.inquiries
\d+ public.lead_events
\df public.submit_inquiry
\df public.record_lead_event
\df public.decrypt_inquirer_phone
\df public.get_inbox_unread_count
\df public.enforce_inquiry_transition
SELECT viewname FROM pg_views WHERE schemaname = 'public' AND viewname LIKE 'v_inquiries%' OR viewname LIKE 'v_lead_events%';
-- Expected: v_inquiries_inbox, v_lead_events_publisher, v_lead_events_admin
```

---

## 3. Wire-level privacy gates (SC-004, SC-005, FR-022)

### 3a. Anonymous SELECT denied

```sql
SET ROLE anon;
SELECT * FROM public.inquiries;        -- Expected: ERROR or 0 rows.
SELECT * FROM public.v_inquiries_inbox; -- Expected: ERROR (no GRANT to anon).
SELECT * FROM public.lead_events;      -- Expected: ERROR or 0 rows.
RESET ROLE;
```

### 3b. Cross-tenant publisher SELECT returns zero

```sql
-- As publisher-A
SELECT count(*) FROM public.v_inquiries_inbox;  -- Expected: count of A's inquiries
-- As publisher-B
SELECT count(*) FROM public.v_inquiries_inbox;  -- Expected: count of B's inquiries
-- Publisher-A's inquiries should NOT appear in publisher-B's count.
```

### 3c. Encrypted column never reveals plaintext

```sql
SELECT id, inquirer_phone_encrypted FROM public.inquiries LIMIT 1;
-- Expected: inquirer_phone_encrypted is a BYTEA (hex blob), not a phone number string.
```

### 3d. `pg_dump` smoke check (the load-bearing SC-005 verification)

```bash
# Submit a test inquiry with a recognizable test phone first (e.g., +963991234567).
pg_dump --no-owner --no-acl postgres > /tmp/dump.sql
grep -F '+963991234567' /tmp/dump.sql
# Expected: zero matches.
```

---

## 4. Listing details ContactBlock manual walk

On the reference Infinix Note 8 (primary) AND Pixel 8 Pro AVD (secondary):

### 4a. Anonymous visitor — Call CTA

1. Open the app (anonymous).
2. Navigate to home → tap an approved listing whose `phone` is set.
3. Confirm the Call CTA is visible and enabled.
4. Tap Call.
5. Confirm the Android system dialer opens pre-populated with the publisher's phone.
6. Tap Back from the dialer; confirm return to the listing details page.
7. SQL check:
   ```sql
   SELECT count(*) FROM public.lead_events
   WHERE listing_id = '<the listing's id>'
     AND event_type = 'phone_revealed'
     AND created_at > now() - interval '1 minute';
   -- Expected: ≥ 1.
   ```

### 4b. WhatsApp CTA — listing with `whatsapp` set

1. From the same listing (or one whose `whatsapp` is set), tap WhatsApp.
2. Confirm WhatsApp opens to the publisher's contact (or, if WhatsApp not installed, the system browser opens `wa.me/...`).
3. SQL check: `whatsapp_clicked` lead event row exists.

### 4c. WhatsApp CTA — listing with `whatsapp` empty (Q1=B-refined)

1. Find or seed an approved listing where `phone` is set but `whatsapp` is empty.
2. Confirm the WhatsApp CTA renders but is visibly disabled (greyed out).
3. Long-press the disabled button; confirm a localized tooltip appears.
4. Confirm tapping the disabled button does NOT insert a `whatsapp_clicked` lead event.

### 4d. Self-contact hide (FR-001d)

1. Sign in as publisher-A.
2. Open one of publisher-A's own approved listings.
3. Confirm NO Call CTA, NO WhatsApp CTA, NO Send Inquiry CTA visible — the entire ContactBlock collapses to `SizedBox.shrink()`.
4. Defense-in-depth SQL check:
   ```sql
   -- As publisher-A:
   SELECT public.submit_inquiry(
     '<publisher-A's own listing id>'::uuid,
     'A',
     '+963991234567',
     'test'
   );
   -- Expected: ERROR with SQLSTATE 23514 and message 'self_contact_blocked'.
   ```

---

## 5. Inquiry form submission (FR-006..012, US3)

### 5a. Anonymous submission

1. Sign out completely.
2. Open an approved listing (must not be self-owned — anonymous user can't be a publisher).
3. Tap Send Inquiry.
4. Confirm the modal bottom sheet opens with empty fields.
5. Fill name = "Test Anon", phone = "+963999000001", message = "Is this still available?"
6. Tap Submit.
7. Confirm a localized success snackbar appears AND navigation returns to the listing details page.
8. SQL check:
   ```sql
   SELECT id, sender_user_id, sender_name, status, created_at,
          public.decrypt_inquirer_phone(id) as decrypted_phone
   FROM public.inquiries
   WHERE created_at > now() - interval '1 minute'
   ORDER BY created_at DESC LIMIT 1;
   -- Expected: sender_user_id IS NULL; sender_name = 'Test Anon';
   -- status = 'new'; decrypted_phone = NULL (you're anonymous, can't decrypt).
   ```
9. SQL check (as publisher-A — the listing's owner):
   ```sql
   SELECT public.decrypt_inquirer_phone(id) FROM public.inquiries
   WHERE created_at > now() - interval '1 minute' ORDER BY created_at DESC LIMIT 1;
   -- Expected: '+963999000001' (the publisher can decrypt).
   ```
10. SQL check (companion lead event):
    ```sql
    SELECT event_type FROM public.lead_events
    WHERE created_at > now() - interval '1 minute' ORDER BY created_at DESC LIMIT 1;
    -- Expected: 'inquiry_sent'.
    ```

### 5b. Signed-in submission (auto-fill)

1. Sign in as a non-publisher account (or use a different publisher to avoid self-contact).
2. Open another publisher's approved listing.
3. Tap Send Inquiry.
4. Confirm name + phone fields pre-populated from the signed-in user's profile.
5. Override the phone field; submit.
6. Confirm the `sender_user_id` on the resulting `inquiries` row matches the signed-in user.

### 5c. Validation errors

1. Open the form anonymously.
2. Try submitting empty → field-level errors render.
3. Type a malformed phone ("12345") → "Invalid phone number" error.
4. Type a 2001-char message → "Message too long" error AND submit button disabled.
5. Confirm zero rows inserted in either table during failures.

### 5d. Atomic-submit failure (defense-in-depth)

```sql
-- Simulate a half-state by temporarily adding a deferred-constraint violation:
BEGIN;
ALTER TABLE public.lead_events DROP CONSTRAINT lead_events_listing_id_fkey;
ALTER TABLE public.lead_events ADD CONSTRAINT lead_events_listing_id_fkey
  FOREIGN KEY (listing_id) REFERENCES public.listings(id) ON DELETE RESTRICT
  DEFERRABLE INITIALLY DEFERRED;
-- Run submit_inquiry with a listing_id about to be deleted:
ROLLBACK;
-- (This is illustrative; actual atomicity verification is via reading the
-- submit_inquiry function body and confirming both INSERTs are in one BEGIN block.)
```

---

## 6. Publisher inbox (FR-019..026, US4)

### 6a. Top-level AppBar action visibility

1. Sign in as publisher-A.
2. Confirm on the home page that a third action icon appears in the AppBar between LocaleToggleAction and the profile icon.
3. Confirm the icon shows a badge with the count of `new`-status inquiries.
4. Sign out → sign in as a user with zero approved listings.
5. Confirm the icon is NOT visible (FR-019 gate).
6. Sign in as an anonymous-effective state (no auth) → confirm the home page looks identical to Phase 15 (no Phase 16 chrome additions).

### 6b. Open inbox + auto-mark-as-seen

1. As publisher-A, tap the AppBar inbox action.
2. Confirm navigation to `/inquiries` and the inbox page renders.
3. Confirm the list shows publisher-A's inquiries newest-first.
4. Tap a `new`-status inquiry.
5. Confirm navigation to the detail page.
6. Wait 1 second; confirm in another session (`psql`) that the inquiry's status is now `seen`.
7. Confirm the home AppBar badge count decremented by 1 in real-time (without leaving the detail page — the badge is computed in the home page's still-alive AppBar).

### 6c. Status mutations + transition allowlist

1. From the detail page, tap "Mark as responded" → confirm status updates.
2. Tap "Mark as closed" → confirm status updates.
3. From the `closed` state, confirm the UI offers "Reopen to seen" and "Reopen to responded" buttons but NOT "Reopen to new".
4. Tap "Reopen to seen"; confirm transition succeeds.
5. SQL test the forbidden `closed → new`:
   ```sql
   UPDATE public.inquiries SET status = 'new' WHERE id = '<closed inquiry id>';
   -- Expected: ERROR 'invalid_inquiry_transition: closed -> new' SQLSTATE 23514.
   ```

### 6d. Cross-publisher RLS

1. Sign in as publisher-B.
2. Open the inbox.
3. Confirm zero inquiries from publisher-A's listings appear.
4. SQL audit:
   ```sql
   -- As publisher-B:
   SELECT COUNT(*) FROM public.v_inquiries_inbox
   WHERE listing_id IN (SELECT id FROM public.listings WHERE publisher_user_id <> auth.uid());
   -- Expected: 0.
   ```

### 6e. Vault decrypt failure handling (FR-026)

1. Corrupt one inquiry's encrypted column (test only — do not run on production):
   ```sql
   UPDATE public.inquiries SET inquirer_phone_encrypted = '\x00'::bytea
   WHERE id = '<some test inquiry id>';
   ```
2. Open the publisher's inbox containing that inquiry.
3. Confirm the inbox renders without crashing; the corrupted row's phone shows the "Phone unavailable" placeholder.
4. Restore: re-submit the test inquiry to get a fresh ciphertext.

---

## 7. Admin oversight (US7, FR-034, SC-011)

### 7a. Admin route guard

1. Sign in as the admin account.
2. Navigate to `/admin/inquiries`.
3. Confirm the page renders with `AdminTierBanner` at the top.
4. Confirm all inquiries from all publishers appear with decrypted callback phone visible.
5. Sign in as a non-admin account (e.g., a moderator with `users.view` but not `inquiries.view_all`).
6. Manually go to `/admin/inquiries` URL via deep link.
7. Confirm redirect to `/home` (the route guard rejects).

### 7b. No hardcoded role checks

```bash
# From repo root
grep -RE "user\.role == 'admin'|user\.role==\"admin\"" lib/
# Expected: zero matches.
```

---

## 8. Lead events admin-only metadata visibility (SC-016)

### 8a. Publisher view excludes metadata

```sql
-- As publisher-A:
SELECT * FROM public.v_lead_events_publisher LIMIT 1;
-- Expected: columns are (id, listing_id, user_id, event_type, created_at).
-- NO 'metadata' column in the result.
```

### 8b. Admin view includes metadata

```sql
-- As an admin:
SELECT id, event_type, metadata FROM public.v_lead_events_admin LIMIT 1;
-- Expected: metadata is a non-null JSONB with keys 'ip' and 'user_agent'.
```

### 8c. Non-admin attempting admin view

```sql
-- As publisher-A (non-admin):
SELECT * FROM public.v_lead_events_admin LIMIT 1;
-- Expected: 0 rows (the view's WHERE predicate fails).
```

---

## 9. Grep gates (constitutional discipline)

### 9a. No Supabase imports outside data layer

```bash
grep -RE "package:supabase_flutter|package:postgrest" \
  lib/features/inquiries/domain/ lib/features/inquiries/presentation/
# Expected: zero matches.
```

### 9b. No inline string literals in feature code

```bash
grep -RE "Text\(['\"]" lib/features/inquiries/
# Expected: only Text(l10n.xxx) or Text(state.xxx) — no Text('...') with literal copy.
```

### 9c. No inline hex literals / raw font sizes

```bash
grep -RE "Color\(0x[0-9A-Fa-f]{8}\)|fontSize:\s*[0-9]+\.[0-9]+" lib/features/inquiries/
# Expected: zero matches.
```

### 9d. No banned packages

```bash
grep -E "flutter_phone_direct_caller|firebase_messaging|sentry|amplitude|mixpanel" pubspec.yaml
# Expected: zero matches.
```

### 9e. No `_showComingSoon` leftover

```bash
grep -F "_showComingSoon" lib/features/listing_details/presentation/widgets/contact_block.dart
# Expected: zero matches.
```

### 9f. No iOS / Web code

```bash
ls ios/ 2>/dev/null  # Expected: directory does not exist OR is unchanged
grep -RE "kIsWeb" lib/features/inquiries/   # Expected: zero matches
```

---

## 10. Final SC matrix check

| SC | Status | Notes |
|----|--------|-------|
| SC-001 | ☐ | Verified via §4a stopwatch + lead event count |
| SC-002 | ☐ | Verified via §4b stopwatch + lead event count |
| SC-003 | ☐ | Verified via §5a/§5d atomic-submit + stopwatch |
| SC-004 | ☐ | Verified via §3b cross-tenant wire capture |
| SC-005 | ☐ | Verified via §3d `pg_dump | grep` smoke check |
| SC-006 | ☐ | Verified via §6d cross-publisher zero-row check |
| SC-007 | ☐ | Verified via §3a anonymous denial |
| SC-008 | ☐ | Verified via §7a admin all-publisher visibility |
| SC-009 | ☐ | Verified via §6c status persistence across app restart |
| SC-010 | ☐ | Verified via §9d banned-package grep |
| SC-011 | ☐ | Verified via §7b hardcoded role grep |
| SC-012 | ☐ | Verified via empty-state UI in §6b |
| SC-013 | ☐ | 4-combination matrix walk in §4 + §5 + §6 |
| SC-014 | ☐ | Verified via §6e Vault decrypt failure handling |
| SC-015 | ☐ | Verified via cross-tenant UPDATE attempt |
| SC-016 | ☐ | Verified via §8a/§8b metadata column visibility |
| SC-017 | ☐ | Verified via §6a badge correctness + visibility gate |

Tick each box as you complete the manual walk. Any unchecked SC is a deferred item recorded in `DEFERRED.md`.
