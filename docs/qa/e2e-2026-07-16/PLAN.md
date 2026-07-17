# Fix Plan — E2E QA (2026-07-16) — v2, implementation-ready

Prioritized, actionable plan derived from [FINDINGS.md](FINDINGS.md). **v2 (2026-07-17):** every finding was re-verified against the live DB + current code during a plan-review pass — root causes pinned to exact files/lines, the view-grants hole widened from 2 to **11 views**, the schema drift widened to **6 missing migration files**, five findings that had no plan line were added (DATA-1, SEC-M2, SEC-I1, PERF-M4, PERF-L6), and an execution guide was added so an implementing session can start without re-deriving anything.

**How the testing was done:** the real release build was driven on the Pixel 8 Pro emulator like a human user — onboarding, signup, login, search, listing detail, favorites, create-listing, admin approvals, chat — and every write was checked against the live Supabase database. In parallel: a security audit and a performance audit. What already works is logged at the bottom of FINDINGS.md; below is only what needs action.

---

## How to execute this plan (read first)

1. Merge (or rebase past) docs PR **#95**, then branch **`036-qa-fixes`** off `main`. **ONE PR** for the whole fix batch, per `docs/AI_AGENT_WORKFLOW.md`.
2. Work in waves, in order — each wave is independently shippable:
   - **Wave 1 — DB only, no app rebuild:** items **1 → 2 → 3** (+ the SEC-L1 dashboard toggle from item 20). Verify via SQL/REST probes + a quick AVD smoke.
   - **Wave 2 — client quick wins (XS/S):** items **5, 6, 7, 8, 11, 14** (+ UX-5 app label, same manifest as 14).
   - **Wave 3 — the M-sized client fixes:** items **4, 9, 10, 12, 13**.
   - **STOP → founder review + re-QA walk** (light/dark × ar/en on the AVD), then **Wave 4 — P2** on approval.
3. Non-negotiable project rules are in **“Execution rules”** at the bottom — read them before touching anything.
4. Defaults for the open product decisions are pinned in **“Pre-answered decisions”** — implement the default unless the founder overrides.

---

## 🔴 P0 — Fix before launch (security + broken core flows)

| # | Issue | Why it matters | Where | Effort |
|---|---|---|---|---|
| 1 | **SEC-H1 + SEC-M1: 11 public views grant INSERT/UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGER to anon and/or authenticated.** `v_agencies` proven exploitable live (anyone can self-create a pre-`approved` agency, bypassing approval; authenticated can tamper existing rows). | RLS-bypass write path on the agency approval workflow + the same latent class on 10 more views. | One migration revoking client writes on ALL public views | S |
| 2 | **DB-1: schema drift — SIX applied migrations have no file in the repo** (5× Phase-035 + 1× Phase-026). Includes the live 29-arg `search_listings`. | A DB rebuild from migrations silently loses search filters + verification columns/RPCs. Blocks reviewing fix #3. | `supabase/migrations/` — reconstruct from live DB, commit-only | S–M |
| 3 | **FUNC-H1: price filter ignored unless BOTH min and max are set** (proven live: `min=1,000,000` returned 16 rows instead of 0). | "Under $X" / "at least $X" is the most common real-estate search; it silently returns everything. | `search_listings` price predicate — new migration on top of #2 | S |
| 4 | **FUNC-H3: chat thread doesn't show your just-sent message** until you leave and re-enter ("no messages yet" after a successful send). | Core messaging looks broken to the sender → re-sends, lost trust. | `chat_thread_cubit.dart` (optimistic append) + realtime delivery check | M |
| 5 | **FUNC-H2: create-listing shows the raw code `listing_media.images_below_minimum`** in the submit-error dialog. | Looks broken on the primary publishing flow. | `submit_failure_dialog.dart` — 2 missing switch cases (l10n string already exists) | XS |

### P0 item details + acceptance checks

