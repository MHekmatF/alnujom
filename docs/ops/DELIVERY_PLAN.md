# Delivery plan — written 2026-09-02 after a review of everything

> **للمؤسس:** هذا الملف هو قائمة العمل المرتّبة حتى يوصل التطبيق لأيدي الناس.
> القسم **B** هو الأشياء التي لا يستطيع أحد غيرك عملها (حسابات، قرارات، كلمات
> سر). القسم **A** أنفّذه أنا بالترتيب. القسم **C** هو الترتيب الزمني الذي يربط
> الاثنين. اقرأ **B** و **C** فقط إذا كان وقتك ضيقاً.

**2026-09-04:** section **E** below adds what the full review of the app found —
evidence in [`REVIEW_2026-09-04.md`](REVIEW_2026-09-04.md). Two of its items
(A14) are launch-relevant and go before everything else that is not blocked.

**2026-09-05:** section **F** adds the gap review — what is still unverified,
what was found that nobody had written down, and what the app lacks — as a
**proposed** queue (A25–A40). Nothing in it has started; §7 of
[`REVIEW_2026-09-05.md`](REVIEW_2026-09-05.md) ranks what only the founder can do.

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
- [x] Issue #39: offline fail-open launch **PASS** (opens to sign-in, not the maintenance screen, no crash; the session survives and returns on reconnect) and the four-combination light/dark × ar/en render **PASS**. With the About-page box from A9 that is three of four.
- [ ] Issue #39's last box — forward-only defaults for a **new** account. Needs a sign-up, which Claude may not perform. One registration by the owner settles it.
- [x] Super-admin role editor, currency history, governorate → city → area admin
      pages — **all three open with real data, 2026-09-04**. The role editor was
      the one worth checking: its first screenful is entirely unchecked, and an
      editor that opened blank would let an admin save and silently wipe a role.
      It does not — `users.view` is ticked further down. Record:
      [`2026-09-04-release-1.1.1-and-admin-drilldowns.md`](../qa/2026-09-04-release-1.1.1-and-admin-drilldowns.md).
      One gap found there: the permission catalogue is English only, and it is
      database text, so `lint_l10n_literals` is blind to it.

### A3 — Release build `1.1.1+3` · S · **DONE 2026-09-04**
- [x] `pubspec.yaml` bumped to `1.1.1+3`.
- [x] Built with `--split-per-abi --obfuscate --split-debug-info=build/symbols
      --dart-define-from-file=.env.json`. Signed with the release key —
      `apksigner` reports `CN=Hekmat Fanari, OU=AlNujom`, v2 scheme, not debug.
