# E2E QA — Full App Walk (2026-07-16)

**Method:** End-to-end exploratory QA driving the real **release** build (`com.alnujom.app`, Flutter 3.35.2) on the Pixel 8 Pro AVD via screenshots + coordinate taps, like a human user. Every mutating action is verified against the Supabase database (ground truth). In parallel: a security audit (RLS/advisors/secrets/auth) and a performance audit (queries/rendering/startup) ran as background agents; their confirmed findings are merged here.

**Severity scale:** 🔴 CRITICAL (security hole / data loss / blocks core flow) · 🟠 HIGH (broken feature or serious risk) · 🟡 MEDIUM (wrong behavior, poor UX, perf issue) · 🔵 LOW (polish/minor) · ⚪ INFO (observation)

---

## Ground-truth baseline (before testing)

| Table | Rows | Table | Rows |
|---|---|---|---|
| profiles / auth users | 12 | listings | 26 (16 approved, 5 sold, 3 rejected, 2 draft) |
| favorites | 1 | conversations / messages | 1 / 0 |
| inquiries | 0 | reviews | 3 |
| notifications | 16 | viewings | 1 |
| crm_leads | 1 | listing_revisions | 2 |
| reports | 0 | saved_searches | 0 |
| account_approval_requests | 12 | ads | 3 |
| governorates / cities / areas | 14 / 64 / 380 | | |

Existing roles in use: `user`, `admin`, `super_admin`, `moderator`, `manager`, `qa_audit_only`. Auth is phone+password via synthetic `<phone>@alnujom.local` emails (no SMS OTP).

**QA accounts created during this session** (delete before launch, along with pre-existing demo data):
- **User:** `+963977445511@alnujom.local` (`QA-Tester-Nujom`, id `10794068-…`) — created via signup UI, then SQL-bootstrapped to approved + super_admin + publisher-approved. **Delete user + profile + user_roles + account_approval_request.**
- **Draft listing:** `927041af-d2a4-4fd9-8fcb-66da97df0fac` ("QA-TEST-LISTING-001") + its `listing_prices` row — created during the create-form test. **Delete.**
- **Favorite:** row (QA user → listing `…010`). **Delete** (or leave; harmless).
- **Revert:** the admin-UI approval test on account `41219f85` (`+963991883342`) — see §admin; restore to `account_status=pending`, `publisher_status=pending`, approval request `12b39449` back to `status=pending, reviewed_by=null, reviewed_at=null`.

---

## 1. Findings — E2E UI walk

**QA account created via the real signup UI:** phone `0977445511` → `+963977445511@alnujom.local`, name `QA-Tester-Nujom`, user_id `10794068-aa65-43ed-8367-ec1d4fcff336`. Bootstrapped via SQL to `approved` + `super_admin` + publisher-approved to exercise authenticated/admin flows. **DELETE this account + revert the pending-account approval test before launch.**

### 🟡 UX-1 — Cold launch shows the OS notification-permission dialog over a BLACK screen (no splash/branding yet)
- Reproduced on every cold start: `am start` resolves to `GrantPermissionsActivity` and the "Allow alnujom to send you notifications?" system dialog appears on a black screen before any splash/branding renders. First thing a brand-new user sees is a permission prompt with no context.
- Root cause = PERF-M3 (`FirebaseMessaging.requestPermission()` awaited in `main.dart` before first frame). **Fix:** defer the permission request until after the app's first frame / after onboarding, ideally with a soft pre-prompt explaining why. Improves both first-impression UX and cold-start.

### 🟡 UX-2 — Auth screens (login + register) still show the OLD placeholder blue-star logo
- The onboarding slides use the new "N" orbit logo mark, but `login` and `register` headers show the Phase-24 **placeholder blue star** (white rounded square + blue star). The whole point of Phases 25/32/35 was to retire that placeholder. Inconsistent branding on the two highest-intent screens.
- **Fix:** swap the auth-header logo to the current brand mark (same asset onboarding uses).

### 🔵 UX-3 — First onboarding slide renders with a blank gray illustration + missing logo on first paint
- Slide 1 showed an empty gray gradient where the background photo goes, and no logo mark; slides 2–3 render both correctly. It's a first-paint asset-load race (network/asset image not ready on frame 1), not a permanently broken asset. **Fix:** precache the first slide's image (and bundle the logo mark as a local asset so it never waits on network).

