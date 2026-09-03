# Delivery plan — written 2026-09-02 after a review of everything

> **للمؤسس:** هذا الملف هو قائمة العمل المرتّبة حتى يوصل التطبيق لأيدي الناس.
> القسم **B** هو الأشياء التي لا يستطيع أحد غيرك عملها (حسابات، قرارات، كلمات
> سر). القسم **A** أنفّذه أنا بالترتيب. القسم **C** هو الترتيب الزمني الذي يربط
> الاثنين. اقرأ **B** و **C** فقط إذا كان وقتك ضيقاً.

This is the ordered work queue for the next sessions. It replaces the scattered
"still owed" lists in `HANDOVER.md`, `PENDING_MIGRATIONS.md`, `v1.0.0.md`,
`REVIEW.md` and the 35 `DEFERRED.md` files — all of which were read for this
review. Those files stay the *evidence*; this file is the *queue*.

**Rules for whoever executes it**

- Work top to bottom inside a section; the numbers are the order. Section C says
  which A-items are blocked on which B-items.
- Flip `- [ ]` to `- [x]` only when the *verification* line was actually
  observed. Partial work stays `- [ ]` with a `⚠️ PARTIAL —` note and the gap.
- Every A-item ends with "Verified by". If you cannot do that step, say so in the
  item rather than skipping it.
- When an item closes, also close its origin: the checklist line in `HANDOVER.md`
  §11, the row in `v1.0.0.md`, or the `DEFERRED.md` entry it came from.

---

## 0. Where things stood on 2026-09-02 (evidence, not opinion)

| Area | State | Evidence |
|---|---|---|
| Code | `main` = `e9a19cc`; PRs #101–#108 merged 2026-09-01/02 | `git log` |
| Verify suite | All six green at #108 | run before each merge |
| Automated tests | **228 pass / 13 fail** — exactly the known cluster: `theme_gallery_test` ×4, `property_card_golden_test` ×4, `empty_state_test` ×3, `error_state_test` ×1, `app_multi_line_field_test` ×1 | `flutter test`, this review |
| Code hygiene | 0 `TODO`/`FIXME`; no stray `print` outside the logger; 3 `// ignore:` total; debug routes registered only under `kDebugMode` | grep, this review |
| Route reachability | Every route has a caller except `/publisher/dashboard` (an unused alias — `/dashboard` embeds the same page) and Reels (deliberate, no video content) | grep, this review |
| Supabase | Live. 4 migrations applied, 2 held on purpose (`PENDING_MIGRATIONS.md`) | MCP |
| Security advisors | 6 ERROR `security_definer_view` (by design, July audit); 16 anon-executable definer functions (each reviewed 2026-09-02 — see A4); `pg_net` in public; leaked-password WARN (Pro-only, ignore) | `get_advisors(security)` |
| Performance advisors | 27 WARN `multiple_permissive_policies`, 16 INFO unindexed FKs, 38 INFO unused indexes — none matter at 26 rows | `get_advisors(performance)` |
| Data | **26 listings** (16 approved · 5 sold · 3 rejected · 2 draft), **all owned by staff accounts**; 12 accounts (11 approved, 1 pending); 51 images, **0 videos**; 14 governorates / 64 cities / 380 areas; 1 push token registered | SQL |
| `app_settings` | **Updated 2026-09-02:** `default_language` now `"ar"`, `support_contact` now filled (placeholder values — see A9). Still null: `privacy_url`, `terms_url` ⚠. `maintenance_mode` off, `default_currency` SYP | SQL |
| Test devices | The **Infinix X692** (Android 10) is connected over USB and Claude drives it with `F:\mm\sdk\platform-tools\adb.exe` — no emulator needed for single-account work, and no load on the build machine. AVDs available: `Pixel_8_Pro`, `almaeda28`, `almaeda_aosp` | `adb devices`, `emulator -list-avds` |
| Build machine | `android/key.properties`, `android/app/google-services.json`, `.env.json` (with `SENTRY_DSN`) all present | `ls` |
| GitHub | Secrets `SUPABASE_URL` + `SUPABASE_ANON_KEY` exist (2026-09-01); keep-alive ran green by hand 2026-09-01; CI auto-triggers paused (manual only); one open issue, #39 | `gh` |
| Dependencies | 14 direct deps a major version behind (firebase_core 3→4, firebase_messaging 15→16, flutter_local_notifications 19→22, flutter_map 7→8, go_router 17→18, get_it 8→9, injectable 2→3, geolocator 13→14, permission_handler 11→13, share_plus 10→13, flutter_secure_storage 10→11, sentry_flutter 8→9, cached_network_image 3→4, flutter_timezone 4→5); supabase_flutter 2.12.4 → 2.17.2 | `flutter pub outdated` |
| Docs | One contradiction found and fixed in this PR: `HANDOVER.md` §2 told the owner to turn on leaked-password protection; §11 (correct) says it is Pro-only. §2 now says "Secure password change" instead | this PR |
| Not verified by anyone | Sign-in / sign-out on hardware; two-account chat + viewings; a real reset email; the update prompt opening a Telegram post; maintenance-mode recovery on a second device; the signed `1.1.x` build itself | `v1.0.0.md`, `2026-09-02-device-walk.md` |