- [x] Symbols copied to `H:\alnujom-symbols\1.1.1+3\` with a `SHA256SUMS.txt`
      beside them. Without those files a crash report from this obfuscated build
      is unreadable.
- [x] Installed on the Infinix over `install -r`; cold start **1.98 s** to first
      frame; the signed-in session survived the upgrade; Home rendered with the
      publish FAB.
- [x] **The icon and splash check found two real defects** — a slab of pale sky
      behind the emblem in the adaptive icon, and the same slab on the splash —
      and both are fixed and rebuilt. Full account in `v1.0.0.md`; the assets are
      now derived by `tool/build_orbit_icon_assets.py` so the next person to
      regenerate them cannot reintroduce it.
- [x] Moving the build-time-only branding art out of `assets/branding/` took
      **2.9 MB** out of every APK on the way past.
- [x] SHA-256 of all three APKs recorded in `docs/release/v1.0.0.md`, and the
      "Built? NOT VERIFIED" row replaced with a real verification table.
- [x] Arabic release note in `docs/release/notes/1.1.1.ar.md` (English beside
      it) — three lines for the Telegram post, the same three for the manifest.
- Verified by: the dossier's `1.1.1+3` verification table, dated, with the
  hashes and the device it was smoke-tested on.

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

### A6 — Database backups · M · **WORKING 2026-09-03, one owner step left**
The Free plan includes **no automatic backups**; before this, a mistaken delete
was permanent. `.github/workflows/db-backup.yml`, verified green on
[run 33767219231](https://github.com/MHekmatF/alnujom/actions/runs/33767219231):

- [x] Weekly (Sundays 03:00 UTC) plus `workflow_dispatch`.
- [x] **Dump succeeds: 1,022,411 bytes**, taken with `pg_dump 17.11` through the
      session pooler at `aws-1-us-east-2.pooler.supabase.com`.
- [x] **The archive lists data for all 43 public tables** — exactly the number
      production has. This is the primary assertion: `pg_restore --list` reads
      the file directly, so it catches a truncated or corrupt dump and a missing
      table without needing any Supabase furniture.
- [x] The secondary restore drill rebuilds 36 of 43 tables in a throwaway
      `postgres:17`. The gap is expected and is **not** a bad backup: `pgsodium`,
      `supabase_vault` and `pg_net` cannot be installed in a plain Postgres, so
      some DDL never replays. It fails only on a collapse (under 30).
- [x] Refuses to archive anything while `BACKUP_PASSPHRASE` is unset — confirmed
      on this run, which warned and uploaded nothing. **This repository is public
      and its artifacts are downloadable by anyone**, and a full dump carries
      `auth.users` password hashes and every real phone number.
- [ ] **Owner: create `BACKUP_PASSPHRASE`** (a long random passphrase, kept in a
      password manager — lose it and the backups are unreadable). Until then the
      job proves a backup is possible every week but keeps no file.
- [ ] Then tick the `HANDOVER.md` section 11 "Confirm backups and do one restore
      drill" box with the run URL.

Four failed runs got here, each for its own reason, all recorded in the
workflow's comments so they are not rediscovered: the secret held a bare
password rather than a URI (my instructions asked for both at different times);
`/usr/bin/pg_dump` is Debian's `pg_wrapper` and picked the runner's Postgres 16
over the 17 that had just been installed; and judging a Supabase dump by whether
a vanilla Postgres can replay every statement was the wrong test.

### A7 — Purge job for deleted accounts · M · **BUILT + DEPLOYED 2026-09-03**

> **Correction.** An earlier version of this entry claimed a purge could never
> find the departed user's files — that `request_account_deletion` deleted the
> listing rows, taking the only link to their storage paths with them, and that
> every day without a schema change made another deletion permanently
> un-purgeable. **That was wrong, and it was wrong in the alarming direction.**
> Reading the migration properly: it runs `UPDATE public.listings SET
> status='deleted'`. The row survives, `publisher_user_id` is never nulled, and
> `listing_media` is not touched at all. Nothing is lost, there is no race, and
> no schema change is needed. There is also no `pg_cron` in this project and no
> migration that hard-deletes from `public.listings`, so no background job can
> break that chain either.

`request_account_deletion()` soft-deletes and anonymises; the `auth.users` row
and the uploaded files remain. The published privacy policy promises the
deletion is real, so the sweep has to exist.

- [x] `supabase/functions/purge_deleted_accounts` written and **deployed
      (version 1)**. For each queue row older than `grace_days` (default 30) it
      removes the storage objects found by joining `listing_media` to the user's
      listings, deletes the `auth.users` row, and marks the request `purged`.
      Files first, deliberately: if the auth delete fails the row stays pending
      and the next run retries, whereas the other order would strand objects
      with no owner to find them by.
- [x] Gated on `users.suspend` checked as the **caller** — the same shape as
      `approve_listing`. (There is no `users.manage`; the four rights are view /
      approve / reject / suspend.)
- [x] Guards verified against the live function: `GET` → `invalid_request`,
      anon `POST` → `permission_denied`, no `Authorization` → 401 at the
      gateway, `grace_days: 999` → 400 with the reason.
- [x] Supports `{"dry_run": true}` so the first real use can be a report.
- [ ] **The purge path itself is unexercised.** There are zero deletion requests
      in production, and testing it needs an admin JWT plus a throwaway account
      the owner creates and deletes. Do that before relying on it, and check
      afterwards: the `auth.users` row gone, the files 404, the queue row
      `purged`.
- [x] **Scheduling — done 2026-09-05 by A32** (pg_cron, daily 03:30 UTC, through a Vault bearer; the function also still takes an admin JWT). The paragraph below is the original reasoning. ~~Scheduling is deliberately not automated.~~ A GitHub workflow would need
      the service-role key in CI, which ADR-0001 forbids; `pg_cron` reading the
      key from Vault would work but the extension is not installed. Run it by
      hand until one of those is decided — at zero requests that is
      proportionate. Procedure in `HANDOVER.md`.

### A8 — Privacy policy live · S · **DONE 2026-09-03**
- [x] Replaced all 8 `TODO(owner)` markers. Operator: **النجوم للتسويق العقاري**, a real-estate office in the Syrian Arab Republic; contact `m.hekmatfanari@gmail.com`; Syrian law governs.
- [x] `tool/build_privacy_site.py` renders both files to `docs/legal/site/`, mirrored to the `gh-pages` branch. It refuses to render a file that still holds a placeholder.
- [x] Live and checked with `curl`: **<https://mhekmatf.github.io/alnujom/>** (ar, authoritative) and **<https://mhekmatf.github.io/alnujom/en.html>** — both 200, no login, no placeholders.
- [x] `app_settings.privacy_url` set; the About page now shows an **الأحكام القانونية** section. `terms_url` deliberately left null — a privacy policy is not terms of service, and the About page correctly hides what is unset. **Terms of service is a separate document nobody has written.**

### A9 — Settings the founder answers, Claude applies · S · **DONE 2026-09-03**
- [x] `default_language` → `"ar"`.
- [x] `support_contact` → phone and WhatsApp `+963991883342`, email `m.hekmatfanari@gmail.com`. Verified on the device: all three rows render on the About page. **The owner says these are provisional — remind him to swap them for business details before launch** (they also appear in the published privacy policy).
- [x] Live values recorded in `HANDOVER.md`, read straight out of `app_settings`
      on 2026-09-04 rather than copied from a migration. The three problems that
      section used to describe are all fixed; the ⚠️ on the provisional contacts
      is stated there, including that changing them means re-running
      `tool/build_privacy_site.py` and pushing `gh-pages`, since they are in the
      **published** policy too.

### A10 — Version manifest · S · **blocked on B5 (the Telegram post URL) only — A3 is done**
- [ ] Write `latest.json` per `docs/release/version-manifest.example.json` with
      `latest_version: "1.1.1"`, **`latest_build: 2003`**, `telegram_url` = the
      post, Arabic + English notes from `docs/release/notes/1.1.1.*.md`.
      **Not `3`.** `PackageInfo.buildNumber` is Android's versionCode, and
      `--split-per-abi` offsets it per ABI — the arm64 APK, the one that gets
      posted, reports **2003**. Writing `3` is invisible today and silently
      disables the prompt for any same-version hotfix. See `v1.0.0.md`.
- [ ] Upload to bucket `app-release`, path `android/latest.json`, via the storage REST API with the service-role key from `.env.admin.json` (never `.env.json`).
- [ ] On a phone still running the old build: cold start → prompt appears → Update opens the Telegram post. This closes `v1.0.0.md` row 233.
- Verified by: the prompt screenshot and the row updated.

### A11 — Demo-data cleanup · S · **blocked on B7 (decision + at least 5 real listings)**
- [ ] Take a backup first (A6, or a manual `pg_dump` if A6 is not live yet).
- [ ] Run PART 1 of `supabase/scripts/pre_launch_data_cleanup.sql`, read the counts, choose the set in PART 2, run PART 3 with its `ROLLBACK`, compare, then `COMMIT`.
- [ ] Guest map + home + search show only the real listings; `get_advisors` unchanged.
- Verified by: the counts before/after appended to the script header.

### A12 — Small hygiene, bundle into any nearby PR · S
- [x] `/publisher/dashboard` — **kept, and now says why in the router.** It has no in-app caller, but it is the canonical publisher-dashboard URL, `specs/035` and `specs/010` both document it, and it is the path prefix of `/publisher/dashboard/my-listings`, which is used. Deleting it would break deep links for no gain.
- [x] `v1.0.0.md` row 171 (new icon + splash in light/dark on device) — done
      during A3 on 2026-09-04, and it did not pass on sight: it found the slab
      behind the emblem and the same slab on the splash. Both fixed and rebuilt;
      the row now records what was wrong rather than a tick.
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

### A14 — Fix what the 2026-09-04 review proved · S · **DONE 2026-09-04**
Two migrations, applied and verified against the live project. Every fix was
re-tested with the same harness that broke it — the `authenticated` role with a
forged JWT claim inside `BEGIN … ROLLBACK`, so nothing persisted (row counts
before and after are identical).

`20260904120001_close_proven_write_holes.sql`:

- [x] `notifications_type_check` widened to twelve types. **This was the one that
      would have bitten first:** `saved_search_match` was rejected, and that
      INSERT happens inside `approve_listing_internal`'s UPDATE, so the first
      saved search would have made listing approval fail. Verified: the INSERT
      that raised `23514` now succeeds. The five A16 types and `listing_expiring`
      were added at the same time, so A16 needs no further migration here.
- [x] `messages`: table-wide UPDATE revoked, `UPDATE (read_at)` granted instead,
      and the policy given a `WITH CHECK` plus `sender_user_id <> auth.uid()` so
      only the **counterpart's** rows can be touched. Verified: the tamper now
      fails with `42501 permission denied for table messages` — refused at the
      grant, before RLS is even consulted. The read receipt and sending still
      work (1 row marked read, 2 messages in the thread).
- [x] `viewings`: both write policies dropped and INSERT/UPDATE/DELETE revoked;
      `request_viewing` and `update_viewing_status` are SECURITY DEFINER and
      unaffected. Verified: the self-confirm now fails with `42501`; the RPC path
      still confirms as the publisher and still refuses the requester with
      "only the publisher can confirm or decline". The INSERT policy went too —
      it checked *who* was inserting but not *what*, so a hand-crafted row could
      arrive already `confirmed`.
- [x] `conversations`: INSERT/UPDATE/DELETE revoked, insert policy dropped. It
      let a caller name any `publisher_user_id`, so a stranger could be opened a
      conversation against. `get_or_create_conversation` derives the publisher
      from the listing.
- [x] `anon` now holds **no** grant at all on those three tables.

`20260904120002_throttle_guest_writers.sql`:

- [x] Hourly ceilings on the three guest-callable writers: `submit_inquiry`
      20/listing and 10/signed-in-sender; `record_lead_event` 60/listing and
      120/user; `record_ad_event` 500/ad and 200/user. Verified: the 21st inquiry
      in an hour raises `rate_limited`, and a valid submission still encrypts the
      phone, writes the lead event and notifies the publisher.
- [x] **Not per-IP, and the reason is recorded in the migration.** All three
      already stored `inet_client_addr()`, and every row ever written says
      `"ip": "::1/128"` — PostgREST's loopback, identical for every caller. A cap
      on that would have throttled the whole internet as one client. See A24.
- [x] `app_client_fingerprint()` added (forwarded header, else NULL) and recorded
      into `metadata->>'client'`, but **not** used as a cap yet — A24.

Client, in the same PR:

- [x] `deleteListing` now appends `.select('id')` and throws when nothing came
      back. A publisher's draft delete matched no DELETE policy, returned zero
      rows and a 2xx, and the bloc reset the form as though it had worked.
- [x] A `rate_limited` inquiry gets its own message in both languages instead of
      the generic "couldn't send", which invited the retry that hits the same
      ceiling.
- Verified by: the six-linter suite green; the four proofs re-run and now
  failing; chat, the thread and the viewings screen opened on the Infinix
  against the **already-installed 1.1.1+3** and all reading correctly — the
  lockdown is server-side, so the build the owner already has is protected by it.


### A15 — Let a publisher close a listing · M · **DONE 2026-09-04**
The biggest functional gap the review found (M1 + M2). `sold`, `rented` and
`paused` existed in the schema and rendered everywhere, but nothing could set
them; and an ordinary publisher could delete nothing at all.

Migrations `20260904120003_set_own_listing_status.sql` and
`20260904120004_relist_sold_listings.sql`, applied and verified in rolled-back
transactions:

- [x] `set_own_listing_status(p_listing_id, p_status)` — owner-checked
      SECURITY DEFINER, `authenticated`-only. Transition table:
      `approved → sold | rented | paused`,
      `paused | sold | rented → approved`,
      `draft | rejected | expired | sold | rented → deleted` (soft).
      Everything else raises `22023`; a non-owner raises `42501`.
- [x] **Sold and rented are not terminal.** The first cut made them so, which
      was wrong for this business — a buyer backs out, a tenant does not sign,
      the wrong button gets tapped — and the only alternative was re-creating
      the listing and queueing for moderation again. Re-listing keeps the
      original approval and `published_at`, so it does not jump the feed.
- [x] **Re-appearing does not re-alert.** `notify_saved_search_matches` fires on
      any `→ approved` transition, so un-pausing or re-listing would have blasted
      every matching saved search, repeatedly if someone toggled. A
      transaction-local GUC (`app.skip_saved_search_alert`) set by this RPC
      suppresses it. Verified both ways: the RPC path is silent, and a genuine
      re-approval by direct UPDATE still produces exactly one alert.
- [x] `pending_review` deliberately offers nothing: a submission under review
      belongs to the moderator until they decide.
- [x] My Listings card: an overflow button opens an action sheet with
      **تمّ البيع / تمّ التأجير / إيقاف مؤقّت / إعادة النشر / حذف الإعلان**,
      each with a one-line explanation of what it does. Delete asks for
      confirmation. 14 new keys in both ARBs plus the `_DebugAppLocalizations`
      overrides.
- [x] The bloc updates the row in place, and drops it from the list when it no
      longer belongs in the current tab. Success and failure use the same
      one-shot-token idiom as Renew.
- [x] Sold / rented / paused listings leave the public surfaces automatically —
      `v_listings_public` filters on `status = 'approved'`. Verified.
- [x] The listing form's "delete draft" now goes through the same RPC instead of
      a raw DELETE that RLS silently refused, and `deleted` rows are filtered out
      of My Listings and out of the dashboard's total count.
- [ ] **⚠️ PARTIAL — the on-device round trip was not completed.** `1.1.2+4` was
      installed on the Infinix and the action sheet was **seen rendering
      correctly** on an approved listing: all three actions in Arabic RTL, each
      with its one-line explanation, icons on the correct side. The owner picked
      the phone up mid-test (another app came to the foreground), so the
      remaining steps were not driven: tap إيقاف مؤقّت → toast → the chip
      changes → the listing leaves guest search → tap إعادة النشر → it comes
      back. Every one of those transitions is proven at the database level; what
      is unproven is the button wiring behind them.
- Verified by: the six-linter suite; four rolled-back proofs (owner path,
  non-owner `42501`, invalid transition `22023`, re-list keeps `published_at`
  and stays quiet); the sheet rendering on `1.1.2+4`. The tap-through round trip
  is still owed — see the PARTIAL line above.


### A16 — Tell people about messages and viewings · M · **DONE 2026-09-04**
Review M4. Six notification types existed and every one was about moderation.
Nothing fired for the two things that actually need a person to come back:
`bump_conversation_last_message` only moved a timestamp, and `request_viewing` /
`update_viewing_status` enqueued nothing at all.

Migration `20260904120005_message_and_viewing_alerts.sql`, applied and verified
in a rolled-back transaction:

- [x] `notify_new_message()` on `messages` AFTER INSERT. The recipient is derived
      from the conversation, never from the payload, so a hand-crafted insert
      cannot address someone else's notification.
- [x] **Debounced.** A conversation is a burst of short messages and one push per
      message would be unusable. It notifies once, then stays quiet until the
      recipient has read it or ten minutes pass. **Verified: three messages in a
      row produced exactly one alert.**
- [x] `request_viewing` → `viewing_requested` to the publisher.
      `update_viewing_status` → `viewing_confirmed` / `viewing_declined` /
      `viewing_cancelled` to **the other party** — confirm and decline are the
      publisher's to make so they reach the requester; cancel can come from
      either side so it reaches whoever did not press it.
- [x] `viewing_cancelled` added to the CHECK: a cancellation leaves the other
      person with a dead appointment in their calendar, which is the same gap
      pointing the other way.
- [x] Payloads carry **UUIDs only** — no message body, no counterpart name. The
      same payload reaches the OS tray, which is readable on a locked screen.
- [x] `dispatch_push` **redeployed (version 5)** with bilingual tray copy for all
      five types, and they join the user-muteable `notif_messages` category
      rather than the always-delivered transactional one. The deployed source
      was read back and matches the repo byte for byte; the endpoint answers
      `401` to an unauthenticated call and `{"code":"unauthorized"}` to a wrong
      token.
- [x] Client: five new `NotificationType` values, tray icons and semantic
      colours (confirmed green, declined/cancelled red), titles in both ARBs
      plus the `_DebugAppLocalizations` overrides, and deep links — a message
      opens `/chat`, any viewing alert opens `/viewings`.
- [x] **`/viewings` is a route now.** It had none: the drawer pushed the page
      directly, so a viewing notification had nowhere to navigate to. It is
      auth-gated exactly like `/chat`, and the drawer goes through the route so
      the two cannot land on stacked copies of the same screen.
- [ ] **⚠️ PARTIAL — no push has been seen landing on a phone.** Everything up to
      the device token is proven: the rows are written, the debounce holds, the
      dispatcher accepts the new types and is live. What is unverified is the
      last hop — FCM to a handset — because it needs two signed-in accounts
      messaging each other. That is the same second account A2 has been waiting
      on; when it exists, this and A2's chat/viewing walk are one test.
- Verified by: the six-linter suite; the rolled-back proof above (1 alert for 3
  messages, `viewing_requested` to the publisher, `viewing_confirmed` back to
  the requester); the redeployed function read back and probed.


### A17 — Bound the map · S · **DONE 2026-09-04** (device walk outstanding)
Review §4 C1. `search_map` had no LIMIT and no bounding box, and the unfiltered
path did not even go through it — the client read `v_listings_map_public` whole.
At 5,000 approved listings that is a ~1 MB payload downloaded, parsed and turned
into 5,000 marker widgets on every map open.

- [x] `20260904120007_bound_the_map.sql` — `search_map` gains `p_min_lat`,
      `p_max_lat`, `p_min_lng`, `p_max_lng` (all default NULL, so a half-box or
      no box still works) and a hard `LIMIT 500`, ordered `published_at DESC`
      so a viewport holding more than the cap keeps the freshest listings.
      Adding parameters is not a replace — the old 16-argument function is
      dropped explicitly, or PostgREST would see two overloads.
- [x] **The box is measured against `marker_lat`/`marker_lng`** — the published
      coordinates, which for an `approximate` listing are the area-centroid
      jitter. Never `listings.latitude/longitude`: filtering on the true
      position would re-open the exact oracle
      `20260902120002_seal_map_jitter_oracle.sql` closed (shrink the box, ask
      again, and the jitter is undone).
- [x] `loadAll()` is gone. Both the filtered and the unfiltered path now go
      through the RPC, so there is no longer a call that can ask for every
      listing in the country.
- [x] The client sends the visible bounds **padded 25%** after the camera has
      been still for 300 ms (`ViewportReporter`, shared by `/map` and the
      search page's embedded map — `onMapEvent` fires on every frame of a drag).
- [x] The BLoC skips the fetch when it already holds a complete, un-truncated
      result covering the new viewport — including the unbounded first load,
      which covers everywhere. **At today's 16 listings the map therefore still
      issues exactly one request and never re-asks.** The handler emits no
      `MapLoading` (that would tear the map down mid-pan), never touches the
      camera, and swallows a failed fetch rather than replacing the map with a
      full-screen error.
- Verified by: the six-linter suite; `search_map()` unbounded returning all 16
  rows exactly as the view does (no regression), a Damascus box 10, a Latakia
  box 1, an off-Syria box 0; the same three calls over PostgREST **with the real
  anon key**, whose JSON carries every key `MapMarkerDto.fromJson` reads; and
  `EXPLAIN (analyze, buffers)`.
- **The measurement is honest about what moved.** Bounded 15.0 ms / 2174
  buffers against unbounded 15.5 ms / 2216 — the same server work, for **6.3 KB
  on the wire instead of 10.1 KB**. The box cuts the payload, not the scan:
  `marker_lat` is computed per row by `listing_marker_coordinates()` in the
  view's LATERAL, so rows are visited before they can be excluded, and Postgres
  will not inline a SECURITY DEFINER function so `EXPLAIN` sees one opaque
  `Function Scan`. The payload is what C1 was about; the scan fix (a coarse
  pre-filter below the LATERAL) is written down in the migration header for the
  day it matters.
- [x] **Walked on the Pixel 8 Pro AVD 2026-09-05, as a guest:** the
      search-and-map tab's map view rendered clusters (4, 10) and pins, and a
      pan across the coast reloaded tiles and kept the markers — no blank map,
      no crash. What a guest walk cannot show is the *network* side (whether
      the pan issued a bounded re-fetch), so the row below stays as the record
      of what is still unmeasured.
- [ ] **⚠️ PARTIAL — the re-fetch on pan is not measured.** The AVD would not stay up this
      session, and the Infinix is the owner's phone carrying the release build
      he is about to publish: a debug install shares `com.alnujom.app` and would
      replace it. What a device would add over the above is the feel of the
      pan/zoom refetch, not its correctness. Fold it into the next device pass.


### A18 — Thumbnails for listing photos · M · **DONE 2026-09-04**
Review P1, and the biggest bandwidth item in the app. Uploads are stored at a
1920-px long edge, ~156 KB average, and every **card** was downloading that full
file — a home feed of twenty is about **3 MB per open**. `memCacheWidth` caps
the decode and Data-saver caps the disk cache; neither caps the transfer.

Measured on the real 51 images: **9,057 KB → 1,234 KB, 87% less.** Over the CDN a
card image is now 27.8 KB where it was 192.7 KB.

- [x] `watermark_pipeline.dart` emits a second JPEG — 480-px long edge, quality
      75 — from the **already-decoded, already-watermarked** pixels, so the
      thumbnail costs no second decode and can never be an un-watermarked copy.
      `ProcessedImage {full, thumbnail}` replaces the bare `Uint8List` through
      the isolate, the use case, the repository and the datasource.
- [x] Uploaded beside the original as `<path>_thumb.jpg` into
      `listing_media.thumbnail_path` (the column already existed for video
      posters). **Best-effort**: a failed thumbnail upload leaves the row's
      `thumbnail_path` null rather than failing the photo.
- [x] `20260904120006_card_images_prefer_thumbnail.sql` — all four card views
      (`v_listings_public`, `v_listings_map_public`, `v_favorites`, `v_reports`)
      now select `COALESCE(thumbnail_path, storage_path)`. Column names, types
      and order are unchanged, and the `security_invoker` reloption is
      re-stated because `CREATE OR REPLACE VIEW` drops it otherwise.
- [x] The three client selects that bypass the views — home feed, conversation
      list, similar-listings rail — request `thumbnail_path` and prefer it.
- [x] **The detail gallery is untouched** and still pulls the full file. Having
      both sizes is the point.
- [x] `tool/backfill_listing_thumbnails.py` — service-role, build-machine only
      per ADR-0001, `--dry-run` first, idempotent, and it survives one bad
      object rather than aborting. **Run: 51 of 51, 0 failed.** Every image row
      now has a thumbnail.
- [x] Storage grew 12 MB → 13 MB. That is the trade: ~1.2 MB stored once
      against 87% off every card view, forever.
- [ ] **The staged revision path still has no thumbnail.** Editing an *approved*
      listing stages images into a manifest that `apply_listing_revision`
      reconciles, and the manifest has no thumbnail slot. Those images fall back
      to the full file through the same COALESCE, so nothing is broken — it is
      the one upload route that does not benefit yet. Widening the manifest and
      the RPC is a follow-up.
- Verified by: the six-linter suite; the backfill's own before/after totals; the
  CDN serving `_thumb.jpg` at 27.8 KB against 192.7 KB for the full file;
  `search_listings` returning `_thumb.jpg` paths; and all 51 rows carrying a
  `thumbnail_path`.

**Live for the build the owner already has.** Search, map, favourites and
reports read their image through the four views, so `1.1.3+5` on the phone is
already downloading thumbnails there without a rebuild. The home feed, the
conversation list and the similar rail need the client change, so those pick it
up in the next build.


### A19 — Page the chat thread · S · **DONE 2026-09-04**
Review §4 C2. `watchMessages` was `.stream().eq(conversation).order(created_at)`
with no limit — the Realtime stream's initial load was the **whole thread**, on
every open, and it stayed resident for as long as the page was up.

- [x] The stream is now a **window**: `.order('created_at', ascending: false)`
      + `.limit(kChatPageSize)` (50). `SupabaseStreamBuilder.limit` applies to
      the initial fetch *and* to every later emit (`sort` then `take`), so the
      window stays pinned to the newest 50 as messages arrive.
- [x] `loadOlderMessages` — a plain `select` with
      `.lt('created_at', cursor).order(desc).limit(50)`, not a second Realtime
      channel: history cannot change (A14 revoked `UPDATE`/`DELETE` on
      `messages` for `authenticated` apart from `read_at`), so a subscription
      would have nothing to deliver. Served by the existing
      `idx_messages_conversation (conversation_id, created_at)` read backwards
      — no new index.
- [x] The cubit holds every message it has shown in a **map by id**, because
      the two sources overlap at the seam and because a message that falls out
      of the fixed-size window as newer ones arrive must stay on screen. The
      window writes over what is there (its rows carry the live `read_at`); a
      fetched page only fills gaps, so a stale history row can never clobber a
      live one.
- [x] The page pages on scroll toward the old end, with a sentinel at the
      visual top: a spinner in flight, a tappable row otherwise — which is
      also the retry after a failed page, and the way forward on a thread too
      short to scroll. `chatLoadEarlier` / `chatLoadEarlierRetry`, both locales.
- [x] `markRead` now fires on a change of **newest id**, not of message count,
      so paging history in no longer sends a pointless read receipt.

**It also fixes a bug nobody had hit yet.** `SupabaseStreamBuilder.order()`
defaults to `ascending: false`, so the bare `.order('created_at')` was already
returning **newest-first** while every comment said oldest-first and the page
then applied `.reversed` on top of a `ListView(reverse: true)`. The thread
rendered **upside down** — oldest at the bottom, newest at the top — from the
second message onward. Nothing caught it because `messages` is **empty in
production**: 1 conversation, 0 messages, and the two-account walk (A2) has
never been run. The whole feature now reads newest-first end to end, and the
page does no re-ordering at all.

- Verified by: the six-linter suite; the `supabase-2.10.6` stream-builder source
  for both the `order` default and the `limit` semantics; and the column grants
  on `messages` (`SELECT` all columns, `UPDATE (read_at)` only), which the plain
  select and `markRead` both depend on.
- **Not verified on a device.** Chat needs two accounts in one thread — that is
  A2, and it is still owner-blocked. This is the one item where the on-device
  walk would tell us something the code cannot.


### A20 — Make shared links open something · S · **BUILT 2026-09-04 — one owner yes from live**
Review §1 M3. Sharing sends `https://alnujom.app/listings/<id>`. The domain does
not resolve, **and the app could not have opened it either**: the only VIEW
intent was the auth callback, and the code comment claiming an https VIEW intent
existed was pointing at a `<queries>` entry, which is the opposite — what the app
may *open*, not what it answers. For an app handed out over Telegram, sharing is
the growth loop, and it produced a link nobody could open.

