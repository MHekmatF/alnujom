# Fix Plan — E2E QA (2026-07-16)

Prioritized, actionable plan derived from [FINDINGS.md](FINDINGS.md). Every item lists **what**, **why it matters**, **where**, and a rough **effort**. Grouped by priority so you can decide the launch cut line.

**How the testing was done:** the real release build was driven on the Pixel 8 Pro emulator like a human user — tapping through onboarding, signup, login, search, a listing, favorites, creating a listing, admin approvals, and chat — and **every action that writes data was checked against the live Supabase database** to confirm the numbers were right. In parallel, one agent audited backend security (RLS/permissions/secrets) and another audited performance. What was verified working is listed at the bottom of FINDINGS.md; below is only what needs action.

---

## 🔴 P0 — Fix before launch (security + broken core flows)

| # | Issue | Why it matters | Where | Effort |
|---|---|---|---|---|
| 1 | **SEC-H1: `v_agencies` lets any client write the `agencies` table directly (RLS bypass).** Proven live: an anonymous request could insert an agency (blocked only by data constraints, not permissions); an authenticated user can self-create a pre-`approved` agency or tamper with existing ones. | A user could bypass the agency approval workflow entirely, or edit/delete other agencies. Real data-integrity/security hole. | DB view `public.v_agencies` | S — one migration: `REVOKE INSERT,UPDATE,DELETE,TRUNCATE ON public.v_agencies FROM anon, authenticated;` |
| 2 | **SEC-M1: same write-bypass on `v_lead_events_admin`** (authenticated). | Analytics tampering, lower impact than #1 but same class. | DB view `v_lead_events_admin` | S — same REVOKE pattern. |
| 3 | **FUNC-H1: price filter is ignored unless BOTH min and max are set.** Proven: "under $X" or "at least $X" (the most common price search) returns everything. | Price is the #1 filter in real estate; single-bound is broken → users see irrelevant results and distrust search. | `search_listings` RPC (price predicate) | S — split into two independent bounds; ship as a new migration. |
| 4 | **FUNC-H3: chat doesn't show your just-sent message** until you leave and re-enter the thread (stays on "no messages yet"). | Core messaging feature looks broken to the sender → re-sends (duplicates), lost trust. | chat thread bloc/page (optimistic append + realtime reconcile) | M |
| 5 | **FUNC-H2: create-listing shows a raw code `listing_media.images_below_minimum`** as the user-facing error. | Looks broken/unprofessional on the primary publishing flow. | l10n ARB + create-form validation mapping | S — add the ar/en string + map the code. |
| 6 | **DB-1: schema drift — the live `search_listings` (29 args incl. deed/finish/verified filters) has NO committed migration.** | If the DB is ever rebuilt from migrations, search silently loses filters. Also blocks reviewing the #3 fix. | `supabase/migrations/` | S — dump the live function and commit it as a migration (do this together with #3). |

---

## 🟠 P1 — Strongly recommended before launch (functional + UX correctness)