---

## A. Claude executes — in this order

Effort: **S** ≤ 1 h · **M** ≈ half a day · **L** ≈ a day or more.

### A1 — Docs and plan (this PR) · S · no dependency
- [x] Fix the `HANDOVER.md` §2 leaked-password contradiction (now "Secure password change").
- [x] Mark the keep-alive secrets item in `HANDOVER.md` §11 done (secrets exist, run was green).
- [x] Add this file and point `CLAUDE.md` at it.
- Verified by: this PR merged on `main`.

### A2 — Signed-in device walk · M · **first pass done 2026-09-03**
The one big hole in the QA record. Record:
[`docs/qa/2026-09-03-signed-in-walk.md`](../qa/2026-09-03-signed-in-walk.md).

- [x] Single-account walk on the Infinix over USB: Home, Saved, Messages, Profile, Notifications, add-listing form, admin home, account-approval queue, agencies, reports. All correct.
- [x] **Two defects found and fixed.** Sign-in appeared to fail and had not — a pushed `/login` never dismissed itself once the session existed (the owner hit this on his first try). And one admin card printed its date in English, the only locale-less `DateFormat` in the repo.
- [x] Sign-out verified on hardware for the first time — no freeze, back on guest Home in under 1.5 s.
- [x] Session survives a cold start and an `install -r`.
- [ ] **Second account on the `Pixel_8_Pro` AVD** for the two-way work: chat optimistic send + realtime inbound, a viewing request and its confirmation, a push notification landing on the other device as a heads-up banner.
- [ ] Create a listing end to end with photos → approve → stay-live edit → revision. **Hold until A11**: it writes real rows into a database whose demo content is about to be deleted.
- [ ] The remaining three boxes in issue #39 (offline fail-open launch, four-combination light/dark × ar/en render, forward-only defaults for a new account). The About-page box is done — see A9.
- [ ] Super-admin role editor, currency history, governorate → city admin pages — reachable only by path interpolation, so confirm they open.