**1 — Revoke client write grants on all public views** (SEC-H1 + SEC-M1 + the write-half of SEC-M2)
- New migration (also **apply via MCP** — see Execution rules):
  ```sql
  revoke insert, update, delete, truncate, references, trigger
    on public.v_ads_serving, public.v_agencies, public.v_favorites,
       public.v_inquiries_inbox, public.v_lead_events_admin,
       public.v_lead_events_publisher, public.v_listings_map_public,
       public.v_listings_public, public.v_publisher_listings,
       public.v_publisher_ratings, public.v_reports
    from anon, authenticated;
  ```
- Safe by construction: verified the app NEVER writes through a `v_*` view (all writes go through RPCs or RLS-gated base tables); server triggers/Edge Functions are unaffected.
- **Accept when:** the grants sweep returns 0 rows — `select g.table_name, g.grantee from information_schema.role_table_grants g join information_schema.views v on v.table_schema='public' and v.table_name=g.table_name where g.table_schema='public' and g.grantee in ('anon','authenticated') and g.privilege_type <> 'SELECT';` — AND an anon REST `POST /rest/v1/v_agencies` now fails with permission-denied (was: reached the base-table constraints). AVD smoke: home/search/map/favorites/ads/reports/publisher screens still load (they only SELECT).

**2 — Reconstruct the 6 missing migration files** (DB-1)
- Missing from `supabase/migrations/` but live in the tracker: `035_add_deed_finish_verification_columns`, `035_expose_deed_finish_verification_in_public_view`, `035_search_listings_deed_finish_verified_filters`, `035_admin_set_listing_verification_rpc`, `035_revoke_anon_admin_verification`, `20260608160001_search_owner_agency_filter`.
- Reconstruct content from the live DB (`pg_get_functiondef`, `pg_get_viewdef`, `information_schema.columns`) into properly-named files. **Commit-only — do NOT re-apply** (they're already live; MCP `apply_migration` would re-run the SQL and duplicate tracker rows).
- **Accept when:** a tracker-vs-repo name diff shows no missing entries (ignoring the known historical duplicate tracker rows), and the committed `search_listings` file matches the live 29-arg definition.

**3 — Fix the single-bound price predicate** (FUNC-H1 / DB-2)
- New migration, `CREATE OR REPLACE` on top of the #2 baseline. Replace (for USD and the SYP pair):
  ```sql
  -- BROKEN: (p_price_min_usd is null or p_price_max_usd is null or v.primary_amount between p_price_min_usd and p_price_max_usd)
  and (p_price_min_usd is null or v.primary_amount >= p_price_min_usd)
  and (p_price_max_usd is null or v.primary_amount <= p_price_max_usd)
  ```
- ⚠️ Pull the FULL live def first (`pg_get_functiondef`) and change ONLY the price predicate — preserve the currency scoping and all 29 args exactly (Phase-031 lesson).
- **Accept when:** `select count(*) from search_listings(p_price_min_usd => 1000000)` = **0** (was 16); both-bounds queries return the same results as before; in the app, a min-only or max-only price filter visibly narrows results.

**4 — Chat: sender sees their message immediately** (FUNC-H3)
- Verified: `ChatThreadCubit.send()` deliberately doesn't append (relies on the Realtime echo, which never arrived); `messages` IS in the `supabase_realtime` publication, so the gap is delivery-side (check `get_logs(realtime)` / socket auth while here).
- Fix (a): optimistic append in `chat_thread_cubit.dart` — on send-success emit the local message; reconcile with the stream by id (no duplicate bubble when the echo does arrive). Fix (b): 2-account live-delivery test for INBOUND messages (deferred Phase-026 QA) — receiving depends on the same stream.
- **Accept when:** on the AVD, sending in a fresh conversation renders the bubble immediately (no leave/re-enter), the DB has exactly one `messages` row, and a 2-account test shows the receiver getting it live (or the realtime root cause is documented + fixed).

**5 — Map the photo-minimum error code** (FUNC-H2)
- `submit_failure_dialog.dart` → add `case 'listing_media.images_below_minimum': return l10n.submitErrorImagesBelowMinimum;` to `_labelForPath()` (string already in ar+en ARBs) and map the same path to the media step in `_stepForPath()`. Audit the other `submit_listing` codes against the switch.
- **Accept when:** 0-photo submit shows "لازم صورة واحدة على الأقل" (Arabic) / the English string (English), and "Jump to step" lands on الصور والفيديو.

---

## 🟠 P1 — Strongly recommended before launch (functional + UX correctness)

| # | Issue | Why it matters | Where | Effort |
|---|---|---|---|---|
| 6 | **FUNC-M1: favorites cards never show the property photo.** `v_favorites.main_image_path` (a storage path) is passed straight to the image widget; Home/Search/Chat all resolve `getPublicUrl` first. | Favorites looks broken though data is fine. | `supabase_favorites_datasource.dart:72` — resolve like `supabase_chat_datasource.dart:72` / home `:147` (http passthrough incl.) | S |
| 7 | **FUNC-M2: "area" labeled "(اختياري)" but required on submit.** Server (`submit_listing`) requires `listings.area_id`; the label comes from the SHARED `location_picker.dart:165` (`locationPickerSelectArea`), which is also used in search where optional is TRUE. | User blocked by a field they were told is optional. | **Default (D1): keep required, fix the label in the form context** — add a required-flag to the picker (form: no "(اختياري)" + red "مطلوب" chip; search: unchanged). | S |
| 8 | **FUNC-M3: photos required (min 1) but the section has no required marker.** | Users learn it's mandatory only at rejection. | `step_media.dart:73` — required chip + "min 1 photo" hint (new ARB key → needs `_DebugAppLocalizations` override) | S |
| 9 | **UX-7: approval card shows nothing when profile name+phone are null** (admin approves blind). Datasource embeds `profiles(phone,email,full_name)` — all null for the older account. | Admins can't tell who they're approving. | (a) one-off backfill of null `profiles.phone/email` from `auth.users` (synthetic-email parse); (b) UI fallback chain phone → email → user-id in `account_approvals_page.dart` | S–M |
| 10 | **UX-1 / PERF-M3: notification-permission dialog over a black screen before any branding.** | Terrible first impression + slows cold start. | `main.dart:131-137` — **keep the guarded `Firebase.initializeApp()` where it is** (DI registers `PushMessagingService` before `configureDependencies()` — moving it breaks the graph); move ONLY `requestPermission()` post-first-frame, ideally behind a soft pre-prompt | S–M |
| 11 | **UX-2: login + register show the old placeholder star.** It's literally `Icons.star` in the shared scaffold. | Inconsistent branding on the highest-intent screens. | `dc_auth_scaffold.dart:48` — swap the icon block for the brand mark onboarding uses (one fix covers both pages) | S |
| 12 | **UX-6: back-press silently discards the half-filled create form** (a server-side draft IS saved, but the user isn't told and can't obviously resume). | Lost work / confusion. | create-form page — `PopScope` keep/discard dialog + "saved as draft" affordance + a drafts entry in "my listings" | M |
| 13 | **SEC-M3: 29 SECURITY DEFINER functions carry default `anon` EXECUTE** (fail closed today; known footgun). | Defense-in-depth. | Migration: revoke anon EXECUTE on all except the deliberate public set (`submit_inquiry`, `record_ad_event`, `search_listings`, `search_map`, `list_video_reels`, market stats). Enumerate: `select p.proname from pg_proc p where p.pronamespace='public'::regnamespace and p.prosecdef and has_function_privilege('anon', p.oid, 'execute')` | S–M |
| 14 | **SEC-L5: `allowBackup` defaults to true** → session tokens extractable via `adb backup` on some devices. | Session theft. | `AndroidManifest.xml:14` — `android:allowBackup="false"` (fix UX-5's lowercase `android:label` on line 15 while here) | S |

---

## 🟡 P2 — Performance & hardening (before or shortly after launch)

| # | Issue | Why | Where | Effort |
|---|---|---|---|---|
| 15 | **PERF-H1 + PERF-M4: Home feed not virtualized** (`SingleChildScrollView`+`Column`, `home_page.dart:227`; no `buildWhen`; whole-page `setState` on segment toggle `:234`). | Jank + growing memory on the main screen; worst on Infinix Note 8. | `CustomScrollView` + `SliverList.builder` (crown/rails as leading slivers); scope the segment toggle rebuild. | M |
| 16 | **PERF-H2: full-size images decoded into small cards** (600px cap only under Data-saver, `app_network_image.dart:67-68`). | Decode jank + memory pressure; compounds #15. | Add `targetWidth` param; always set `memCacheWidth` at card call sites. | S–M |
| 17 | **PERF-H3: `search_listings` text search can't use any index** (cross-table OR defeats the GIN; no pg_trgm). | Search latency grows linearly with listings. | Fold description into `search_vector`, or pg_trgm + trigram GIN + restructure. Coordinate with #3 (same function). | M |
| 18 | **PERF-M1/M2: 63 per-row `auth.uid()` re-evaluations + 27 duplicate permissive policies** on hot feed tables. | Per-row CPU on every feed/search. | Wrap as `(select auth.uid())`; merge duplicate policies (advisor-guided). | M |
| 19 | **PERF-M5 + L1/L2: 90 MB APK; no minify/shrink/ABI-split; ~4 MB dead fonts+assets.** Release block (`build.gradle.kts:72-79`) sets only signing. | 2–3× larger Telegram download than needed. | `isMinifyEnabled`+`isShrinkResources` + `--split-per-abi`; prune Cairo/IBMPlex fonts + unused `assets/branding/` from `pubspec.yaml`. | S–M |
| 20 | **SEC-L1/L2/L3/L4:** leaked-password protection off (dashboard toggle — do in Wave 1); `app-release` bucket lists all files; 3 trigger fns unpinned `search_path`; `pg_net` in public schema. | Standard hardening. | Auth settings + storage policy + migrations. | S each |
| 21 | **DATA-1: hard-deleting a user who is a CRM lead contact fails** (`crm_leads_identity` CHECK vs `ON DELETE SET NULL` → 23514). | Any future account-deletion/admin-delete flow fails for users who ever messaged. **Escalate to P0/P1 if account deletion ships at launch (D3).** | On user delete: delete/anonymize their CRM leads first, or relax the identity CHECK for anonymized leads. | S–M |
| 22 | **SEC-M2 (residual): 6 definer views rely solely on their WHERE for read security.** Item 1 kills the write path; reads still bypass base RLS by design. | A future edit dropping a predicate silently exposes data. | Convert read-only reporting views to `security_invoker=true` where base RLS suffices; otherwise document the WHERE-gates as load-bearing. | M |
| 23 | **SEC-I1 (verify): confirm no anon path returns exact listing coordinates** pre-jitter (`v_listings_public` verified clean; other paths unchecked). | Location privacy. | Audit map/search RPC outputs for raw lat/lng reachable by anon. | S |

---

## 🔵 P3 — Polish / follow-up

- **UX-3:** precache the first onboarding image + bundle the logo mark locally (first slide flashes blank).
- **UX-4 (D2):** decide whether passive listing views should be tracked (currently no server-side view analytics for publishers). Default: defer post-launch.
- **UX-5:** lowercase `alnujom` app label → properly-cased display name (fold into item 14's manifest edit).
- **PERF-L3/L4/L5:** currency cache; index `reviews.listing_id`, `viewings.listing_id`, `listings.agency_id`; `MediaQuery.sizeOf` in chat/assistant bubbles.
- **PERF-L6 (monitor):** Realtime WAL poller dominates DB time (inflated by `REPLICA IDENTITY FULL` on `user_roles`); keep publications minimal, watch as usage grows.

---

## Pre-answered decisions (defaults — founder can override)

| ID | Decision | Default |
|---|---|---|
| D1 | Area field: required or optional? | **Required** — fix the label (client-only, item 7). Override = amend `submit_listing` to accept null `area_id` (migration) and keep the label. |
| D2 | Track passive listing views? | **Defer post-launch** (UX-4). |
| D3 | DATA-1 priority | **P2** — escalate to P0/P1 if an account-deletion flow ships at launch. |
| D4 | Launch cut line | **P0 + P1 before launch**; P2 after (except the SEC-L1 dashboard toggle — minutes, do it in Wave 1). |

## Traceability — every finding → a plan item

| Finding | Item | Finding | Item | Finding | Item |
|---|---|---|---|---|---|
| SEC-H1 | 1 | FUNC-M3 | 8 | PERF-M4 | 15 |
| SEC-M1 | 1 | UX-7 | 9 | PERF-M5 | 19 |
| SEC-M2 | 1 + 22 | UX-1 | 10 | PERF-L1/L2 | 19 |
| SEC-M3 | 13 | UX-2 | 11 | PERF-L3/L4/L5 | P3 |
| SEC-L1–L4 | 20 | UX-6 | 12 | PERF-L6 | P3 |
| SEC-L5 | 14 | UX-3 | P3 | DB-1 | 2 |
| SEC-I1 | 23 | UX-4 | P3 (D2) | DB-2 | 3 |
| FUNC-H1 | 3 | UX-5 | P3 + 14 | DATA-1 | 21 |
| FUNC-H2 | 5 | PERF-H1 | 15 | | |
| FUNC-H3 | 4 | PERF-H2 | 16 | | |
| FUNC-M1 | 6 | PERF-H3 | 17 | | |
| FUNC-M2 | 7 (D1) | PERF-M1/M2 | 18 | | |
| | | PERF-M3 | 10 | | |

## Execution rules (project constraints — do not skip)

- **Every** `flutter run`/`build` needs `--dart-define-from-file=.env.json` (else Supabase init is skipped → red screen).
- **DB changes:** write the file in `supabase/migrations/` AND apply it via Supabase MCP `apply_migration` (the CLI `db push` path is dead). NEVER re-apply an existing migration name (it re-runs the SQL + duplicates the tracker row). `pg_get_functiondef` BEFORE any `CREATE OR REPLACE` and preserve everything you're not changing. Run `get_advisors` after each DB wave. Item 2's reconstructed files are **commit-only**.
- **No new automated tests** (founder rule until MVP ships). Verification = manual AVD walk, light/dark × ar/en; the Pixel 8 Pro AVD is acceptable evidence; use the Infinix Note 8 for the perf-sensitive items (15/16).
- **New ARB keys** need a matching `@override` in `_DebugAppLocalizations` (`lib/core/localization/app_strings.dart`) or `flutter analyze` fails.
- **Local verify suite before every commit** (CI is paused — this is the only gate): `flutter analyze` + `dart run tool/lint_design_tokens.dart` + `dart run tool/lint_l10n_parity.dart` + `dart run tool/lint_l10n_literals.dart`. Format ONLY touched files (repo-wide `dart format` has version drift).
- **Known failures that are NOT yours:** 12 pre-existing widget-test failures (flutter_animate timers, stale Retry, goldens, theme_gallery). Golden + contrast baselines are flagged for regen when visual changes land — review those diffs deliberately.
- **Emulator:** relaunch recipe + off-screen-window fix in `docs/dev/android-emulator-windows.md`; screenshots via `adb exec-out screencap -p > file.png`.

## Coverage gaps to walk next (not tested this session)
Reviews (write), CRM, publisher dashboard/charts, viewings scheduler, Reels playback, map, comparison, agency screens, admin sub-screens (locations/currencies/roles/audit/ads/reports), and forgot-password. No problems were seen in these — they simply weren't exercised. Recommend a second focused pass after Wave 3, ideally on the physical Infinix Note 8 for the performance-sensitive ones (feed scroll, reels).

## Test-data cleanup (done at end of the QA session)
QA account `+963977445511` (+ profile/roles/approval-request), draft listing `QA-TEST-LISTING-001`, the test favorite, and the test chat message/conversation were created during testing and are removed. The demo account `+963991883342` approval test was reverted to `pending`. Reminder: delete the pre-existing demo data before launch (tracked in the Phase-25 memory).