Both halves are built. Neither is switched on, because the switch is the owner's.

- [x] **The app can open a listing link.** `alnujom://listings/<uuid>` is
      declared in the manifest and read by `DeepLinkListener` off `app_links`.
      **Not** by Flutter's own deep linking — `flutter_deeplinking_enabled` has
      to stay `false` or the router hijacks
      `alnujom://auth/reset-password#access_token=…` and lands the user on the
      request-a-reset page (spec 005 D-01). `resolveDeepLink` returns null for
      `alnujom://auth/...`, so supabase_flutter keeps sole ownership of it.
- [x] A link is untrusted input, so the mapper accepts a closed set: one route,
      an id that must match a UUID, otherwise null. The worst a hostile link can
      do is open the listing page for an id that does not exist.
- [x] **The page those links point at** — `docs/landing/l/index.html`. Reads the
      id, fetches the one row `anon` may already read from `v_listings_public`,
      and shows photo, price, title, location, room/bath/size chips and **Open
      in app**. Same tokens as the privacy pages, so the site reads as one thing.
      The anon key in it is the same one that ships in every APK.
- [x] Verified in a browser against the live database: **found** (light and
      dark), **"no longer available"** for an id the view does not carry (sold,
      paused, expired all land here), **"invalid link"** for a non-UUID, and the
      footer link back to the policy. Seven link forms map correctly and nine
      hostile or malformed ones map to null, including the auth callback.
      Six linters green, and the merged manifest carries both intent filters
      with `flutter_deeplinking_enabled` still `false`.