### 🟠 FUNC-H1 — Price filter is ignored unless BOTH min and max are set (single-bound price search silently returns everything)
- `search_listings` price predicate: `(p_price_min_usd IS NULL OR p_price_max_usd IS NULL OR v.primary_amount BETWEEN p_price_min_usd AND p_price_max_usd)` — if **either** bound is NULL the whole clause is TRUE, so the filter does nothing. Same for the SYP pair.
- **✅ CONFIRMED LIVE via RPC:** `search_listings(p_price_min_usd => 1000000)` (min above every listing) returned **16** rows (should be **0**); with both bounds set (`1M`–`2M`) it correctly returned `0`. So "under $X" or "at least $X" — the most common price search — returns unfiltered results.
- **Fix:** split into two independent bounds:
  `(p_price_min_usd IS NULL OR v.primary_amount >= p_price_min_usd) AND (p_price_max_usd IS NULL OR v.primary_amount <= p_price_max_usd)` (and the same for SYP).
- ⚠️ Note the schema-drift risk (DB-1): this RPC was applied to the live DB without a committed migration, so the fix must be captured as a new migration.

### 🟡 FUNC-M1 — Favorites cards never show the property photo (always a placeholder icon)
- **✅ CONFIRMED (UI + code):** the Favorites tab card for listing `…010` shows the apartment type-icon placeholder, though the same listing shows its real cover photo on Home, Search, and Detail. The DB/view are fine — `v_favorites.main_image_path = "…/living-luxury-1.jpg"` and the media row exists.
- **Root cause:** `favorite_card.dart:172` passes `item.mainImagePath` (a raw **storage path**) directly to `AppNetworkImage`, which expects a full HTTP URL. The favorites datasource never calls `getPublicUrl`, whereas Home (`supabase_home_feed_datasource.dart:147`) and Search (`supabase_search_datasource.dart:214`) both resolve `storage_path → getPublicUrl('listing-images')` before passing to the card.
- **Fix:** in `supabase_favorites_datasource.dart` (or the DTO mapping), resolve `main_image_path` via `_client.storage.from('listing-images').getPublicUrl(path)` (with the same `http`-prefix passthrough Home uses).

### 🟡 UX-6 — Create-listing form discards a half-filled draft on back-press with no confirmation
- While filling the "إضافة عقار" form, a system back gesture immediately popped the route back to Home and discarded all entered fields (title/price/area) with no "discard changes?" prompt and no draft autosave. On a long listing form this is easy to trigger accidentally and costs the user everything they typed.
- **Nuance found later:** the form DOES autosave a server-side **draft** (a `draft` listing row is created with the entered values — see the create-persist verification in §4). So back-press doesn't necessarily lose everything, but the user gets no indication a draft was saved and no obvious way to resume it. **Fix:** either a `PopScope` discard/keep dialog, or a visible "saved as draft" toast + a drafts entry in "my listings".

### 🟡 FUNC-M2 — Create-listing: the "area/neighborhood" field is labeled "(optional)" but is required on submit
- **✅ CONFIRMED in UI:** the area dropdown reads **"اختر المنطقة (اختياري)"** (Choose area — *optional*), but submitting a fully-filled form (title/purpose/type/price/area-size/governorate/city/detailed-address/rooms/baths/phone, no photos) failed with **"تعذّر الإرسال — الرجاء إكمال الحقول التالية: المنطقة"** (please complete: Area). The label and the validation contradict each other, so the user is blocked by a field they were told is optional.
- **Fix:** either drop the "(اختياري)" label and mark it required (with the red "مطلوب" chip like the others), or make submit genuinely accept a null area. Pick one and make label + validation agree.

### 🟠 FUNC-H2 — Create-listing validation error shows a RAW UNTRANSLATED KEY to the user
- **✅ CONFIRMED in UI:** submitting with fewer than the minimum photos shows the dialog message literally as **`listing_media.images_below_minimum`** (the raw i18n key), instead of a localized Arabic sentence. (By contrast the missing-area error *was* translated → "المنطقة".) A raw key in a user-facing error dialog looks broken/unprofessional on the app's core publishing flow.
- **Fix (root cause pinned during plan review 2026-07-17):** the localized string **already exists** — `submitErrorImagesBelowMinimum` is in both ARBs since Phase 11 (ar "لازم صورة واحدة على الأقل" / en "At least one photo is required"). The bug is that `submit_failure_dialog.dart` → `_labelForPath()` has **no `case 'listing_media.images_below_minimum'`**, so the switch falls through to the raw path; `_stepForPath()` also doesn't map it to the media step. Fix = add the two switch cases (no ARB change needed). Audit the other codes `submit_listing` can emit against the same switch.

