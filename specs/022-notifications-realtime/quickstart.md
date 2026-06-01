# Quickstart — Phase 22 Push Notifications + Realtime (manual verification)

End-to-end recipe a reviewer/agent runs to validate Phase 22. Two-device where noted (device A = recipient, device B = admin/super-admin). Per the MVP convention there are no new automated tests (memory `feedback_no_new_tests`); evidence = on-device walks + SQL/wire inspection mapped to SC-001..SC-011. Run the app with `--dart-define-from-file=.env.json` (memory `project_dart_defines`). Apply migrations via Supabase MCP (`project_supabase_apply_via_mcp`); after applying, run `get_advisors` and a structural check.

## 0. Apply backend + deploy the Edge Function (PB)
1. Apply `20260602120001`–`20260602120011` in order (Supabase MCP `apply_migration`, one file per name — `project_supabase_mcp_apply_migration`).
2. Deploy `supabase/functions/dispatch_push`.
3. Register secrets from env (only when testing push): `fcm_service_account`, `push_dispatch_url`, `push_dispatch_token`. **Skip this step to test the degraded path (§7).**
4. Confirm Realtime: `select * from pg_publication_tables where pubname='supabase_realtime' and tablename in ('listings','reports','user_roles');` → three rows.
5. `get_advisors` → no new RLS-disabled table; no function-search-path warning on the new fns.

## 1. In-app notifications for the six events (SC-001) — two-device
On A, sign in as a regular user (kept on the pending screen if not yet approved). On B (admin):
- **Account approved**: approve A's account → on A, the bell badge increments and the center shows "Account approved"; tap → opens home; row `read_at` set. (For a fresh pending account, do this first.)
- **Account rejected**: with a second test account, reject → center shows "Account rejected"; tap → rejection screen.
- **Listing approved/rejected**: A submits a listing; B approves → A gets "Listing approved" → tap opens listing details. B rejects another with a reason → A gets "Listing rejected" → tap opens My Listings showing the **reason** (note: the reason is shown in-app, NOT on the push tray — §6).
- **Inquiry received**: from a third account, submit an inquiry on A's approved listing → A gets "Inquiry received" → tap opens the inquiry.
- **Agency invitation**: from an agency admin, invite A → A gets "Agency invitation" → tap opens `/agency` accept/decline.
SQL: `select type, count(*) from notifications where recipient_user_id='<A>' group by type;` → one row per triggered event.

## 2. Push to device, incl. cold start (SC-002) — two-device, push configured
With secrets registered (§0.3) and A logged in (token registered — verify `select count(*) from notification_tokens where user_id='<A>';` ≥ 1): background the app on A → trigger an approval on B → a system push arrives on A within ~10 s; tap → opens the deep-linked screen. Fully close the app on A, approve a listing on B → cold-start tap deep-links to the listing.

## 3. Exactly-once (SC-009)
Trigger one listing approval → `select count(*) … type='listing_approved'` = 1. Re-invoke the approve path on the already-approved listing → count stays 1 (no duplicate; the PERFORM is on the transition branch only).

## 4. Admin counters live + reconcile (SC-004) — two-device
On B, open the admin dashboard. From A: submit a listing → B's pending-listing counter increments within ~5 s (no refresh). B (or another admin) approves it → counter decrements. File a report from A → reports counter increments; resolve → updates. Toggle B's network off ~10 s then on → counters reconcile to correct values (fresh fetch). Confirm a non-admin client receives no counter change.

## 5. Live permission refresh (SC-005) — two-device
On A (regular user), confirm an admin-gated surface is hidden. On B (super-admin), grant A a role carrying a permission → on A, the gated surface appears **without re-login** (within the live `user_roles` refresh). Revoke → it disappears on the next live refresh. Confirm the existing three observation points still work (foreground-resume refresh; explicit refresh; next login).

## 6. Push privacy + localization (SC-006) — push configured
Reject a listing with a detailed reason on B. On A: the **push tray** shows generic copy ("Listing reviewed — tap for details"), NOT the reason; opening the app shows the full reason in My Listings. Set A's preferred language to Arabic → next push tray text is Arabic; switch to English → English. In-app center: toggle the app locale → center copy re-renders in the active locale. Cycle the four combinations (light/dark × ar/en) on the Infinix Note 8 + a 412 dp AVD — center list/tile/badge/empty/error all localized + direction-correct + Phase 2 tokens.

## 7. Degraded mode — push disabled/unconfigured (SC-003)
With NO secrets registered (skip §0.3) — i.e., simulate Firebase blocked from Syria: build + run the app (it must NOT red-screen — guarded `Firebase.initializeApp`). Repeat §1's six events → every notification still lands **in-app** (center + badge) with NO error and NO crash; `notify_push_dispatch` skips silently (dispatch URL/secret null). Confirm `flutter build apk --debug` succeeds with push disabled.

## 8. `notifications_enabled` off (FR-021)
Set A's `user_preferences.notifications_enabled=false`. Trigger an event on B → A receives NO push / no active alert, but the center still shows the new item as **unread** when A opens it (history written). Turn the flag back on → pushes resume.

## 9. Security / RLS (SC-007) — wire level
From user X's session: `select * from notifications where recipient_user_id='<Y>'` → 0 rows; attempt `insert into notifications …` → denied; `select/insert/delete` on `notification_tokens` for Y → denied. Confirm `grep -ri "fcm_service_account\|service_account" lib/ android/ supabase/functions/dispatch_push` shows only Vault *reads*, never key material; the built APK does not contain the JSON. Non-admin Realtime: subscribe to `listings` as a non-admin → no admin rows delivered.

## 10. Badge + persistence + multi-device (SC-008, SC-011)
Badge count equals `unread_notification_count()`; mark-one and mark-all update it. Log out + back in (and reinstall on a second device, same account) → history present. Two devices logged in: both receive push; log out one → `notification_tokens` loses that device's row only; the other keeps receiving push.

## 11. Structural / dependency gates (SC-010)
- `grep -R "package:firebase" lib/features/*/domain lib/core` → only `lib/core/messaging` interface (no SDK import) and NOTHING under any `domain/` (Principle IX).
- No iOS/Web files added; `google-services`/manifest changes Android-only (Principle XI).
- App runs with push disabled (§7).
- No new permission key (`grep` the §9.1 catalog unchanged); the only backend surface added = the 2 tables, the enqueue+client RPCs, the 4 transition amendments, the Vault secret(s), `pg_net`+trigger+`dispatch_push`, and the 3 Realtime publication adds.
- Full verify suite passes: `flutter analyze` + format + design-tokens + l10n-parity + l10n-literals + SDK-boundary (memory `project_wave_run_full_verify_suite`).

## Constitution grep gates (quick)
- l10n: every new ARB key present in BOTH `app_ar.arb` + `app_en.arb`; generated `app_localizations*.dart` regenerated.
- DI: `dart run build_runner build --delete-conflicting-outputs` clean; `injection.config.dart` checked in.
- Domain purity: no `supabase_flutter`/`firebase_messaging` import under any feature `domain/`.