| # | Issue | Why it matters | Where | Effort |
|---|---|---|---|---|
| 7 | **FUNC-M1: favorites cards never show the property photo** (always a placeholder). Home/Search resolve the image URL; favorites doesn't. | The Favorites screen looks empty/broken even though the data is fine. | `supabase_favorites_datasource.dart` (add `getPublicUrl('listing-images')`) | S |
| 8 | **FUNC-M2: create-listing "area" field is labeled "(optional)" but is required on submit.** | User is blocked by a field they were told was optional. | create-form (label vs validation) | S — pick one: make it required (add the chip) or accept null. |
| 9 | **FUNC-M3: photos are effectively required (minimum count) but the photo section has no "required" marker.** | User isn't told photos are mandatory until submit is rejected. | create-form photo section | S |
| 10 | **UX-7: account-approval card shows no name/phone when the profile fields are null** (admin approves blind). Phone is still recoverable from the auth email. | Admins can't tell who they're approving. | approvals screen (fallback to auth phone / user_id) | S–M |
| 11 | **UX-1 / PERF-M3: cold launch shows the notification-permission dialog over a black screen** before any branding, because permission is requested before the first frame. | Bad first impression; also slows cold start. | `main.dart` — defer `FirebaseMessaging.requestPermission()` to post-first-frame, ideally with a soft pre-prompt. | S–M |
| 12 | **UX-2: login + register still show the OLD placeholder blue-star logo** (onboarding uses the new mark). | Inconsistent branding on the two highest-intent screens. | auth headers — swap to the current brand mark. | S |
| 13 | **UX-6: create-listing discards a half-filled form on back-press** with no confirmation (a draft IS autosaved server-side, but the user isn't told and can't obviously resume it). | Lost work / confusion. | create-form — `PopScope` discard dialog + "saved as draft" affordance + a drafts entry in "my listings". | M |
| 14 | **SEC-M3: 29 SECURITY DEFINER functions carry default `anon` EXECUTE** (they fail closed today, but it's the known footgun). | Defense-in-depth; one future edit could turn a latent grant into a hole. | `REVOKE EXECUTE … FROM anon` on all vault/decrypt/agency-management RPCs. | S–M |
| 15 | **SEC-L5: Android `allowBackup` defaults to true** → session tokens could be extracted via `adb backup`. | Session theft on some devices. | `AndroidManifest.xml` — `android:allowBackup="false"`. | S |

---

## 🟡 P2 — Performance & hardening (before or shortly after launch)

| # | Issue | Why | Where | Effort |
|---|---|---|---|---|
| 16 | **PERF-H1: Home feed is no longer virtualized** (Blue Crown redesign uses a `Column` in a `SingleChildScrollView`; no `buildWhen`). | Jank + growing memory on the main screen after a few scroll pages — worst on the Infinix Note 8. | `home_page.dart` → `CustomScrollView` + `SliverList.builder`. | M |
| 17 | **PERF-H2: full-size images decoded into small cards by default** (600px cap only applies in Data-saver). | Decode jank + memory pressure on low-end devices; compounds #16. | `app_network_image.dart` — always set `memCacheWidth` at card call sites. | S–M |
| 18 | **PERF-H3: `search_listings` text search can't use any index** (cross-table OR + no pg_trgm). | Search latency grows linearly with listing count. | fold description into `search_vector`, or add pg_trgm + trigram GIN. | M |
| 19 | **PERF-M1/M2: 63 RLS `auth.uid()` re-evaluations + 27 duplicate permissive policies** on the hot feed tables. | Per-row CPU on every feed/search as data grows. | wrap as `(select auth.uid())`; merge duplicate policies (advisor-guided). | M |
| 20 | **PERF-M5 + L1/L2: fat APK (90 MB), no minify/shrink/ABI-split; ~4 MB dead fonts+assets bundled.** | 2–3× larger download than needed (distributed via Telegram). | `build.gradle.kts` (minify + `--split-per-abi`); prune `pubspec.yaml` assets. | S–M |
| 21 | **SEC-L1/L2/L3/L4: leaked-password protection off; `app-release` bucket lists all files; 3 trigger fns unpinned search_path; `pg_net` in public schema.** | Standard hardening. | Auth settings + storage policy + migrations. | S each |

---

## 🔵 P3 — Polish / follow-up

- **UX-3:** precache the first onboarding image + bundle the logo mark locally (first slide flashes blank). 
- **UX-4:** decide whether passive listing views should be tracked (currently no server-side view analytics for publishers). 
- **UX-5:** app label is lowercase `alnujom` — set a properly-cased display name. 
- **PERF-L3/L4/L5:** currency cache; index a few user-facing FKs (`reviews.listing_id`, `viewings.listing_id`, `listings.agency_id`); `MediaQuery.sizeOf` in chat/assistant bubbles.

---

## Coverage gaps to walk next (not tested this session)
Reviews (write), CRM, publisher dashboard/charts, viewings scheduler, Reels playback, map, comparison, agency screens, admin sub-screens (locations/currencies/roles/audit/ads/reports), and forgot-password. No problems were seen in these — they simply weren't exercised. Recommend a second focused pass, ideally on the physical Infinix Note 8 for the performance-sensitive ones (feed scroll, reels).

## Test-data cleanup (done at end of this session)
QA account `+963977445511` (+ profile/roles/approval-request), draft listing `QA-TEST-LISTING-001`, the test favorite, and the test chat message/conversation were created during testing and are removed. The demo account `+963991883342` approval test was reverted to `pending`.
