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

## What this walk could NOT cover

- **The password-reset round trip.** The `request_password_reset` Edge Function
  is still at version 1; it needs `alnujom://auth/reset-password` added to the
  Supabase Redirect URLs allow-list and then redeploying. Only the intent
  plumbing is proven, not the mail → link → new password path.
- **Account deletion end to end.** The RPC is applied but nobody has deleted an
  account. Do it on a throwaway account: check the profile is tombstoned, its
  listings leave search/map/home, its three Vault secrets are gone, and a row
  lands in `account_deletion_requests`.
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