- [x] **Walked on the Pixel 8 Pro AVD 2026-09-05** (once the port fix in
      `docs/dev/android-emulator-windows.md` brought it back): a debug build,
      `am start -a VIEW -d alnujom://listings/<id>` from the guest home → the
      listing detail page opened directly (title, price, chips, contact row).
- [x] `docs/landing/` is a **tracked source** that `tool/build_privacy_site.py`
      copies into the output. The output directory is gitignored, so a page
      written straight into it would be lost on the next run and never reach
      review — which is also why the README's claim that the rendered pages are
      "committed under `docs/legal/site/`" was never true.
- [ ] **⚠️ Owner — publish the page.** It reaches people only when it is pushed
      to the `gh-pages` branch, which is publishing to a public site and is the
      owner's call, not Claude's. One yes and it is live at
      `https://mhekmatf.github.io/alnujom/l/?id=<listing>`.
- [ ] **⚠️ Then flip `_shareLinkBase`** in `per_listing_action_block.dart` from
      the dead `https://alnujom.app` to that base. Deliberately NOT changed yet:
      pointing it at an unpublished page would trade one dead link for another.
      It needs a new build to reach users either way.
- [ ] **B5 — the Telegram post URL** fills `TELEGRAM_URL` in the page, and the
      "download the app" button appears. While it is empty the button simply
      does not render, rather than sending anyone to a dead link.