### 🟡 FUNC-M3 — Photos are effectively required (minimum count) but the photo section is NOT marked required
- The "الصور والفيديو" section shows "أضف حتى 10 صور" / "تمت إضافة 0 صورة" with **no** red "مطلوب" chip (unlike title/price/etc.), yet submit is blocked with `images_below_minimum` when 0 photos are added. Users aren't told photos are mandatory until they're rejected at submit.
- **Fix:** mark the photo section required (add the "مطلوب" chip + a "min N photos" hint), consistent with the other required fields.

### 🟡 UX-7 — Account-approval card shows NO identifying info when the profile name+phone are null (admin approves blind)
- **✅ CONFIRMED:** on the "طلبات الموافقة المعلّقة" screen, the real pending account (`41219f85`) rendered a card with **only a request date** — no name, no phone, no Accept/Reject context — because its `profiles.full_name` and `profiles.phone` are both null. An admin cannot tell who they're approving.
- The phone is still recoverable from `auth.users.email` (synthetic `+963991883342@alnujom.local`). **Fix:** fall back to the auth phone (parse from the synthetic email) and/or the user_id when the profile name/phone are null, so every approval card shows at least one identifier. (Also worth ensuring signup always persists `profiles.phone` — my fresh signup did, but this older account has null; confirm no signup path drops it.)

### 🟠 FUNC-H3 — Chat thread does NOT show a just-sent message until you leave and re-enter (stays on "no messages yet")
- **✅ CONFIRMED end-to-end:** started a conversation via مراسلة on listing `…010`, typed and sent "QA-test-inquiry-msg-001". The DB got the row immediately (`messages` + a new `conversations` row, correct `sender_user_id`/`listing_id`), but the thread UI **stayed on the empty state "لا توجد رسائل بعد"** — the sent bubble did not appear. After navigating out and back in, the bubble renders correctly (blue, "1:01 ص", ✓).
- **Impact:** on the app's core messaging feature the sender sees "no messages yet" right after sending → looks like it failed → likely re-sends (duplicates) and loses trust.
- **Cause (verified in code during plan review 2026-07-17):** `ChatThreadCubit` deliberately does NOT append on send — its doc comment says "the Realtime stream echoes it back, so we don't optimistically append" (`chat_thread_cubit.dart:55-62`) — and that echo never arrived. `messages` **is** in the `supabase_realtime` publication (verified live), so the delivery gap is downstream (realtime socket auth / WALRUS RLS path — check `get_logs(realtime)` while fixing). **Fix:** (a) optimistically append the sent message on send-success and reconcile with the stream by message id — fixes the sender's view regardless of the realtime root cause; (b) verify INBOUND live delivery with a 2-account device test (already a deferred Phase-026 QA item), since receiving depends on the same stream.

### 🔵 DATA-1 — Hard-deleting a user who is a CRM lead contact fails (constraint conflict)
- Found during test-data cleanup: `crm_leads.contact_user_id` is `ON DELETE SET NULL`, but `crm_leads` also has a CHECK (`crm_leads_identity`) requiring at least one identity column non-null. So deleting a user who is the *only* identity on a lead throws `23514`. (Auto-CRM had created a lead when the QA user messaged a listing — that part works correctly.)
- **Impact:** a future "delete my account" / GDPR-erasure flow, or admin user-deletion, will fail for any user who ever messaged a listing. **Fix:** on user delete, delete/anonymize their CRM leads first, or relax the identity constraint to allow a fully-anonymized lead.

### ⚪ UX-4 (INFO) — Opening a listing detail records NO server-side view tracking
- After opening listing `…010`, there is no `lead_events` row and no view counter increment. Passive views aren't tracked at all (only contact actions appear to be). If publishers are meant to see "views" analytics, passive views need to be recorded. Confirm whether this is intended before launch.

