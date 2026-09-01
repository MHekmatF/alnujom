# Delivery QA walk — 2026-09-01

Pixel 8 Pro AVD (API 36, x86_64, software GPU), release APK built from this
branch and signed with the real release keystore, run against the **live**
Supabase backend.

## What passed

| # | Check | Result |
|---|---|---|
| 1 | App launches from a cold install | PASS — reaches the onboarding screen |
| 2 | Onboarding renders | PASS — full-bleed hero, Arabic RTL, brand mark, skip + next, page dots |
| 3 | Notification permission is requested after first frame, not over a black screen | PASS (the Phase-24 UX-1 fix) |
| 4 | Register screen | PASS — blue header, white sheet, RTL labels, phone/password/name/email fields |
| 5 | Login screen | PASS — password show/hide, forgot-password link, guest entry, register link |
| 6 | Guest entry → home feed | PASS — categories, ad banner with real artwork, "أحدث الإعلانات" with real listings |
| 7 | **Guest → Search tab** | **PASS — 16 results.** Before this branch it ejected the user to /login |
| 8 | **Guest → Map view** | **PASS — 16 markers** clustered as 4 (Aleppo), 10 (Damascus), plus Latakia and Homs, with OSM tiles and attribution. Before this branch the query failed with `42501` for anonymous callers |
| 9 | Reset-password deep link is registered | PASS — `am start -a VIEW -d "alnujom://auth/reset-password#…"` reports *"intent has been delivered"*, so Android routes the scheme to the app |
| 10 | A **forged** recovery token is rejected | PASS — the app stays on login rather than opening the set-password screen |
| 11 | Android log during the whole walk | Clean — no app error, exception or crash |
| 12 | App label | "Al Nujom" in the system permission dialog (the localised `@string/app_name`) |

Marker counts were cross-checked against SQL: `anon` sees exactly 16 rows in
`v_listings_map_public`, and all 16 approximate listings return a **jittered**
coordinate — none returns its exact position.

## Server-side verification (same day, after the walk)

**Password reset — the deep link is accepted.** The Edge Function was redeployed
as version 2 and invoked for real against the founder's own account (the only
one with a real email on file — the audit's "3 accounts" figure is now 1). The
GoTrue log shows
`POST | 200 | /auth/v1/admin/generate_link?redirect_to=alnujom%3A%2F%2Fauth%2Freset-password`
and the function logged `reset_email_sent`, i.e. the **primary** path, not the
no-deep-link fallback. So the redirect address is already allow-listed and **no
dashboard change is needed**. What remains unproven is only the last hop: tapping
the emailed link on a device running this build.

**Account deletion — the RPC runs correctly.** Executed twice against real
accounts inside transactions that were rolled back, so nothing changed. On a
plain account it returned
`{"status":"deleted", …, "auth_identifier_released":true}` — including the
best-effort `auth.users` rename, the branch most likely to fail. On the heaviest
account (15 listings) it left 11 listings live, tombstoned one profile, and wrote
one operator-queue row and one `account.self_deleted` audit row. Both rollbacks
confirmed: still 26 listings and 12 profiles, none deleted.

That also proves the amended `enforce_profile_status_admin_only()` trigger works
— without it, the tombstone UPDATE would have raised `42501`.

## What this walk could NOT cover

- **The last hop of the password reset**: tapping the real emailed link on a
  device running this build, and setting a new password.
- **Account deletion from the UI**, and its Vault-secret purge (no test account
  had Vault PII).
- **Agency invitation accept** — needs two accounts (inviter + invitee).
- **The heads-up push banner** — needs a real FCM send to a device that
  previously ran the old build, which is the case the new channel id exists for.
- **Chat with two real accounts**, and the two-device maintenance-mode walk
  (issue #39).
- **The batch-2 admin screens.** They are login-gated behind an admin account, so
  this walk never reached them; their restyle is verified only by the linters.
- **The Infinix Note 8.** The build installed on it is a *debug* build from June,
  so a release APK cannot upgrade it in place (different signing key). Uninstall
  the debug build first if you want the release on that device.

## Notes

- The emulator's own SystemUI threw an "isn't responding" dialog once under the
  software GPU. That is an emulator artifact, not the app.
- Two packages are installed on the Infinix: the current `com.alnujom.app` and a
  stale `com.alnujom.alnujom_app` v1.0.0 from March, left over from before the
  application id was settled. Worth uninstalling to avoid confusing future QA.
