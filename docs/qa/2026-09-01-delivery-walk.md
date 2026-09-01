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

## Second walk — signed-in surfaces (debug build, DESIGN_TOOLS on)

The first walk could only reach guest screens. A throwaway account was
registered through the app's own form, approved, used, deleted through the app,
and then fully purged — so the database ends exactly where it started.

| # | Check | Result |
|---|---|---|
| 13 | Registration from the app | PASS — account created, correctly gated on the "الحساب قيد المراجعة" screen, which carries its own sign-out |
| 14 | Approved account reaches the app | PASS — home feed, bottom nav, profile |
| 15 | Profile screen | PASS — identity card with the "مقبول" badge, role chip, account section, sign-out |
| 16 | **SegmentedButton theme** | PASS — the preferred-currency toggle now renders as a pill with the selected segment on `primaryContainer` and a check, matching the chips. It was stock Material before this branch |
| 17 | Verified-agency badge on a photo card | PASS — the green "موثّق" pill reads clearly over listing photography |
| 18 | **Account deletion, end to end** | PASS — see below |

**Account deletion, verified in the database afterwards:** phone released (no
profile holds it), `account_status = deleted`, name nulled, one operator-queue
row, one `account.self_deleted` audit row, and `auth.users.email` renamed to
`deleted-<uuid>@deleted.alnujom.local` so the number can register again. The app
returned to the guest home. The three friction gates all behaved: the
acknowledgement checkbox arms the button, and the destructive dialog asks once
more.

The test account was then purged completely (auth user, queue row, audit row).
Final state: 12 profiles, 26 listings, 12 auth users — identical to before.

## Third walk — the batch-2 admin screens

A second throwaway account was created with the `admin` role, walked, then
purged the same way. This is the only way those screens can be seen at all —
they are login- and permission-gated.

| # | Check | Result |
|---|---|---|
| 19 | Navigation drawer (admin) | PASS — Publishing / Administration / Chats & viewings / Other groups, all on DS cards |
| 20 | Admin console home | PASS — three KPI counters and the moderation + settings tile grids in the restyled idiom, with a live "2" badge on account approvals |
| 21 | Account-approvals queue | PASS — real rows with name, phone, request date and accept/reject actions |

Everything rendered in Arabic RTL with no overflow, no unstyled Material and no
error state. Both test accounts were purged afterwards; the database is back to
12 profiles, 12 auth users, 26 listings, 12 approval requests and 0 deletion
requests.

**One cosmetic gap noticed, not fixed:** an approval row for an account whose
profile has no name or phone falls back to displaying the raw user UUID. That is
the Phase-24 fallback working as designed (it replaced a blank card), but a UUID
is not useful to a moderator. Only demo data hits it today.

**A note on the design-tools build:** the `DESIGN_TOOLS=true` palette pill sits
over the app bar's trailing corner and covers the drawer button. Open the drawer
with an edge swipe when running that build.

## Fourth walk — the Infinix Note 8 (real hardware)

The release APK (`arm64-v8a`, signed with the release keystore) installed and
walked on the founder's own Infinix Note 8 — Helio G80, 6 GB RAM, Android 10,
720x1640 — against the live backend.

The phone was carrying a **debug** build from 21 June, which a release APK
cannot upgrade in place (different signing key), so that build was uninstalled
first. Its local data went with it; signing back in is all that is needed.

| # | Check | Result |
|---|---|---|
| 22 | Cold start | **5.4 s** (`am start -W`, `TotalTime: 5392 ms`) — over the 3 s target, recorded in the release doc |
| 23 | Onboarding at 720x1640 | PASS — the headline wraps to two lines on this narrower screen and still does not overflow |
| 24 | Register and login screens | PASS |
| 25 | Guest home | PASS — categories, ad artwork, real listings |
| 26 | **Guest Search** | PASS — 16 results, on real hardware |
| 27 | **Guest Map** | PASS — 4 (Aleppo) + 10 (Damascus) clusters plus Latakia and Homs pins, OSM tiles and attribution |
| 28 | Listing detail | PASS — hero, specs row, the "موثّق ميدانياً" banner, deed and finish cards, and the sticky WhatsApp / message / call bar |
| 29 | Similar-listings carousel | PASS — cards fit their row, no overflow |
| 30 | Android log across the whole walk | Clean — no error, exception or overflow |
| 31 | Memory after browsing | ~296 MB PSS |

**Could not be tested here:** dark mode. Infinix's XOS ignores both
`cmd uimode night yes` and `settings put secure ui_night_mode`, so the theme
cannot be flipped over adb on this device — it needs the phone's own settings
toggle, or the app's theme setting, which is behind a login.

**Also noted:** a guest session does not survive an app restart, which is normal
for guest mode but worth knowing when re-testing.

## What this walk could NOT cover

- **The last hop of the password reset**: tapping the real emailed link on a
  device running this build, and setting a new password.
- **The Vault-secret purge inside deletion** — neither test account had Vault PII.
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