- [ ] **B16 — the real domain** replaces the base again and adds the `https`
      intent filter with `android:autoVerify="true"` plus
      `/.well-known/assetlinks.json`. Without verification Android shows a
      chooser instead of opening the app, and a GitHub *project* Pages site
      cannot serve that file at the host root — which is why no https filter is
      declared yet. `resolveDeepLink` already accepts both the `?id=` form a
      static host can serve and the `/l/<id>` path form a real domain can, so
      old links keep working across the move.


### A21 — A tile provider that allows apps · S · **blocked on B17 (a key)**
Review §4. Swap the three `urlTemplate`s for the provider's URL with the key
from `.env.json` (a new dart-define, never committed). Keep the OSM attribution.

### A22 — Stop the audit log eating the database · S · **DONE 2026-09-04**
Review §4 C3. Measured before the change — 1,410 rows / 1,576 kB:

| action | rows | bytes each |
|---|---|---|
| `listing.updated` | 247 | 1,861 |
| `listing_media.updated` | 130 | 939 |
| `listing_media.created` | 95 | 538 |
| `listing.created` | 73 | 957 |
| `listing.approved` / `.rejected` / `.submitted` / `.paused` | 44 | ~1,850 |

Reading it turned up **two causes the review had not separated**, both bigger
than the one it named:

- [x] **Every listing UPDATE stored the whole row twice** — `to_jsonb(OLD)` and
      `to_jsonb(NEW)` — so changing one price cost 1.9 KB. It now stores only
      the keys that differ. Easier to read, too: the admin viewer shows what
      changed instead of two near-identical blobs to diff by eye.
- [x] **A status change wrote the same thing twice.** `listing.updated` fired,
      then `listing.approved` fired carrying an identical pair of snapshots. One
      row now, under the status verb when there is one — the generic verb is the
      fallback, not an extra.
- [x] **The three row-level `listing_media` triggers are dropped** (the item as
      written). One audit row per photo insert/update/delete, whole row each
      way, for machine noise — A18's thumbnail backfill alone wrote 51
      `listing_media.updated` rows for a column no human set. Media stays
      auditable through the listing and through `listing_revisions`, which is
      what an admin actually reviews. The three *functional* triggers on that
      table (ordering, the media cap, `updated_at`) are untouched.
- [x] A no-op UPDATE no longer writes an audit row at all.
- [x] `purge_audit_logs(p_retain interval default '180 days')` — SECURITY
      DEFINER, `EXECUTE` revoked from PUBLIC/anon/authenticated, returns the
      count deleted, and **refuses any retention under 30 days** so a
      fat-fingered `interval '0'` cannot empty the table.
- Verified in a rolled-back transaction on a real listing:

  | change | before | after |
  |---|---|---|
  | title edit | 1 row, 1,861 B | **1 row, 584 B** (`title`, `search_vector`, `updated_at`) — 69% less |
  | status change | 2 rows, ~3,682 B | **1 row, 176 B** (`status`) — 95% less |

  Plus: the three media triggers gone and the three functional ones still there;
  `anon`, `authenticated` and `PUBLIC` all denied EXECUTE on the purge; and
  `purge_audit_logs(interval '0 days')` rejected while the row count stayed at
  1,410.

**Nothing was deleted.** `purge_audit_logs()` at its default returns **0** today
— the oldest audit row is 2026-05-09, so nothing qualifies until 2026-11-05.

- [x] **Scheduled 2026-09-05 by A32** (weekly, Sunday 04:00 UTC, 180-day retention). ~~Owner decision — schedule it, or run it by hand?~~ `pg_cron` 1.6.4 is
      available on this project but not installed, and the plan defers that to
      the owner along with A7's. The one-liner for both is in the migration
      header. Until then the retention exists but never runs, and the table just
      grows more slowly.


### A23 — Filter the publisher dashboard's Realtime subscription · S · **DONE 2026-09-04**
Review §4. `subscribeTables(['listings','inquiries'])` was unfiltered, so every
write in the system woke every open dashboard — a Realtime message each, and an
RLS check per subscriber per event.

**The `inquiries` half was not merely unfiltered — it had never delivered
anything**, for two independent reasons:

1. `public.inquiries` is **not in the `supabase_realtime` publication**, so no
   change on it was ever published. (`listings`, `reports`, `messages`,
   `user_roles` and `conversations` are; `inquiries` and `notifications` were
   not.)
2. The table carried **no column naming the publisher** — only `listing_id` —
   so the client could not have narrowed the subscription even if events had
   arrived.

A publisher's counter has therefore never moved when an inquiry landed. It moved
on the next manual refresh, or on the channel's resubscribe reconcile.

- [x] `20260904120009_filter_the_publisher_dashboard.sql` — `inquiries` gains
      `publisher_user_id`, **derived, never client-supplied**: a
      `BEFORE INSERT OR UPDATE OF listing_id` trigger recomputes it from the
      listing and overwrites whatever arrived, which is what makes it safe to
      hang RLS on. Backfilled, `NOT NULL`, indexed `(publisher_user_id,
      created_at DESC)`.
- [x] `inquiries_select_publisher` and `inquiries_update_publisher` drop their
      `EXISTS (SELECT 1 FROM listings ...)` for one column comparison — the
      same rows, and that join was the per-event cost Realtime pays for every
      subscriber, not just on a page load.
- [x] **`REPLICA IDENTITY FULL` on `listings` and `inquiries`.** A filter on a
      non-PK column needs the old row to decide whether a subscriber could see
      the record before the change; with the default identity the old record is
      the primary key alone, so filtered UPDATE/DELETE events are silently
      dropped while INSERT keeps working — which is exactly how this hides.
      Same lesson as `user_roles` and `messages`, both already FULL. The cost is
      the whole old row in the WAL per UPDATE, which is the right trade on two
      low-write tables and would not be on a hot one.
- [x] `inquiries` added to the `supabase_realtime` publication.
- [x] `subscribeTables` now takes `List<RealtimeTableWatch>` —
      `.all(table)` or `.where(table, column:, value:)` — and the filter values
      are part of the channel name, so two dashboards open for different
      publishers cannot land on the same topic. The publisher cubit narrows both
      bindings to its own `publisher_user_id` and **does not open a channel at
      all when signed out**; the admin dashboard stays `.all` on purpose (a
      handful of admins, and they moderate everything).
- [x] The user id reaches the cubit through `PublisherDashboardRepository
      .currentUserId`, the same seam `ChatRepository` already opens for
      `isMine` — no SDK in a bloc.
- Verified: six linters green; the trigger **overwrote a deliberately forged
  `publisher_user_id`** on insert; the new policy proven both ways in a
  rolled-back transaction with `set local role authenticated` — the listing's
  publisher sees the inquiry (1), another authenticated user does not (0); both
  tables report `full` replica identity and `inquiries` is now in the
  publication.
- [ ] **⚠️ PARTIAL — the live channel is not walked on a device.** `inquiries`
      is empty in production (0 rows) and the AVD will not start (see
      `docs/dev/android-emulator-windows.md`), so "an inquiry arrives and the
      counter moves without a refresh" is unproven end to end. Everything it
      depends on — publication, replica identity, RLS, the filter column — is
      proven server-side. Fold into the next device pass.


### A24 — Sharpen the throttle to a real client key · S · after one real device use
A14's caps are per-listing and per-user because no per-caller key was available:
`inet_client_addr()` is `::1` for every PostgREST request. `app_client_fingerprint()`
now records the forwarded header into `metadata->>'client'` on every inquiry, lead
event and ad click.

- [ ] After the next real use from a phone, read it:
      `select metadata->>'client' from public.lead_events order by created_at desc limit 5;`
- [ ] If it is a real address, add a per-fingerprint cap to the three functions
      and an index on `((metadata->>'client'), created_at desc)`.