### A3 — Release build `1.1.1+3` · S · after A2
- [ ] Bump `pubspec.yaml` to `1.1.1+3`.
- [ ] `flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols --dart-define-from-file=.env.json`
- [ ] Copy `build/symbols` to `H:\alnujom-symbols\1.1.1+3\` (outside the repo — without it crash reports from this build are unreadable).
- [ ] Install `app-arm64-v8a-release.apk` on the Infinix; cold start; icon + splash in light and dark; guest browse; sign in.
- [ ] Record SHA-256 of the two APKs (arm64 + armeabi-v7a) in `docs/release/v1.0.0.md` and fill the "Built? NOT VERIFIED" row.
- [ ] Write the Arabic release note (3 lines, plain) into `docs/release/notes/1.1.1.ar.md` for the Telegram post and the manifest.
- Verified by: the dossier row shows the date, the hashes and the device it was smoke-tested on.

### A4 — Security hardening batch · S · **DONE 2026-09-03**
All 16 anon-executable SECURITY DEFINER functions were reviewed. Fifteen are
correct: `current_user_has_permission`, `is_agency_admin`, `is_agency_member`
and `publisher_owns_approved_listing` are boolean helpers keyed on `auth.uid()`
(**and revoking one that an anon-scoped policy calls returns 42501 to every
guest — that was the 2026-09-02 outage, do not tidy them up**);
`listing_marker_coordinates`, `list_video_reels`, `market_area_stats`,
`market_price_trend`, `publisher_rating_distribution` and
`publisher_response_stats` are the intended public reads; `record_ad_event`,
`record_lead_event` and `submit_inquiry` are intentionally guest-callable.

- [x] `20260903120001` applied: EXECUTE on `get_listing_coordinates(uuid)`
      revoked from `PUBLIC` and `anon`. The grant was never written — it was
      Postgres's default EXECUTE-to-PUBLIC, which `anon` inherits.
- [x] Verified: anon -> `42501`; authenticated keeps it; the guest map and feed
      unchanged; role sweep over 54 relations shows no unintended denial.
- Recorded in `PENDING_MIGRATIONS.md` section 2d.

### A5 — Apply the held coordinate revoke · S · **blocked on A3 + B5 (users on the new build)**
- [ ] Wait until the Telegram post for `1.1.1+3` has been up for about a week (the old build reads the columns directly — see `PENDING_MIGRATIONS.md` §3).
- [ ] Apply `20260901120002_revoke_authenticated_listing_coordinates.sql` via MCP.
- [ ] Verify the list in `PENDING_MIGRATIONS.md` §3: publisher edit form load/change/save/submit, stay-live revision, admin revision diff, admin listing preview; raw REST `select=latitude` as a signed-in user → `42501`.
- [ ] Run the probe script again.
- Verified by: the §3 block in `PENDING_MIGRATIONS.md` flipped to ✅ with the date and the verification lines; `v1.0.0.md` row 293 closed.

### A6 — Database backups · M · **BUILT 2026-09-03, one owner step left**
The Free plan includes **no automatic backups**; today a mistaken delete is
permanent. `.github/workflows/db-backup.yml`:

- [x] Weekly (Sundays 03:00 UTC) plus `workflow_dispatch`. Installs the Postgres
      **17** client from PGDG — Supabase runs 17.6 and an older `pg_dump`
      refuses a newer server.
- [x] Rejects the wrong connection string with a plain message: the transaction
      pooler (`:6543`) cannot run `pg_dump`, and the direct `db.<ref>` host is
      IPv6-only where GitHub runners have none.
- [x] **Restores the dump it just took** into a `postgres:17` service container
      and asserts at least 40 base tables come back (production has 43). A
      backup nobody has restored is a guess.
- [x] Refuses to archive anything unless `BACKUP_PASSPHRASE` exists. **This
      repository is public and its artifacts are downloadable by anyone**, and a
      full dump carries `auth.users` password hashes and every real phone
      number. With the secret it uploads AES-256-encrypted; without it the dump
      and the drill still run and only the upload is skipped.
- [ ] **Owner: create `BACKUP_PASSPHRASE`** (a long random passphrase, kept in a
      password manager — lose it and the backups are unreadable). Until then
      nothing is being kept.
- [ ] Then tick the `HANDOVER.md` section 11 "Confirm backups and do one restore
      drill" box with the run URL.

### A7 — Purge job for deleted accounts · M · no dependency
`request_account_deletion()` soft-deletes; the `auth.users` row and the account's
storage objects remain (`PENDING_MIGRATIONS.md` §2 "Still owed").
- [ ] Edge Function `purge_deleted_accounts` (service role): for each `account_deletion_requests` row with `purge_status` pending and `requested_at` older than 30 days — delete the user's objects in every bucket (prefix = user id), `auth.admin.deleteUser(id)`, set `purge_status = 'purged'` + timestamp; write an `audit_logs` row.
- [ ] Schedule: `pg_cron` weekly calling it through `pg_net` with the service key from Vault (same pattern as the existing cron jobs) — or, if that proves fiddly, a documented manual invoke in `HANDOVER.md`.
- [ ] Test with a throwaway account the founder creates and deletes (Claude cannot create accounts).
- Verified by: the throwaway's `auth.users` row and files are gone; the request row says `purged`.

### A8 — Privacy policy live · S · **DONE 2026-09-03**
- [x] Replaced all 8 `TODO(owner)` markers. Operator: **النجوم للتسويق العقاري**, a real-estate office in the Syrian Arab Republic; contact `m.hekmatfanari@gmail.com`; Syrian law governs.
- [x] `tool/build_privacy_site.py` renders both files to `docs/legal/site/`, mirrored to the `gh-pages` branch. It refuses to render a file that still holds a placeholder.
- [x] Live and checked with `curl`: **<https://mhekmatf.github.io/alnujom/>** (ar, authoritative) and **<https://mhekmatf.github.io/alnujom/en.html>** — both 200, no login, no placeholders.
- [x] `app_settings.privacy_url` set; the About page now shows an **الأحكام القانونية** section. `terms_url` deliberately left null — a privacy policy is not terms of service, and the About page correctly hides what is unset. **Terms of service is a separate document nobody has written.**

### A9 — Settings the founder answers, Claude applies · S · **DONE 2026-09-03**
- [x] `default_language` → `"ar"`.
- [x] `support_contact` → phone and WhatsApp `+963991883342`, email `m.hekmatfanari@gmail.com`. Verified on the device: all three rows render on the About page. **The owner says these are provisional — remind him to swap them for business details before launch** (they also appear in the published privacy policy).
- [ ] Record the new live values in `HANDOVER.md` §8.

### A10 — Version manifest · S · **blocked on A3 + B5 (the Telegram post URL)**
- [ ] Write `latest.json` per `docs/release/version-manifest.example.json` with `latest_version: "1.1.1"`, `latest_build: 3`, `telegram_url` = the post, Arabic + English notes from A3.
- [ ] Upload to bucket `app-release`, path `android/latest.json`, via the storage REST API with the service-role key from `.env.admin.json` (never `.env.json`).
- [ ] On a phone still running the old build: cold start → prompt appears → Update opens the Telegram post. This closes `v1.0.0.md` row 233.
- Verified by: the prompt screenshot and the row updated.

### A11 — Demo-data cleanup · S · **blocked on B7 (decision + at least 5 real listings)**
- [ ] Take a backup first (A6, or a manual `pg_dump` if A6 is not live yet).
- [ ] Run PART 1 of `supabase/scripts/pre_launch_data_cleanup.sql`, read the counts, choose the set in PART 2, run PART 3 with its `ROLLBACK`, compare, then `COMMIT`.
- [ ] Guest map + home + search show only the real listings; `get_advisors` unchanged.
- Verified by: the counts before/after appended to the script header.

### A12 — Small hygiene, bundle into any nearby PR · S
- [ ] Remove the `/publisher/dashboard` route + its two constants (no caller; `/dashboard` renders the same page) — or leave it with a one-line comment saying so. Run `lint_public_routes` after.
- [ ] `v1.0.0.md` row 171 (new icon + splash in light/dark on device) — observe it during A3 and close it.
- [ ] Issue #39 — close it when A2 ticks its boxes.

### A13 — After launch, not before
- [ ] **Dependency upgrades** (the 14 majors above + `supabase_flutter` 2.17). One PR, `pub get` re-resolved per the analyzer/test chain, full device walk after. Risk without user-visible benefit before launch; do it in the first quiet week after.
- [ ] **Performance advisors**: add the 16 FK indexes (one migration), consolidate the duplicate permissive SELECT/UPDATE policies per table (27 warnings) — measure nothing until there are thousands of rows.
- [ ] **The 13 failing tests**: regenerate the goldens, pin the `flutter_animate` timers, fix the `EmptyState`/`ErrorState` expectations — still under the "no new tests" rule, this is repairing existing ones.
- [ ] **REVIEW.md**: the batch-2 pass over ~40 internal admin/agency screens, and the §3b open questions — founder answers first.
- [ ] **Reels**: give it an entry point (Search tab segment or Home rail) once `listing_media` has real `video` rows; until then it stays route-only.
- [ ] **Phone verification over WhatsApp** (SMS cannot reach `+963`): manual code at first, Business API later — product decision.
- [ ] **Google Play**: `docs/release/google-play-readiness.md` — AAB, `--dart-define=IN_APP_UPDATE_PROMPT=false`, photo/video permission declaration, web deletion-request URL; gated on B9.
- [ ] Move `pg_net` out of `public` if Supabase ever allows it on this plan (advisor WARN, cosmetic).

---

## B. Founder — only you can do these

| # | What | Why it matters | Time |
|---|---|---|---|
| **B1** | **Custom SMTP** — Supabase → Authentication → Emails → SMTP Settings; any free tier (Resend, Brevo, SendGrid). Then send yourself one real reset from the app. | Without it password-reset mail reaches nobody; the function says "sent" and nothing looks wrong. | 20 min |
| **B2** | **Type your password once** on the Infinix. It is connected by USB and Claude drives it directly — the app is already sitting on the sign-in screen, so this is two fields and a tap. Claude may not type passwords, and that is the only step in the whole walk that needs you. A second account for the two-way chat / viewing tests can come later on the `Pixel_8_Pro` AVD, which Claude starts itself. | Every signed-in screen is unverified on hardware. Unblocks A2. | 1 min |
| ~~**B3**~~ | ~~**Support channels**~~ — **done 2026-09-02**, applied and seen on the device (A9). **But they are the founder's own personal number and gmail, given as placeholders.** Before launch: send the real support channels so A9 can be re-run. | Otherwise real users call his personal phone. | ⚠️ redo before launch |
| **B4** | **Privacy policy blanks**: legal entity name + country of registration; a contact email someone reads; governing law. Plus a clear **yes** to publishing it on GitHub Pages. | The policy must be live (a real URL) before Play and is good practice for Telegram distribution too. Unblocks A8. | 10 min |
| **B5** | **Telegram channel**: create it, post the APK Claude hands you with the Arabic note, send back the post URL. | The one outstanding launch item since June. Unblocks A10 and, a week later, A5. | 15 min |
| **B6** | **Database password as a GitHub secret** named `SUPABASE_DB_URL` (the session-pooler URI from Supabase → Project Settings → Database). Add it yourself in GitHub → Settings → Secrets; never paste it in chat. | Free plan = no backups. Unblocks A6. | 5 min |
| **B7** | **Decide the demo data** (26 listings, all from team accounts). Recommendation: delete all of them — but only after at least 5 real listings are in, because an empty marketplace is worse than a demo one. Alternative: keep 3–4 clearly labelled as samples. | Today 15 of the 16 public listings are fake. Unblocks A11. | decision |
| **B8** | **Secure password change = ON** — Supabase → Authentication → Sign In / Providers → Email. **Correction:** the 2026-09-02 message told you to turn on *leaked-password protection*; that was wrong — it is Pro-plan only. This is the toggle that exists on Free. | Stops a stolen old session from silently changing the password. | 1 min |
| **B9** | **Google Play Console from Syria** — can an account be opened at all? | Decides whether the Play track exists. Later. | unknown |
| **B10** | **Save the secrets in a password manager**: keystore file + its passwords, DB password, Vault secrets, `.env.admin.json`. | Losing the keystore means the app can never be updated again. | 10 min |
| **B11** | **Restrict the Firebase Android key** (Google Cloud Console → the `AIza…` key → package `com.alnujom.app` + release fingerprint + FCM APIs only). | A leaked unrestricted key can be abused on your quota. | 10 min |
| **B12** | **A backup super-admin** and your moderators enrolled from the in-app Roles screen. | So someone else can get in if you lose your phone. | 10 min |
| **B13** | **Reels**: agree it stays hidden until there are ~10 videos. | Product call; no work either way today. | decision |

---

## C. The order that ties it together

```
now ──► A1 (this PR)
        A4 hardening ─────────────────────────────────────────── any time
        A7 purge job ─────────────────────────────────────────── any time