### App label is lowercase "alnujom"
- 🔵 UX-5 — The Android app/notification label is lowercase `alnujom` (seen in the permission dialog). Consider a properly-cased display name ("Al Nujom" / "النجوم").

---

## 2. Findings — Security audit

Read-only audit (no data/schema mutated). Overall the backend is in good shape: **all 43 public tables have RLS enabled**, every SECURITY DEFINER function has `search_path` pinned, admin RPCs enforce the caller's role server-side (not trusting params), storage buckets are UUID-path + ownership gated with MIME/size limits, and **no secrets are committed** (`.env.admin.json` / `key.properties` gitignored and never in history). The findings below are the exceptions.

### 🟠 SEC-H1 — `v_agencies` is an auto-updatable SECURITY DEFINER view with INSERT/UPDATE/DELETE granted to `anon` + `authenticated` (RLS-bypass write path)
- Object: view `public.v_agencies` (single base table `agencies`). `is_insertable_into=YES`, `is_updatable=YES`, `security_invoker` unset (= definer), and grants include anon/authenticated INSERT/UPDATE/DELETE. Writes through a single-base-table definer view run as the view **owner** and skip `agencies` RLS; with no `WITH CHECK OPTION` the view's WHERE isn't enforced on write.
- **Impact:** a client could potentially insert/modify/delete arbitrary `agencies` rows — e.g. self-set `status='approved'`, tamper with or delete other agencies — bypassing RLS.
- **✅ CONFIRMED LIVE (exploit-tested with the public anon key):** an anon `POST /rest/v1/v_agencies` was **authorized** — it reached the base table and failed only on data constraints, never on RLS/permission:
  - `INSERT {name, status:'approved'}` → `23502 null value in column "owner_user_id"` (base-table NOT NULL — write was accepted, blocked only by missing column).
  - `INSERT {…, owner_user_id: <uuid>}` → `23503 FK violation on agencies_owner_user_id_fkey` (reached the base-table FK check). With a **valid** `owner_user_id` (any authenticated attacker uses their own `auth.uid()`), the insert succeeds → **anyone can self-create a pre-`approved` agency, bypassing the approval workflow.**
  - anon `UPDATE`/`DELETE` returned `42501 permission denied for function current_user_has_permission` — these are *incidentally* blocked only because anon lacks EXECUTE on that function (the view's WHERE calls it); an **authenticated** user passes that check, and since base RLS is bypassed they can tamper with any `approved` agency row (no `WITH CHECK OPTION`).
  - No test rows persisted (all probe inserts failed on constraints; verified `agencies` has 0 `__QA_SECH1__` rows).
- **Fix:** `REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.v_agencies FROM anon, authenticated;` (writes must go through the `create_agency` / `update_agency_profile` RPCs, which enforce authorization). Same pattern should be checked on every auto-updatable definer view — see SEC-M1.

### 🟡 SEC-M1 — `v_lead_events_admin` same auto-updatable definer-view write path (authenticated)
- View over `lead_events`, definer, `authenticated` granted INSERT/UPDATE/DELETE → authenticated users could write/delete analytics events bypassing RLS. Lower impact (analytics integrity).
- **Fix:** `REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.v_lead_events_admin FROM authenticated;`
- **Plan-review sweep (2026-07-17): the same write grants exist on ELEVEN public views** — `v_ads_serving`, `v_agencies`, `v_favorites`, `v_inquiries_inbox`, `v_lead_events_admin`, `v_lead_events_publisher`, `v_listings_map_public`, `v_listings_public`, `v_publisher_listings`, `v_publisher_ratings`, `v_reports` (each with DELETE/INSERT/REFERENCES/TRIGGER/TRUNCATE/UPDATE for anon and/or authenticated). Only the auto-updatable single-base-table **definer** ones are directly exploitable (the SEC-H1 class), but the fix should revoke client write privileges on **all** public views in one migration — the app never writes through a view (all writes go through RPCs or RLS-gated base tables), so this is zero-risk.

### 🟡 SEC-M2 — Six SECURITY DEFINER views rely solely on their WHERE clause for row security (advisor ERROR)
- `v_ads_serving`, `v_agencies`, `v_listings_public`, `v_reports`, `v_lead_events_admin`, `v_lead_events_publisher`. Reads are currently gated correctly by each view's WHERE, but base-table RLS is bypassed, so a future edit dropping a predicate silently exposes data. This is the project's documented "definer+WHERE" pattern (likely intentional) but it's what enables H1/M1.
- **Fix:** convert read-only reporting views to `security_invoker=true` where base-table RLS already expresses the rule; otherwise add regression coverage on the WHERE gates.

### 🟡 SEC-M3 — 29 SECURITY DEFINER functions carry default `anon` EXECUTE (defense-in-depth gap)
- Incl. `app_vault_secret_for_agency`, `app_vault_set_agency_secret`, `decrypt_inquirer_phone`, `create_agency`, agency-management RPCs. **Verified these fail closed for anon** (they check `auth.uid()`/permissions which are null for anon), so not currently exploitable — but the known project gotcha (new funcs get default anon EXECUTE).
- **Fix:** `REVOKE EXECUTE … FROM anon` on all vault/decrypt/agency-management RPCs; keep anon EXECUTE only on the deliberately public ones (`submit_inquiry`, `record_ad_event`, `search_listings`, `search_map`, `list_video_reels`, market stats).

### 🔵 SEC-L1 — Leaked-password protection disabled (enable HaveIBeenPwned check in Auth settings).
### 🔵 SEC-L2 — `app-release` public bucket allows listing all files (`public_bucket_allows_listing`); scope or remove the broad SELECT list policy.
### 🔵 SEC-L3 — Three trigger functions have mutable `search_path` (`set_updated_at`, `listing_status_transition_trigger_fn`, `listing_media_cap_check`); non-DEFINER so low risk, pin anyway.
### 🔵 SEC-L4 — `pg_net` extension installed in `public` schema; move to a dedicated schema.
### 🔵 SEC-L5 — Android `allowBackup` defaults to `true` — Supabase session tokens in SharedPreferences could be extracted via `adb backup` on some devices. Set `android:allowBackup="false"` or exclude the auth store.
### ⚪ SEC-I1 — `map_jitter_coordinates` is anon-executable and takes original coords as client params; public view `v_listings_public` does NOT expose lat/lng (checked), so exact coords don't appear to reach anon. UNVERIFIED: confirm no other anon path hands exact lat/lng to clients before jitter.

---

## 3. Findings — Performance audit

Data-layer hygiene is genuinely good (no `select('*')`, keyset pagination everywhere, no N+1, exemplary reels controller lifecycle, debounced search, image work off the UI thread in an isolate). The gaps below are mostly on the Phase-035 "Blue Crown" home redesign and search indexing.

### 🟠 PERF-H1 — Home feed is no longer virtualized (Blue Crown redesign regression)
- `lib/features/home/presentation/pages/home_page.dart:227` uses `SingleChildScrollView` + `Column`; `:279-326` spreads **every** card into the column (the old `ListView.builder` was replaced). Every infinite-scroll page keeps all cards + images alive, and `BlocBuilder<HomeBloc>` at `:188` has no `buildWhen` so all cards rebuild on each pagination/refresh emission.
- **Fix:** convert to `CustomScrollView` + `SliverList.builder` (crown/rails as leading slivers). **Impact:** jank + growing memory on the primary screen after 2–3 pages, worst on the Infinix Note 8.

### 🟠 PERF-H2 — Full-size images decoded into small cards by default
- `lib/core/widgets/app_network_image.dart:67-68`: `memCacheWidth`/`maxWidthDiskCache` (600px) apply **only when Data-saver is ON**. Default decodes ~1920px JPEG (~8 MB bitmap) into a ~360px card slot; no Supabase image transforms anywhere (all 20+ call sites use raw `getPublicUrl`).
- **Fix:** add a `targetWidth` param and always set `memCacheWidth` at card call sites. **Impact:** decode jank + memory pressure; compounds with PERF-H1.

### 🟠 PERF-H3 — `search_listings` text search cannot use any index
- `supabase/migrations/20260615120003_search_amenities_filter.sql:76-79`: `search_vector @@ plainto_tsquery(...) OR ld.description ILIKE '%'||q||'%'`. The cross-table OR defeats the GIN index (`idx_listings_search_vector` = **0 scans**) and `pg_trgm` is **not installed** so the leading-wildcard ILIKE can never be indexed.
- **Fix:** fold description into `search_vector`, or install pg_trgm + trigram GIN on `listing_details.description` and restructure as UNION. **Impact:** search latency grows linearly with listing count — the main growth-limiting query.

### 🟡 PERF-M1 — 63 `auth_rls_initplan` warnings across 26 tables (incl. hot feed path)
- `auth.uid()`/permission functions re-evaluated **per row** on `listings`×3, `listing_media`×4, `listing_prices`×2, `favorites`, `messages`, etc. **Fix:** wrap as `(select auth.uid())` per advisor. **Impact:** per-row CPU on every feed page as rows grow.

### 🟡 PERF-M2 — 27 `multiple_permissive_policies` combos double RLS cost on the feed
- `listings`/`listing_media`/`listing_prices`/`listing_details`/`listing_visibility` each have 2 permissive SELECT policies for `authenticated`. **Fix:** merge into one policy per action.

### 🟡 PERF-M3 — Heavy awaited chain before first frame
- `lib/main.dart:131-137`: `await Firebase.initializeApp()` **and** `await FirebaseMessaging…requestPermission()` (can raise the Android-13 permission dialog on splash) before `runApp`. **Fix:** move `requestPermission` (and ideally Firebase init) post-first-frame; keep Supabase/DI awaited. **Impact:** slower cold start; dialog can block splash.

### 🟡 PERF-M4 — Whole-page `setState` on the Home segment toggle
- `home_page.dart:234` rebuilds the entire non-virtualized body on purpose-segment change. **Fix:** scope to a `ValueNotifier`/the crown widget.

### 🟡 PERF-M5 — Fat APK, no shrinking config
- `android/app/build.gradle.kts` release block sets only signing — no `isMinifyEnabled`/`isShrinkResources`, no ABI splits; APKs are distributed directly (Telegram). **Fix:** `--split-per-abi` (arm64 for Infinix) + minify/shrinkResources. **Impact:** ~2–3× larger download than needed. _(Current release APK = 90 MB.)_

### 🔵 PERF-L1 — ~1.5 MB dead fonts bundled (Cairo + IBMPlexSansArabic) — only Tajawal + Inter used (`typography.dart:43-44`). Drop them from `pubspec.yaml:115-137`.
### 🔵 PERF-L2 — ~2.8 MB dead branding assets — `pubspec.yaml:100` bundles all of `assets/branding/` but only 3 files load at runtime; the rest are icon/splash build inputs. Enumerate only the 3 used files.
### 🔵 PERF-L3 — Currencies re-fetched per screen, no cache (`CurrenciesRepositoryImpl`). Add a short-TTL in-memory cache.
### 🔵 PERF-L4 — 19 unindexed FKs; user-facing ones worth indexing first: `reviews.listing_id`, `viewings.listing_id`, `listings.agency_id`.
### 🔵 PERF-L5 — `MediaQuery.of` in chat/assistant message bubbles (`chat_thread_page.dart:204`, `assistant_page.dart:232`) rebuilds all bubbles per frame on keyboard animation. Use `MediaQuery.sizeOf`.
### ⚪ PERF-L6 — Realtime WAL poller dominates DB time (inflated by `REPLICA IDENTITY FULL` on `user_roles`); keep publications minimal, monitor.

### ⚠️ Non-perf issues surfaced by the perf audit (important):
- **DB-1 (schema drift):** live `search_listings` has 29 args (incl. `p_deed_type`/`p_finish_level`/`p_verified_only`) but **no committed migration** defines them — the Phase-035 filter migration was applied live and never committed. Reproducibility/DR risk.
  - **Plan-review scope (2026-07-17): the live migration tracker has SIX applied migrations with no matching file in `supabase/migrations/`:** `035_add_deed_finish_verification_columns`, `035_expose_deed_finish_verification_in_public_view`, `035_search_listings_deed_finish_verified_filters`, `035_admin_set_listing_verification_rpc`, `035_revoke_anon_admin_verification` (all Phase 035), plus `20260608160001_search_owner_agency_filter` (Phase 026). All six must be reconstructed from the live DB and committed (commit-only — do NOT re-apply; they're already live).
- **DB-2 (logic bug — now 🟠 HIGH, CONFIRMED LIVE):** see FUNC-H1 below.

---

## 4. Verified OK (coverage log)

Each of these was driven in the real release UI and cross-checked against the database:

- **Onboarding** — 3 slides, correct Arabic RTL, skip + next + "start now" all work.
- **Signup** (real form) — created `+963977445511` → DB shows synthetic email, profile `QA-Tester-Nujom`, phone normalized `0977445511`→`+963977445511`, `account_status=pending`, `publisher_status=pending`, and **1 `account_approval_request` auto-created** by the workflow trigger. Email auto-confirmed (no real email). ✅ UI↔DB exact match.
- **Pending-approval gate** — new account correctly held on "الحساب قيد المراجعة"; cannot enter the app. ✅ matches `account_status=pending`.
- **Sign-out** — from the pending screen returns to login. ✅
- **Login** — after approving the account (SQL), same credentials logged in and routed to Home. No stale-permission-cache issue on fresh login. ✅
- **Home feed** ("Blue Crown") — featured rail shows the 2 correct featured listings with موثّق (verified) + مميّز (featured) badges; prices ($210,000 / $120,000), purpose segments, property-type grid, bottom nav all render correctly in RTL. ✅ matches DB featured set.
- **Listing detail** (`…010`) — floor 7 / 220 m² / 3 baths / 4 rooms / green deed / super-deluxe / field-verified badge all render; **every field exactly matches the `listings` row**. ✅
- **Favorite toggle** — heart on detail inserted a `favorites` row (my user + listing `…010`). ✅ persistence verified.
- **Search + filters** — default search returns "16 نتيجة" = the 16 approved listings; villa filter returns "نتيجتان" = the 2 approved villas ($340k sale shown first). ✅ counts match DB exactly. Filter chips + "1 active" badge work.
- **Filters sheet** — purpose, property type, **advertiser (owner/office) filter**, verified-only toggle all present; the Syria location cascade (14 governorates → Damascus → Damascus city → 14+ neighborhoods) loads correct data.
- **Chat/inquiry (WRITE PATH)** — sending a message inserted a `messages` row + new `conversations` row with correct `sender_user_id` and `listing_id`; message shows on reload with ✓. ✅ (but see FUNC-H3 — doesn't show until reload).
- **Notifications** — screen renders the correct empty state for the new QA account (its 0 notifications; the 16 in DB belong to other users). ✅
- **Profile** — shows QA name, phone `+963977445511`, "مقبول" (approved) badge, roles (Super Admin + User); **currency selector** loads (SYP selected, USD available); data-saver toggle present. ✅
- **Guest mode** — sign-out clears the session and lands on public Home; tapping a protected tab (Profile) correctly redirects to the login gate. ✅
- **Admin gate + dashboard** — super_admin role unlocks the "الإدارة" section; the admin dashboard stats are accurate (0 open reports, 0 listings under review, 2 users pending — all match DB). ✅

**NOT individually walked this session** (lower priority / time; no evidence of problems, but untested here — flag for a follow-up pass): reviews write, CRM leads/notes/reminders, publisher dashboard analytics/charts, viewings scheduler, Reels video playback, map view, comparison screen, agency screens, and the other admin sub-screens (locations, currencies, roles, audit logs, ads, reports, inquiries inbox). Forgot-password (OTP-less reset via Edge Function) also not exercised.
- **Admin account approval (WRITE PATH) — ✅ verified end-to-end:** tapping قبول on the real pending account ran `approve_account_approval_request` and the DB transitioned exactly right — request `status pending→approved`, `reviewed_by`=my admin user, `reviewed_at` set, and target `profiles.account_status pending→approved` (publisher_status correctly left pending). Reverted afterward. ✅
- **Publisher create-listing (WRITE PATH) — ✅ ALL FIELDS PERSIST CORRECTLY (no dropped values):** filled the Quick form (title/purpose/type/price-SYP/area/gov/city/area/detailed-address/rooms/baths/phone) and the DB row `927041af-…` came back with every value intact — `title`, `purpose=sale`, `property_type=apartment`, `area_size=150`, `rooms=3`, `bathrooms=2`, `address_text`, `phone`, `city_id`+`area_id` FKs, and the price in `listing_prices` (50,000,000 SYP). Status = `draft` (autosaved). This directly clears the historical "wave ships dropped form values" concern for this form. The only unverified step is the final `draft→pending` submit, blocked by the mandatory-photo gate + the emulator photo-picker not exposing adb-pushed images (environment limitation, not an app bug).