- [ ] If it is still null, the gateway strips the header — record that and leave
      the per-listing caps as the answer.

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
| **B14** | **Decide the photo-bucket stance.** Photos of rejected / deleted / pending listings are downloadable by anyone who has the URL (review §2 S3). Paths are unguessable and the purge removes them after account deletion. **Accept** (recommended: simplest, fastest, what every listings site does) or **make the bucket private** (every image URL becomes a signed URL — slower first paint, and cache-unfriendly). | Today's behaviour contradicts what the July audit told you. | decision |
| **B15** | **Budget for the Pro plan (~$25/month) at about 1,000 listings.** Storage (1 GB) is the first wall, egress (5 GB/month) the second, Realtime connections (200) the third; Pro removes all three and adds daily backups and image resizing (review §4). | Otherwise the app stops accepting photos one day with no warning. | decision + card |
| **B16** | **A domain** for shareable links — `alnujom.app` is unregistered and every share today is a dead link (review §1 M3). Any registrar; ~$15/year. Send the name and I wire it (A20). | Sharing is the growth loop for a Telegram-distributed app. | 15 min |
| **B17** | **A map-tile account** (MapTiler or Stadia Maps, both have a free tier) and its key, into `.env.json` on the build machine, never in chat. OpenStreetMap's own servers forbid being an app's default tile source (review §4). | A blank map the day the app gets traffic. | 10 min |

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

Launch = A3 posted (B5), A9 and A8 done, A11 done, B1 done, **and A14 applied**
(without it the first saved search breaks listing approval). Everything else
can follow it.

**Added 2026-09-04 (section E):**

```
now ──► A14 fixes (proven bugs) ──► A15 close a listing ──► A16 message/viewing alerts
        A17 map bounds · A18 thumbnails · A19 chat paging · A22 audit retention ── any time
B16 domain ──► A20 share links        B17 tile key ──► A21 tiles
B14 bucket stance (decision only)      B15 Pro plan at ~1,000 listings
```

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

## E. What the 2026-09-04 full review adds

The review asked four questions — complete? secure? fast? scales? — and answered
each from the live project, with every claim that could be run, run. The
queue items are A14–A23 above and B14–B17; the evidence and the proofs are in
[`REVIEW_2026-09-04.md`](REVIEW_2026-09-04.md). In one line each:

- **Not complete:** a publisher cannot mark a listing sold / rented / paused,
  cannot delete (the draft delete silently fails), shared links point at an
  unregistered domain, and nobody is notified of a new message or a viewing
  request.
- **Not fully secure:** chat messages can be rewritten by the other party and
  a viewing requester can self-confirm (both proven, both one migration to
  close); photos of unapproved listings are public by URL (owner decision).
- **Fast today:** 1.98 s cold start, 69 ms search; images are the drag.
- **Scales in code, not in plan:** two unbounded queries and the audit log
  need fixing; the Free plan's 1 GB storage and 5 GB egress are the real
  ceilings at roughly 1,000 listings.
- **One latent bug:** the notifications CHECK constraint rejects the
  saved-search alert type — the first saved search will make listing
  approval fail. A14.

---

## F. What the 2026-09-05 gap review adds — PROPOSED, nothing started

The founder asked for three things and no execution: is anything still
unverified, did we forget anything, and what does the app lack. The evidence is
[`REVIEW_2026-09-05.md`](REVIEW_2026-09-05.md); this section is the queue it
proposes. **None of A25–A40 has been started.** Sizes: S under half a day,
M a day or two; one PR each.

**Found and not previously recorded:** orphaned files are **57% of storage**
(29 images + 2 videos, 12.5 MB, from pre-A15 hard deletes, replaced photos and
one failed video upload); **every public listing goes dark on 2026-10-06**
(all 16 carry that `expires_at`); new listings never expire because nothing
writes `expires_at` at approval; the backup workflow **keeps no file** without
`BACKUP_PASSPHRASE`; the live update manifest is a June placeholder
(`1.1.0` / build `1` / `t.me/alnujom`).

### Tier 1 — before the first real users

- [x] **A25 — Storage hygiene** · **BUILT + DEPLOYED 2026-09-05**, migration
      `20260905120002` applied, edge function `sweep_storage` v1 live. Two
      read-only lists in the database (`list_orphan_media_objects`,
      `list_purgeable_listing_media` — objects no media row references, and the
      media of listings soft-deleted more than 30 days ago whose owner has no
      pending account purge) and one function that removes the files and then
      the rows, files first. **Dry run through the scheduler's own path**
      (pg_cron → pg_net → Vault bearer → function → RPCs): `200`, caller
      `scheduler`, **31 orphans / 12.8 MB found, 0 removed**, 0 deleted-listing
      media. A replaced photo's original is caught by the same sweep after its
      7-day grace, so the client was not changed. **The first real run is the
      scheduled one, Sunday 2026-09-07 04:30 UTC (A32)** — it is a delete, so
      the owner can stop it before then with
      `SELECT cron.unschedule('housekeeping_storage_sweep');`, or ask for it
      sooner.
- [x] **A26 — Listings expire, publisher hears first** · **DONE 2026-09-05**,
      migration `20260905120001` applied. **F1 answered by making it a setting:**
      `listing_validity_days` (60 by default, 7–365, editable from Admin →
      Settings → Listing Defaults). First approval and a lapsed relist stamp
      `expires_at`; `renew_listing` defaults to the setting, is limited to
      `approved`/`expired`, and brings an `expired` listing back.
      `sweep_listing_expiry()` (hourly under A32) warns 3 days out with
      `listing_expiring` — once per expiry date — and flips lapsed rows to
      `expired` with `listing_expired`; both types are in the CHECK, the app
      (tile, body, deep link to My Listings) and the push copy. The client no
      longer hard-codes 30 days on Renew. **Proven in a rolled-back
      transaction:** approve → `+60d`; sweep at 2 days out → `warned=1`, again
      → `warned=0`; past date → `expired=1`, status `expired`, one
      `listing_expired` row; owner renew → `approved +60d`; a stranger →
      `42501`. The 2026-10-06 cliff stands for the demo rows by design (B7).
      Not walked on a device (no publisher account on the AVD).
- [ ] **A27 — Terms of service** · M. AR + EN beside the privacy policy,
      `terms_url` set, acceptance checkbox at sign-up with the timestamp on the
      profile. Needs B4 facts and the owner's yes on the text and on publishing.
- [x] **A28 — Throttle chat and posting** · **DONE 2026-09-05**, migration
      `20260905120004` applied. `messages`: 60 per conversation per hour, 120
      per sender per hour (BEFORE INSERT; new index on sender + created_at,
      which was also an unindexed FK). `listings`: 20 drafts per publisher per
      hour (BEFORE INSERT). `submit_listing`: 10 per hour, 30 per day, counted
      from the status history. All raise `rate_limited` / 23514 like the guest
      throttle. **Proven, rolled back:** as the buyer, 60 messages land and the
      61st is refused; as a publisher, 20 drafts land and the 21st is refused.