B2 ───► A2 signed-in walk ──► A3 build 1.1.1+3 ──► B5 Telegram ──► A10 manifest
                                                              └─ ~1 week ─► A5 revoke
B1 SMTP ──► founder tests one real reset
B3 ───► A9 settings            B4 ───► A8 privacy policy live
B6 ───► A6 backups (restore drill proves it)
B7 (+ ≥5 real listings) ──► A11 delete demo data ──► launch announcement
after launch ──► A13
```

Launch = A3 posted (B5), A9 and A8 done, A11 done, B1 done. Everything else can
follow it.

---

## C2. Two questions settled on 2026-09-02

**"Can we test on a web build instead? It would be lighter."** — No, and it is
not needed. The project has **no web target at all**: there is no `web/` folder,
and Android is the declared platform. Adding one means `flutter create
--platforms=web .` and then working around every plugin with no web
implementation — `flutter_local_notifications`, `flutter_image_compress`,
`permission_handler` at minimum. And the result would test a *different* app:
web exercises no push notification, no notification icon, no Android back-stack,
no deep link, no update prompt, no camera — which is precisely where every defect
of the last three sessions was found (#105 back-stack, #106 notification icon,
#107 tab exits). It would be a day of work to build a surface that cannot see the
class of bug we keep finding.

The lighter option already exists and is in use: **the Infinix is connected over
USB**, driven straight from `adb`. It costs the build machine nothing — no
emulator process, no RAM — and it is the exact hardware and Android version a
user has. The `Pixel_8_Pro` AVD is only needed for the *second* account in the
two-way chat and viewing tests, and only while those run.

**The stale package on the test phone.** The Infinix carries two builds:
`com.alnujom.app` (`1.1.0+2`, the real one, updated 2026-09-02) and
`com.alnujom.alnujom_app` (`1.0.0+1`, from 2026-03-07, an old application id that
no longer exists in the codebase). The old one is dead weight and can confuse a
walk — uninstall it before the A2 walk, but ask first, since it is a delete on
the founder's own device.

---

## D. Checked on 2026-09-02 and clean — do not redo

- All seven Edge Functions match the repo (six unchanged; `request_password_reset` v2 redeployed and verified via GoTrue logs).
- Role read sweep: 0/44 relations fail for `anon`, 0/53 for `authenticated` (`probe_role_read_access.sql`).
- The whole guest RPC surface answers 200; no IDOR among SECURITY DEFINER functions that take a user id; all storage write policies ownership-gated; Realtime replica identity correct.
- No page consumes a bloc nothing provides (all three `BlocProvider` forms checked); Dart crash-pattern sweeps clean; `lint_di_graph` and `lint_public_routes` green.
- Arabic ARB: every non-Arabic value is a template, symbol or hint by design (21 keys, all legitimate).
- Debug routes (`/_debug/theme-gallery`, `/debug/money-formatter`) exist only under `kDebugMode`.
- Release signing fails closed without `key.properties` (verified in `build.gradle.kts`); `targetSdk` 36; HTTPS-only.
- Map privacy oracle closed and proven closed with no marker moved; notification icon and heads-up channel fixed and seen on the device.
- Keep-alive workflow: secrets present, manual run green 2026-09-01.
- "Save search" and "message the publisher" as a guest both toast correctly (they look silent only because a toast outlives no screenshot loop).