- [x] **A29 — Suspend, block, report a person** · **DONE 2026-09-05**, migration
      `20260905120005` applied. **Block:** `user_blocks` (no client grants;
      RPCs `block_user` / `unblock_user` / `list_my_blocks` /
      `is_user_blocked_by_me`); a block in either direction closes the
      `messages` insert policy, `get_or_create_conversation`, `request_viewing`
      and `submit_inquiry`. In the app: the chat thread's ⋮ menu (report /
      block / unblock), a banner while a block stands, and Settings → Blocked
      users. **Report a person:** `reports.target_user_id` (exactly one of
      listing / user), three new reasons, `submit_user_report`, `v_reports`
      LEFT-joins the listing and carries `target_user_name`; the report sheet,
      My Reports and the admin queue render both kinds. **Suspend:**
      `moderate_user(user, suspend|reinstate)` gated on `users.suspend` — both
      statuses to `suspended`, approved listings paused, sessions ended, one
      `moderation_actions` row, `account_suspended` / `account_reinstated`
      notifications (in the CHECK, the app and the push copy); the admin
      queue reaches it as the `suspend_user` resolution on a report about a
      person or a listing (its publisher). `resolve_report` v4, `dispatch_push`
      v7. **Proven, rolled back (19 checks):** block → message `42501`,
      conversation and viewing `user_blocked`; unblock → message lands; second
      report `23505`; the reporter sees the person's name in `v_reports`;
      `suspend_user` → `suspended/suspended`, `approved_left=0 paused=1`, the
      moderation row, the notification; double suspend `invalid_transition`;
      reinstate through the public RPC; a holder of no `users.suspend` →
      `permission_denied`. Not walked on a device (needs two accounts).
- [x] **A30 — Offline and timeouts** · **DONE 2026-09-05.** One
      `TimeoutHttpClient` handed to `Supabase.initialize(httpClient:)` puts a
      deadline on every REST / auth / functions call (20 s) and every Storage
      call (3 min for a photo body) — a dead connection now ends in the
      existing error state with Retry, not a spinner. `connectivity_plus`
      (7.3.1) feeds a `ConnectivityCubit`; `OfflineBanner` sits above the whole
      navigator and shows the until-now-unused `errorOffline` copy while no
      network interface is up. The auth bloc now tells a session that lapsed
      apart from a sign-out that was asked for (`Unauthenticated.reason`), and
      the sign-in screen says so once — "your session expired" online, "no
      connection" offline — instead of a silent bounce. Not walked on a
      device: the offline strip and the timeout need airplane mode on the AVD
      (next walk); the expired-session notice needs a session to lapse.
- [x] **A31 — Forced-update floor** · **DONE 2026-09-05.** The repository
      compares the installed build to `min_supported_version` (only when a
      newer build exists — a floor above the latest is a manifest mistake and
      must not lock anyone out); below it the prompt has no "later", no back
      (`PopScope`), a body that says the version is no longer supported, and an
      Update button that opens the post and leaves the dialog up. `latest.json`
      needs no new field: `min_supported_version` has been in the schema since
      Phase 24 and was parsed and ignored. Not walked on a device (needs a
      manifest with a floor above the installed build).
- [x] **A32 — Schedule the recurring jobs** · **DONE 2026-09-05**, migration
      `20260905120003` applied: `pg_cron` 1.6.4 installed, four jobs (UTC):
      `housekeeping_listing_expiry` hourly at :10 · `housekeeping_audit_purge`
      Sun 04:00 (180-day retention) · `housekeeping_account_purge` daily 03:30
      · `housekeeping_storage_sweep` Sun 04:30. The two edge functions are
      called through `pg_net` with a Vault secret (`housekeeping_token`,
      generated in the database, compared there by
      `housekeeping_token_matches()`); `purge_deleted_accounts` v2 accepts it
      beside an admin JWT. The service-role key never moves (ADR-0001).
      **No token sweep** — `notification_tokens` has only `created_at` and the
      app does not refresh it, so an age cut would delete live tokens; FCM
      already tells the dispatcher which ones are dead. Taken as the owner's
      "كمل كلشي" of 2026-09-05; every job can be stopped with
      `cron.unschedule(name)`.
- [x] **A33 — Arabic completeness** · **DONE 2026-09-05** (F2: in the
      database). Migration `20260905120006` adds `permissions.description_ar`
      and seeds all 24; the role editor shows it on an Arabic screen, English
      otherwise, the key last. The audit-log viewer no longer prints
      `listing.approved` and `listings`: 19 entity + 18 verb labels in both
      languages, composed as "إعلان: تمت الموافقة عليه", raw id for anything
      new. Every Arabic date in the app now says حزيران, not يونيو — one
      in-place patch of intl's `ar` symbol table (`ensureLevantineArabicDateSymbols`,
      re-applied from the app shell on each build because the localizations
      delegate rewrites the table on locale load) rather than twenty call
      sites. The two bare ISO dates (My Listings card, hide-until picker) go
      through `DateFormat` now. The English bottom-nav label is "Search" and
      the create-listing toggles are one word each, so nothing truncates.
      Digits stay Western on purpose. Not walked on a device (the admin screens
      need an admin sign-in).

### Tier 2 — first weeks after launch

- [ ] **A34 — In-app feedback** · S–M. A "report a problem" sheet under
      About, a `feedback` table, admins notified, build attached.
- [ ] **A35 — Usage analytics and view counts** · M. Funnel events on the
      existing seam; a deduplicated `listing_views` counter on the publisher
      card.
- [ ] **A36 — Page the last two lists** · S. Viewings, approvals queue; CRM
      timeline "load more".
- [ ] **A37 — Accessibility pass** · M. Label every icon-only control; a
      TalkBack walk of the ten main screens (needs a device).
- [ ] **A38 — Data export** · S–M. "Download my data" through an edge
      function with the caller's own token. Play prerequisite.
- [ ] **A39 — Dark map tiles** · S. After B17.
- [ ] **A40 — Manifest guard** · S. With A10: refuse to upload a
      `latest.json` whose `latest_build` is lower than the current.
- A13 stands as written (dependency majors, FK indexes + policy consolidation,
  the 13 tests, REVIEW.md batch-2, Reels entry, `pg_net` schema).

### Tier 3 — decisions, not work

WhatsApp phone verification; Reels at ~10 videos (B13); Google Play (B9);
Pro at ~1,000 listings (B15); a real model behind the assistant; agency-shared
CRM; video poster frames; the `REVIEW.md` §5 polish backlog.

### Founder, ranked by what it unblocks (review §7)

1. **A second test account**, signed in once by you on a second device
   (Claude may not type a password) → twelve unverified rows, issue #39, the
   three PARTIAL marks on A15/A16/A23.
2. **B5** the Telegram post → A10, the update-prompt test, A5, the share
   page's download button.
3. **B1** SMTP → password recovery for real users.
4. **`BACKUP_PASSPHRASE`** (A6) → the weekly backup starts keeping files.
5. **Answers still open:** publish the share page (A20) · B7 demo data ·
   B14 bucket. Settled 2026-09-05 by "كمل كلشي": A32 scheduled, **F1** is
   a setting (60 days), **F2** the database.
6. **B4** legal facts → A27 and the policy's placeholders. **B3** real
   support channels. **B16** domain, **B17** tile key. **B10/B11/B12** the
   safety nets. Later: B9, B15, the logo, REVIEW.md's questions.

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
