---
description: "Phase 16 — Contact, Inquiries & Lead Events task list"
---

# Tasks: Contact, Inquiries & Lead Events

**Input**: Design documents from `specs/016-contact-inquiries/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)
**Tests**: No new automated tests per project memory `feedback_no_new_tests.md`. Manual UI verification on Infinix Note 8 + Pixel 8 Pro AVD (per memories `user_test_device.md` and `feedback_avd_acceptable_qa.md`) is the gate. `quickstart.md` captures the recipe.
**Organization**: Tasks are grouped by Sub-Phase (matching plan.md §Phase Dependencies). Story labels [US1]..[US7] tag tasks by the primary user story they enable; many tasks serve multiple stories where the inbox, ContactBlock, and admin oversight surfaces share infrastructure.

**Acceptance-criteria convention** (Constitution Principle X compliance, matches Phase 14 + Phase 15 precedent): each implementation task's acceptance criteria is defined by the **linked contract file** or **data-model section** it references in its description. A task that says "Create X per contracts/phase16-Y.md §Z" is accepted when (a) the file exists at the specified path, (b) its content matches the contract's stated structure (signature, fields, behavior), and (c) `flutter analyze` returns zero new errors / `flutter build apk --debug` succeeds where applicable. The **Phase Checkpoint** line at the end of each sub-phase summarizes the cumulative acceptance gate for the whole phase. Tasks with explicit per-task acceptance criteria spell them out in an `**Acceptance**:` clause. Manual smoke tests carry their own pass/fail criteria inline.

**Checkbox discipline (MANDATORY for every sub-agent)**: Each sub-agent dispatched against this tasks.md MUST flip its `- [ ] T<id>` checkboxes to `- [X] T<id>` in the **same commit** as the implementation. Do NOT leave checkbox-flipping for a "cleanup pass" — it never happens. If a task is partially complete or device-verified-only, flip the checkbox to `- [ ] **⚠️ PARTIAL —**` with a one-line reason and a `DEFERRED.md §D-T<id>` pointer per memory `feedback_strict_task_completion.md`.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Maps the task to one or more user stories from spec.md
- All file paths are repo-relative

---

## Phase 1: Sub-Phase A — Bootstrap (pubspec, route slots, domain skeleton)

**Purpose**: Add `url_launcher`, register the three new routes, define the `InquiryStatus` + `LeadEventType` enums, scaffold the `lib/features/inquiries/` skeleton, and stub the three pages so the dependency graph is testable end-to-end.

**Goal**: After Phase 1, `flutter pub get` succeeds, the app builds, and tapping any of the three new routes (`/inquiries`, `/inquiries/:id`, `/admin/inquiries`) opens a stub page.

- [ ] T001 Add `url_launcher: ^6.3.0` to `pubspec.yaml` under `dependencies:` (alphabetically between `supabase_flutter` and any later entry). Run `flutter pub get`. Verify zero version-resolution conflicts in `pubspec.lock`.
- [ ] T002 [P] Add the following constants to the `AppRoutes` class in `lib/core/routing/app_router.dart` (insert after `static const map = '/map';` from Phase 15): `static const inquiries = '/inquiries';`, `static const inquiryDetail = '/inquiries/:id';`, `static const adminInquiries = '/admin/inquiries';`. Add a helper `static String inquiryDetailFor(String id) => '/inquiries/$id';` matching the Phase 13 `listingDetailsFor` pattern. Add matching constants to the `AppRouteNames` class: `inquiries`, `inquiryDetail`, `adminInquiries`.
- [ ] T003 [P] Create the `lib/features/inquiries/` skeleton directories: `data/datasources/`, `data/models/`, `data/repositories/`, `domain/entities/`, `domain/repositories/`, `domain/usecases/`, `presentation/bloc/`, `presentation/pages/`, `presentation/sheets/`, `presentation/widgets/`. Add a `.gitkeep` or single placeholder file in each so they commit.
- [ ] T004 [P] [US4] Create `lib/features/inquiries/domain/entities/inquiry_status.dart` per data-model.md §3.1. `enum InquiryStatus { new_, seen, responded, closed, spam }` plus the static `_allowed` transition map per FR-021a + Q2=B + Q3=B AND the `allowedTransitions` getter AND the `wireValue` + `fromWire(String)` serialization helpers. No external dependencies beyond `package:equatable/equatable.dart`.
- [ ] T005 [P] [US6] Create `lib/features/inquiries/domain/entities/lead_event_type.dart` per data-model.md §3.2. `enum LeadEventType { phoneRevealed, whatsappClicked, inquirySent, favoriteAdded }` plus `wireValue` + `fromWire(String)` serialization helpers. `favoriteAdded` is reserved for Phase 17 — no Phase 16 write path consumes it.
- [ ] T006 [P] [US4] Create stub `lib/features/inquiries/presentation/pages/inquiry_inbox_page.dart` rendering an empty `Scaffold` with an `AppBar` (title `Text('Inquiries')` as a placeholder Sub-Phase G will replace via ARB) and an empty body. Class signature: `class InquiryInboxPage extends StatelessWidget { const InquiryInboxPage({super.key}); ... }`.
- [ ] T007 [P] [US4] Create stub `lib/features/inquiries/presentation/pages/inquiry_detail_page.dart` rendering an empty `Scaffold` with an AppBar and placeholder body. Class signature: `class InquiryDetailPage extends StatelessWidget { const InquiryDetailPage({super.key, required this.id}); final String id; ... }`.
- [ ] T008 [P] [US7] Create stub `lib/features/inquiries/presentation/pages/admin_inquiry_oversight_page.dart` rendering an empty `Scaffold` with placeholder body. Class signature: `class AdminInquiryOversightPage extends StatelessWidget { const AdminInquiryOversightPage({super.key}); ... }`.
- [ ] T009 [US4,US7] In `lib/core/routing/app_router.dart`, register three `GoRoute` entries. Insert immediately after the existing `/map` route block from Phase 15:
  - `/inquiries` → `InquiryInboxPage()`
  - `/inquiries/:id` → `InquiryDetailPage(id: state.pathParameters['id']!)`
  - `/admin/inquiries` → `AdminInquiryOversightPage()` with a `redirect:` that returns `null` when `getIt<PermissionChecker>().has('inquiries.view_all')` is true and `AppRoutes.home` otherwise. Add imports for all three page files + `PermissionChecker`.
- [ ] T010 [US4,US7] Run `flutter pub run build_runner build --delete-conflicting-outputs` to regenerate `lib/core/di/injection.config.dart` (picks up no new `@injectable` annotations yet — Sub-Phases E and F will). Run `flutter build apk --debug --dart-define-from-file=.env.json` to confirm the app builds end-to-end. Flip checkboxes T001–T010 to `[X]` in the same commit.

**Phase Checkpoint**: `flutter run` launches the app; navigating to `/inquiries`, `/inquiries/<some-uuid>`, and (signed-in as admin) `/admin/inquiries` shows the respective stub pages. Signed-in as non-admin → `/admin/inquiries` redirects to home. The build is green.

---

## Phase 2: Sub-Phase B — Backend schema (tables + transition trigger)

**Purpose**: Land the three Supabase migrations that create the `inquiries` + `lead_events` tables and the `enforce_inquiry_transition` BEFORE UPDATE trigger.

**Goal**: After Phase 2, `INSERT INTO public.inquiries (...)` from a privileged session works AND the trigger rejects any disallowed status transition.

- [ ] T011 [US3,US4] Create migration file `supabase/migrations/20260527120001_create_inquiries_table.sql` with the full body per data-model.md §2.1. Columns: `id`, `listing_id` (FK ON DELETE RESTRICT per Q4=C), `sender_user_id` (FK ON DELETE SET NULL), `sender_name` (CHECK 1..100), `inquirer_phone_encrypted` (BYTEA), `inquirer_phone_key_name` (TEXT DEFAULT 'app-inquirer-phone-key'), `message` (CHECK 1..2000 per Q7=B), `status` (CHECK enum), `created_at`, `updated_at`. `ALTER TABLE ENABLE ROW LEVEL SECURITY`. Three indexes per FR-015. Trigger `trg_inquiries_set_updated_at` calling `public.set_updated_at()`.
- [ ] T012 [US6] Create migration file `supabase/migrations/20260527120002_create_lead_events_table.sql` with the full body per data-model.md §2.2. Columns: `id`, `listing_id` (FK ON DELETE RESTRICT per Q4=C), `user_id` (FK ON DELETE SET NULL), `event_type` (CHECK enum incl. `favorite_added` reserved for Phase 17), `metadata` (JSONB), `created_at`. `ALTER TABLE ENABLE ROW LEVEL SECURITY`. Two indexes per FR-015.
- [ ] T013 [US4] Create migration file `supabase/migrations/20260527120005_create_enforce_inquiry_transition_trigger.sql` with the full body per data-model.md §2.5 + contracts/phase16-enforce-inquiry-transition-trigger.md. Function `public.enforce_inquiry_transition()` returns trigger; SECURITY DEFINER; search_path hardened. Allowed-pair lookup covers FR-021a + Q2=B forward path + closed-reopen + any-non-spam → spam. Invalid transitions RAISE EXCEPTION with SQLSTATE 23514. Trigger `trg_inquiries_enforce_transition BEFORE UPDATE OF status ON public.inquiries`.
- [ ] T014 [US3,US4,US6] One-time Vault key setup per data-model.md §1 / quickstart.md §1: via Supabase MCP `execute_sql`, run `SELECT vault.create_secret(gen_random_uuid()::text, 'app-inquirer-phone-key', 'Symmetric key for inquirer_phone column encryption (Phase 16, ADR-0001)');`. Verify via `SELECT name FROM vault.secrets WHERE name = 'app-inquirer-phone-key';` — expected 1 row. Idempotency: if the row already exists, the call raises a uniqueness violation; that's acceptable.
- [ ] T015 [US3,US4,US6] Apply T011's migration via Supabase MCP `apply_migration` tool: name `"create_inquiries_table"`, query = contents of T011's file. Per memory `project_supabase_mcp_apply_migration.md`: re-applying re-runs SQL AND adds a duplicate tracker row — the migration uses `CREATE TABLE IF NOT EXISTS` so re-application is safe.
- [ ] T016 [US6] Apply T012's migration via Supabase MCP `apply_migration`: name `"create_lead_events_table"`, query = T012's file contents.
- [ ] T017 [US4] Apply T013's migration via Supabase MCP `apply_migration`: name `"create_enforce_inquiry_transition_trigger"`, query = T013's file contents.
- [ ] T018 [P] [US3,US4] Create `supabase/docs/inquiries.md` documenting: columns table, CHECK constraints, indexes, Vault encryption contract (encrypt-only-via-RPC convention), forward-stated RLS posture (Phase 2 only enables RLS; Phase 3 lands the policies). Reference contracts/phase16-inquiries-table.md as the authoritative interface.
- [ ] T019 [P] [US6] Create `supabase/docs/lead_events.md` documenting: columns table, CHECK constraint on event_type (including `favorite_added` reserved), indexes, IP/UA capture convention (Sub-Phase D RPC writes only), metadata column masking rule (Sub-Phase C view enforces). Reference contracts/phase16-lead-events-table.md.
- [ ] T020 [US3,US4,US6] Verification via Supabase MCP `execute_sql`: `\d+ public.inquiries`, `\d+ public.lead_events`, `\df public.enforce_inquiry_transition`. Expected: all three exist with the columns/checks/indexes per data-model. Run `SELECT * FROM information_schema.triggers WHERE trigger_name = 'trg_inquiries_enforce_transition';` — expected 1 row. Flip T011–T020 in the same commit.

**Phase Checkpoint**: The two tables exist with RLS enabled (no policies yet — Phase 3 adds them). The transition trigger is wired. The Vault key is provisioned. Direct INSERT/UPDATE attempts from `authenticated`/`anon` fail because no INSERT policy yet exists (which is correct — all writes go through Sub-Phase D RPCs).

---

## Phase 3: Sub-Phase C — Backend policies + views (RLS three-tier rule + metadata masking)

**Purpose**: Land the four migrations that add the SELECT/UPDATE policies on both tables, create the inbox view with the inlined decrypt function, and create the publisher + admin tier lead_events views.

**Goal**: After Phase 3, the three-tier visibility rule (publisher / sender / admin) is enforced at the data layer. The `metadata` masking rule (FR-014b) is enforced at the view-projection layer.

- [ ] T021 [US3,US4,US5,US7] Create migration file `supabase/migrations/20260527120003_create_inquiries_policies.sql` with the full body per data-model.md §2.3 + contracts/phase16-inquiries-policies.md. Includes: idempotent `INSERT INTO public.permissions (key, ...) VALUES ('inquiries.view_all', ...) ON CONFLICT DO NOTHING` preamble; three SELECT policies (`inquiries_select_publisher`, `inquiries_select_sender`, `inquiries_select_admin`); one UPDATE policy (`inquiries_update_publisher`) with matching USING + WITH CHECK; `REVOKE INSERT ON public.inquiries FROM authenticated, anon`; no DELETE policy.
- [ ] T022 [US5,US6,US7] Create migration file `supabase/migrations/20260527120004_create_lead_events_policies.sql` with the full body per data-model.md §2.4 + contracts/phase16-lead-events-policies.md. Two SELECT policies (`lead_events_select_publisher`, `lead_events_select_admin`); `REVOKE INSERT, UPDATE, DELETE ON public.lead_events FROM authenticated, anon`.
- [ ] T023 [US3,US4,US5,US7] Apply T021's migration via Supabase MCP `apply_migration`: name `"create_inquiries_policies"`, query = T021's file contents.
- [ ] T024 [US5,US6,US7] Apply T022's migration via Supabase MCP `apply_migration`: name `"create_lead_events_policies"`, query = T022's file contents.
- [ ] T025 [US4,US5,US7] Create migration file `supabase/migrations/20260527120007_create_v_inquiries_inbox_view.sql` with the full body per data-model.md §2.7 + contracts/phase16-v-inquiries-inbox-view.md. View `public.v_inquiries_inbox` projects 11 columns including the `public.decrypt_inquirer_phone(i.id) AS inquirer_phone_decrypted` per-row call. JOIN on `public.listings` for `listing_title` + `listing_status`. `GRANT SELECT TO authenticated`. NOT granted to `anon`. **Note**: this migration MUST be applied AFTER Sub-Phase D's `decrypt_inquirer_phone` function migration (T031); enforce filename ascending order so apply succeeds (T031's `20260527120006` lands before this `20260527120007`).
- [ ] T026 [US6,US7] Create migration file `supabase/migrations/20260527120008_create_v_lead_events_views.sql` with the full body per data-model.md §2.8 + contracts/phase16-v-lead-events-views.md. View `v_lead_events_publisher` projects 5 columns (no `metadata`); view `v_lead_events_admin` projects 6 columns (with `metadata`) AND a defensive `WHERE public.current_user_has_permission('inquiries.view_all')` predicate. Both `GRANT SELECT TO authenticated`.
- [ ] T027 [US3,US5,US7] Update `supabase/docs/inquiries.md` (append RLS matrix section): three-tier rule, INSERT-via-RPC-only, UPDATE-publisher-only-with-trigger, no DELETE, view projection.
- [ ] T028 [US6,US7] Update `supabase/docs/lead_events.md` (append RLS matrix section): publisher-tier reads via `v_lead_events_publisher` (no metadata), admin-tier reads via `v_lead_events_admin` (with metadata + permission gate), no direct table writes from clients.

**Phase Checkpoint**: Policies + views exist. T025–T026 cannot be APPLIED until Sub-Phase D's decrypt function lands; the **migration files** commit now, the apply order is enforced by filename ordering in Sub-Phase D's checkpoint. Flip T021–T028 in the same commit.

---

## Phase 4: Sub-Phase D — Backend RPCs + decrypt function + advisor hardening

**Purpose**: Land the five Supabase migrations that create the SECURITY DEFINER write paths (`submit_inquiry`, `record_lead_event`), the decrypt function (`decrypt_inquirer_phone`), the unread-count RPC (`get_inbox_unread_count`), and the advisor-hardening cleanup.

**Goal**: After Phase 4, the Flutter client can call all four RPCs; the views from Sub-Phase C become queryable; the data layer is fully wired on the backend.

- [ ] T029 [US3,US4,US5,US7] Create migration file `supabase/migrations/20260527120006_create_decrypt_inquirer_phone_fn.sql` with the full body per data-model.md §2.6 + contracts/phase16-decrypt-inquirer-phone-fn.md. **BEFORE writing this migration, READ `supabase/migrations/20260510120004_profiles_vault_pii_helpers.sql` to identify the exact `pgsodium`/`vault` API surface this project uses** (e.g., does Phase 5 use `vault.decrypted_secrets` view + `pgsodium.crypto_aead_det_decrypt` directly, or a higher-level `vault.decrypt_secret_by_name(...)` wrapper, or a project-specific helper like `public.app_vault_secret(...)` from Phase 4?). Mirror Phase 5's pattern exactly — do NOT invent a new pattern. Then write: Function `public.decrypt_inquirer_phone(p_inquiry_id uuid) RETURNS text` SECURITY DEFINER. Body: load inquiry row, evaluate three-tier rule, return NULL when unauthorized, decrypt via the project's established API, catch decrypt errors and return NULL per FR-026. `GRANT EXECUTE TO authenticated`. **Acceptance**: `SELECT public.decrypt_inquirer_phone(gen_random_uuid())` from an authenticated session returns NULL (no matching inquiry); from an anon session, returns NULL or denial.
- [ ] T030 [US3,US6] Create migration file `supabase/migrations/20260527120009_create_submit_inquiry_rpc.sql` with the full body per data-model.md §2.9 + contracts/phase16-submit-inquiry-rpc.md. Function `public.submit_inquiry(p_listing_id uuid, p_sender_name text, p_inquirer_phone text, p_message text) RETURNS uuid` SECURITY DEFINER. Body: validate inputs (length, E.164 regex, listing approved + not self), encrypt phone via `pgsodium.crypto_aead_det_encrypt(plaintext, inquiry_id::text as AAD, key_id)`, capture IP+UA from server-side context (`inet_client_addr()` + `current_setting('request.headers', true)::jsonb->>'user-agent'`), atomic two-row INSERT (inquiry + companion `inquiry_sent` lead event), return inquiry id. `GRANT EXECUTE TO authenticated, anon`. Structured error codes: `invalid_sender_name`, `invalid_phone`, `invalid_message_length`, `listing_not_found`, `listing_not_approved`, `self_contact_blocked`.
- [ ] T031 [US1,US2,US6] Create migration file `supabase/migrations/20260527120010_create_record_lead_event_rpc.sql` with the full body per data-model.md §2.10 + contracts/phase16-record-lead-event-rpc.md. Function `public.record_lead_event(p_listing_id uuid, p_event_type text) RETURNS uuid` SECURITY DEFINER. Body: validate `p_event_type IN ('phone_revealed', 'whatsapp_clicked')` (NOT `inquiry_sent`; NOT `favorite_added`); validate listing approved; per-event-type field check (phone non-empty for phone_revealed; whatsapp non-empty for whatsapp_clicked); capture IP+UA; INSERT lead_events row; return id. `GRANT EXECUTE TO authenticated, anon`.
- [ ] T032 [US4] Create migration file `supabase/migrations/20260527120011_create_get_inbox_unread_count_rpc.sql` with the full body per data-model.md §2.11 + contracts/phase16-get-inbox-unread-count-rpc.md. Function `public.get_inbox_unread_count() RETURNS integer` SECURITY DEFINER + STABLE. Body: SQL `SELECT COUNT(*)::integer FROM public.inquiries i JOIN public.listings l ON l.id = i.listing_id WHERE l.publisher_user_id = auth.uid() AND i.status = 'new'`. `GRANT EXECUTE TO authenticated`. NOT granted to `anon`.
- [ ] T033 [US3,US4,US5,US6,US7] Create migration file `supabase/migrations/20260527120012_phase16_advisor_hardening.sql` per data-model.md §2.12. Body: re-assert `search_path` on every Phase 16 function via `ALTER FUNCTION ... SET search_path = pg_catalog, public[, vault]`; `REVOKE ALL ON TABLE public.inquiries, public.lead_events FROM PUBLIC, authenticated, anon`; explicit `GRANT SELECT ON public.v_inquiries_inbox, public.v_lead_events_publisher, public.v_lead_events_admin TO authenticated`; `GRANT UPDATE (status) ON public.inquiries TO authenticated` (column-restricted UPDATE so only the status column is mutable from authenticated clients).
- [ ] T034 [US3,US4,US5,US6,US7] Apply T029's migration via Supabase MCP `apply_migration`: name `"create_decrypt_inquirer_phone_fn"`, query = T029's file. Apply T030's migration: name `"create_submit_inquiry_rpc"`. Apply T031's migration: name `"create_record_lead_event_rpc"`. Apply T032's migration: name `"create_get_inbox_unread_count_rpc"`. Apply Phase 3's T025+T026 migrations now that the decrypt function exists: name `"create_v_inquiries_inbox_view"` + `"create_v_lead_events_views"`. Apply T033: name `"phase16_advisor_hardening"`. Verify each application is successful via the MCP response.
- [ ] T035 [US3,US5] Smoke test via Supabase MCP `execute_sql` (as a test publisher account with an approved listing): `SELECT public.submit_inquiry('<test listing id>'::uuid, 'Test Sender', '+963991234567', 'Smoke test message');` — expected: returns a UUID. Verify: `SELECT id, sender_name, status FROM public.inquiries WHERE id = '<returned uuid>'` returns the row with `status = 'new'`. Verify: `SELECT count(*) FROM public.lead_events WHERE listing_id = '<test listing id>' AND event_type = 'inquiry_sent' AND created_at > now() - interval '1 minute'` returns ≥ 1.
- [ ] T036 [US3,US5] Decrypt verification: `SELECT public.decrypt_inquirer_phone('<inquiry id from T035>')` as the listing's publisher → expected: returns `'+963991234567'`. Same query as a non-publisher non-admin → expected: returns NULL. Same query as an admin with `inquiries.view_all` → expected: returns `'+963991234567'`.
- [ ] T037 [US4] Transition-trigger smoke: `UPDATE public.inquiries SET status = 'seen' WHERE id = '<test id>'` succeeds; `UPDATE public.inquiries SET status = 'new' WHERE id = '<test id>' AND status = 'closed'` (first transition the row to closed via valid path, then try invalid regress) → expected SQLSTATE 23514 error mentioning `closed -> new`. Flip T029–T037 in the same commit.

**Phase Checkpoint**: All backend artifacts are live. The Flutter data layer (Phase 6) can call any of the four RPCs and query both views. RLS isolation holds; transition allowlist holds; Vault encrypt/decrypt holds; IP/UA capture into `lead_events.metadata` holds.

---

## Phase 5: Sub-Phase G — Localization (ARB additions)

**Purpose**: Add ~32 new bilingual keys to `app_ar.arb` + `app_en.arb` so Sub-Phases F and H can consume them.

**Goal**: After Phase 5, `flutter gen-l10n` regenerates `AppLocalizations` with all inquiry-related getters.

- [ ] T038 [P] [US1,US2,US3] Add to BOTH `lib/l10n/app_ar.arb` AND `lib/l10n/app_en.arb` in matched pairs. **ContactBlock additions** (4 keys; Phase 13 already ships `cta_call`, `cta_whatsapp`, `cta_send_inquiry`): `contact_call_disabled_tooltip`, `contact_whatsapp_disabled_tooltip`, `contact_dialer_unavailable`, `contact_whatsapp_app_unavailable`. Use Syrian Levantine Arabic copy (e.g., `contact_whatsapp_disabled_tooltip` Ar: "لم يضف الناشر رقم واتساب").
- [ ] T039 [P] [US3] Continue adding to both ARB files. **Inquiry form sheet** (14 keys): `inquiry_form_title`, `inquiry_form_name_label`, `inquiry_form_name_placeholder`, `inquiry_form_phone_label`, `inquiry_form_message_label`, `inquiry_form_message_placeholder`, `inquiry_form_message_counter` (with `{remaining}` placeholder), `inquiry_form_submit_button`, `inquiry_form_success_snackbar`, `inquiry_form_validation_name_required`, `inquiry_form_validation_phone_invalid`, `inquiry_form_validation_message_required`, `inquiry_form_validation_message_too_long`, `inquiry_form_submission_failed`.
- [ ] T040 [P] [US4] Continue adding to both ARB files. **Inbox page chrome + status badge** (11 keys): `inquiry_inbox_app_bar_title`, `inquiry_inbox_empty_state`, `inquiry_inbox_filter_status_label`, `inquiry_inbox_filter_listing_label`, `inquiry_inbox_load_more`, `inquiry_inbox_anonymous_sender_label`, `inquiry_status_new`, `inquiry_status_seen`, `inquiry_status_responded`, `inquiry_status_closed`, `inquiry_status_spam`.
- [ ] T041 [P] [US4] Continue adding to both ARB files. **Inquiry detail page** (9 keys): `inquiry_detail_app_bar_title`, `inquiry_detail_callback_phone_label`, `inquiry_detail_phone_unavailable_placeholder`, `inquiry_detail_tap_to_call_action`, `inquiry_detail_listing_link_label`, `inquiry_detail_mark_responded_action`, `inquiry_detail_mark_closed_action`, `inquiry_detail_reopen_to_seen_action`, `inquiry_detail_reopen_to_responded_action`.
- [ ] T042 [P] [US7] Continue adding to both ARB files. **Admin oversight** (3 keys): `admin_inquiries_tier_banner`, `admin_inquiries_app_bar_title`, `admin_inquiries_publisher_filter_label`. **Home AppBar action** (1 key): `home_inquiries_action_tooltip`.
- [ ] T043 [US1,US2,US3,US4,US7] Run `flutter gen-l10n` to regenerate `lib/l10n/app_localizations.dart`, `app_localizations_ar.dart`, `app_localizations_en.dart`. Verify all ~32 new getters exist in the generated file. Run `flutter analyze` — expected: zero new analyzer warnings. (The new keys are not yet consumed; Phase 7 and Phase 8 will consume them.) Flip T038–T043 in the same commit.

**Phase Checkpoint**: ARB files contain all needed keys; codegen succeeds; the app still builds and runs cleanly.

---

## Phase 6: Sub-Phase E — Domain + data layer for the inquiries feature

**Purpose**: Define the `Inquiry`, `LeadEvent`, `InquirySubmission` entities; the `InquiryRepository` + `LeadEventRepository` interfaces; the six use cases; the DTOs; the Supabase datasource; the two repository implementations. Wire DI codegen.

**Goal**: After Phase 6, calling `getIt<SubmitInquiry>()(submission)` writes an inquiry; `getIt<LoadInquiryInbox>()(filter)` returns paginated rows; the data path is fully testable from the Dart side.

- [ ] T044 [P] [US3,US4,US7] Create `lib/features/inquiries/domain/entities/inquiry.dart` per data-model.md §3.3. `class Inquiry extends Equatable` with 11 fields: `id`, `listingId`, `listingTitle`, `listingStatus`, `senderUserId`, `senderName`, `decryptedPhone` (nullable per FR-026), `message`, `status` (InquiryStatus), `createdAt`, `updatedAt`. `copyWith({InquiryStatus? status})` method. Imports: `package:equatable/equatable.dart`, `../../../listing_form/domain/entities/listing.dart` (for ListingStatus), `inquiry_status.dart`.
- [ ] T045 [P] [US6,US7] Create `lib/features/inquiries/domain/entities/lead_event.dart` per data-model.md §3.4. `class LeadEvent extends Equatable` with 6 fields: `id`, `listingId`, `userId` (nullable), `eventType` (LeadEventType), `metadata` (`Map<String, dynamic>?` — null for publisher tier per FR-014b), `createdAt`.
- [ ] T046 [P] [US3] Create `lib/features/inquiries/domain/entities/inquiry_submission.dart` per data-model.md §3.5. `class InquirySubmission extends Equatable` private constructor. Static `validate({listingId, senderName, phone, message}) => Result<InquirySubmission, Failure>` running 3 validation steps (name 1..100; phone E.164 via Phase 5 `PhoneNumber.tryParse`; message 1..2000). Returns `Result.failure(Failure.validation(<code>))` per-field. Imports: `package:equatable/equatable.dart`, `../../../../core/errors/{failure,result}.dart`, `../../../../shared/domain/value_objects/phone_number.dart`.
- [ ] T047 [P] [US3,US4,US7] Create `lib/features/inquiries/domain/repositories/inquiry_repository.dart` per data-model.md §3.6. Abstract class with 5 methods: `submitInquiry(InquirySubmission)`, `loadInbox({statusFilter, listingIdFilter, cursor, limit = 30})`, `loadDetail(String inquiryId)`, `updateStatus(String inquiryId, InquiryStatus newStatus)`, `loadUnreadCount()`. All return `Future<Result<...>>`. Imports per the data-model snippet.
- [ ] T048 [P] [US1,US2,US6,US7] Create `lib/features/inquiries/domain/repositories/lead_event_repository.dart` per data-model.md §3.6. Abstract class with 2 methods: `recordEvent({listingId, eventType})`, `loadByListing(listingId, {since})`. Imports per data-model.
- [ ] T049 [P] [US3] Create `lib/features/inquiries/domain/usecases/submit_inquiry.dart` — `@injectable` class wrapping `InquiryRepository.submitInquiry`. Single `call(InquirySubmission)` method.
- [ ] T050 [P] [US1,US2] Create `lib/features/inquiries/domain/usecases/record_lead_event.dart` — `@injectable` class wrapping `LeadEventRepository.recordEvent`. Single `call({String listingId, LeadEventType eventType})` method.
- [ ] T051 [P] [US4,US7] Create `lib/features/inquiries/domain/usecases/load_inquiry_inbox.dart` — `@injectable` class wrapping `InquiryRepository.loadInbox`. `call({statusFilter, listingIdFilter, cursor, limit = 30})`.
- [ ] T052 [P] [US4] Create `lib/features/inquiries/domain/usecases/load_inquiry_detail.dart` — `@injectable` class wrapping `InquiryRepository.loadDetail`.
- [ ] T053 [P] [US4] Create `lib/features/inquiries/domain/usecases/update_inquiry_status.dart` — `@injectable` class wrapping `InquiryRepository.updateStatus`.
- [ ] T054 [P] [US4] Create `lib/features/inquiries/domain/usecases/load_inbox_unread_count.dart` — `@injectable` class wrapping `InquiryRepository.loadUnreadCount`.
- [ ] T055 [P] [US3,US4,US7] Create `lib/features/inquiries/data/models/inquiry_dto.dart` mirroring the `v_inquiries_inbox` row shape per data-model. Fields: 11 columns from the view; `InquiryDto.fromJson(Map<String, dynamic>)` factory; `toEntity()` method constructing `Inquiry` from DTO. Handle the `inquirer_phone_decrypted` nullable column passing through to `Inquiry.decryptedPhone`.
- [ ] T056 [P] [US6,US7] Create `lib/features/inquiries/data/models/lead_event_dto.dart` mirroring `v_lead_events_publisher` (default tier) or `v_lead_events_admin` (admin tier). `metadata` field optional in the DTO; the data source decides which view to read based on a `tier` parameter.
- [ ] T057 [US3,US4,US6,US7] Create `lib/features/inquiries/data/datasources/supabase_inquiries_datasource.dart` per plan §Sub-Phase E step 9. `@injectable` class with constructor `SupabaseInquiriesDatasource(SupabaseClientWrapper _client)`. Methods:
  - `submitInquiry(InquirySubmission)` → `_client.raw.rpc('submit_inquiry', params: {...})`.
  - `loadInbox({...})` → `_client.raw.from('v_inquiries_inbox').select(...).order('created_at', ascending: false).order('id', ascending: false).limit(limit)` + optional `.lt('created_at', cursor)` for pagination.
  - `loadDetail(id)` → `.from('v_inquiries_inbox').select().eq('id', id).maybeSingle()`.
  - `updateStatus(id, newStatus)` → `.from('inquiries').update({'status': newStatus.wireValue}).eq('id', id)`. Catches PostgrestException with SQLSTATE 23514 and maps to `Failure.transitionInvalid`.
  - `loadUnreadCount()` → `.rpc('get_inbox_unread_count')`.
  - `recordLeadEvent({listingId, eventType})` → `.rpc('record_lead_event', params: {'p_listing_id': listingId, 'p_event_type': eventType.wireValue})`.
  - `loadLeadEventsByListing(listingId, {tier})` → query either `v_lead_events_publisher` or `v_lead_events_admin` based on tier.
- [ ] T058 [US3,US4] Create `lib/features/inquiries/data/repositories/inquiry_repository_impl.dart`. `@LazySingleton(as: InquiryRepository)` class delegating each method to `SupabaseInquiriesDatasource`. Wraps exceptions in `Failure.fromException`; returns `Result.success`/`Result.failure`.
- [ ] T059 [US1,US2,US6] Create `lib/features/inquiries/data/repositories/lead_event_repository_impl.dart`. `@LazySingleton(as: LeadEventRepository)` class delegating to `SupabaseInquiriesDatasource`'s `recordLeadEvent` + `loadLeadEventsByListing`.
- [ ] T060 [US3,US4,US6,US7] Run `flutter pub run build_runner build --delete-conflicting-outputs` to regenerate `lib/core/di/injection.config.dart`. Verify all 6 use cases + 2 repositories + 1 datasource are registered. Run `flutter analyze` → expected: zero new warnings. Flip T044–T060 in the same commit.

**Phase Checkpoint**: The full Dart data path is wired. `getIt<SubmitInquiry>()(InquirySubmission.validate(...).unwrap())` writes a real inquiry; `getIt<LoadInquiryInbox>()()` returns real rows; `getIt<RecordLeadEvent>()(listingId: ..., eventType: LeadEventType.phoneRevealed)` writes a real lead event.

---

## Phase 7: Sub-Phase F — Presentation (inbox + detail + form sheet + cubits + admin overlay)

**Purpose**: Build the publisher-facing inbox page + per-inquiry detail page + the inquiry-form modal sheet + the `ContactCtaCubit` + the `InquiriesUnreadCubit` + the admin oversight page + the supporting widgets (status badge, unread badge, message snippet, admin banner).

**Goal**: After Phase 7, navigating to `/inquiries` shows the real inbox; tapping a row opens the detail page; status mutations persist; the admin oversight page works for users with `inquiries.view_all`.

- [ ] T061 [US3] Implement `lib/features/inquiries/presentation/bloc/inquiry_form_bloc.dart` per plan §Sub-Phase F step 1. Events: `InquiryFormFieldChanged({field, value})`, `InquiryFormSubmitted()`. States: `InquiryFormEditing({name, phone, message, validationErrors})`, `InquiryFormSubmitting()`, `InquiryFormSubmitted(inquiryId)`, `InquiryFormFailed(failure)`. On submit: build `InquirySubmission`, validate, call `SubmitInquiry` use case. `@injectable` annotated.
- [ ] T062 [US3] Implement `lib/features/inquiries/presentation/sheets/inquiry_form_sheet.dart` per contracts/phase16-inquiry-form-sheet.md. `showModalBottomSheet`-compatible `StatefulWidget` that hosts `BlocProvider<InquiryFormBloc>`. Composition: 3 TextFields (name/phone/message) + character counter visible at ≥ 1600 chars per R-108 + submit button. Pre-population: when `getIt<AuthBloc>().state` is Authenticated, pre-fill name from `profiles.full_name` + phone from `profiles.phone`. Constructor: `InquiryFormSheet({required String listingId, super.key})`. Validation errors render localized labels per FR-012.
- [ ] T063 [US1,US2] Implement `lib/features/inquiries/presentation/bloc/contact_cta_cubit.dart` per plan §Sub-Phase F step 3. Cubit emitting `ContactCtaState({phone, whatsapp, showCall, showWhatsApp, whatsappEnabled, showInquiry, isSelfContact})`. Constructor: `ContactCtaCubit({required this.listing}) : super(_compute(listing, getIt<AuthBloc>()))`. The `_compute` static helper performs the FR-001d self-contact check + the FR-001a/b/c CTA visibility logic + Q1=B-refined strict-source-of-truth WhatsApp gate. `@injectable` annotated with `@factoryParam Listing listing`.
- [ ] T064 [US4] Implement `lib/features/inquiries/presentation/bloc/inquiry_inbox_bloc.dart` per plan §Sub-Phase F step 4. Events: `InquiryInboxOpened()`, `InquiryInboxRefreshRequested()`, `InquiryInboxMoreLoaded()`, `InquiryInboxStatusFilterChanged(InquiryStatus?)`, `InquiryInboxListingFilterChanged(String?)`. States: `InquiryInboxLoading`, `InquiryInboxLoaded({inquiries, hasMore, cursor, statusFilter, listingFilter})`, `InquiryInboxError(failure)`. Constructor injects `LoadInquiryInbox`. `@injectable`.
- [ ] T065 [US4,US7] Implement `lib/features/inquiries/presentation/widgets/inbox_status_badge.dart` per plan §Sub-Phase F step 10. Colored `Chip` (rendered via design tokens — never hex literal) keyed by `InquiryStatus`. Status labels read from ARB (`l10n.inquiry_status_new` etc.).
- [ ] T066 [US4] Implement `lib/features/inquiries/presentation/widgets/inquiry_message_snippet.dart` per plan §Sub-Phase F step 11. Truncates message to ~120 chars + ellipsis. Renders `Text` with `Theme.of(context).textTheme.bodySmall` per Constitution VI.
- [ ] T067 [US4] Implement `lib/features/inquiries/presentation/widgets/unread_count_badge.dart` per plan §Sub-Phase F step 9. Small circular badge composed from `AppRadii.full` + `Theme.of(context).colorScheme.error` (or similar accent token). Hidden when count is 0. Constructor: `UnreadCountBadge({required this.count, super.key})`.
- [ ] T068 [US7] Implement `lib/features/inquiries/presentation/widgets/admin_tier_banner.dart` per plan §Sub-Phase F step 12. Small banner widget reading from `l10n.admin_inquiries_tier_banner`; styled per design tokens; rendered only on the admin oversight page.
- [ ] T069 [US4,US7] Implement `lib/features/inquiries/presentation/pages/inquiry_inbox_page.dart` (REPLACES the Sub-Phase A stub) per contracts/phase16-inbox-page-composition.md. Composition: `AppBar` with `DeepLinkAwareBackButton` (Phase 15-extracted widget) + status/listing filter dropdowns; body is a `RefreshIndicator` wrapping a `ListView.builder` over `state.inquiries`; each row tile shows status badge + sender name (or "Anonymous" label) + decrypted phone (or "Phone unavailable" placeholder per FR-026) + listing title + message snippet + timestamp; tap → `context.push(AppRoutes.inquiryDetailFor(inquiry.id))`; pagination loads more on scroll past 80% mark. Empty state renders `l10n.inquiry_inbox_empty_state` per SC-012.
- [ ] T070 [US4] Implement `lib/features/inquiries/presentation/bloc/inquiry_detail_bloc.dart` per plan §Sub-Phase F step 6. Events: `InquiryDetailOpened(String id)`, `MarkResponded()`, `MarkClosed()`, `ReopenToSeen()`, `ReopenToResponded()`. States: `InquiryDetailLoading`, `InquiryDetailLoaded(inquiry)`, `InquiryDetailError(failure)`. On `InquiryDetailOpened`: call `LoadInquiryDetail`; if loaded inquiry's status is `new`, immediately dispatch `UpdateInquiryStatus(id, seen)` AND emit a side-effect call to `getIt<InquiriesUnreadCubit>().decrement()`. On any mutation event: call `UpdateInquiryStatus`, optimistically emit new Loaded state; on failure roll back. Constructor injects `LoadInquiryDetail`, `UpdateInquiryStatus`, `InquiriesUnreadCubit`. `@injectable`.
- [ ] T071 [US4] Implement `lib/features/inquiries/presentation/pages/inquiry_detail_page.dart` (REPLACES the Sub-Phase A stub). Composition: `AppBar` with `DeepLinkAwareBackButton`; body shows the full `message` text + the decrypted callback phone (with a "Tap to call" affordance that uses `url_launcher.launchUrl(Uri.parse('tel:...'))`) + the inquirer's name + the listing reference (tappable, navigates to `/listings/:id`) + the current status badge + 1-4 status-mutation buttons whose visibility depends on `state.inquiry.status.allowedTransitions` per FR-021a. The `closed → new` transition has NO UI affordance per Q2=B.
- [ ] T072 [US4,US7] Implement `lib/features/inquiries/presentation/bloc/inquiries_unread_cubit.dart` per plan §Sub-Phase F step 8. `@lazySingleton` Cubit. State: `InquiriesUnreadState({count, canShowEntry})`. Constructor wires `LoadInboxUnreadCount` + the existing `SupabaseClientWrapper` (for the one-time "owns ≥1 approved listing" check). Methods: `refresh()` (re-fetches both `canShowEntry` and `count`), `decrement()` (called by `InquiryDetailBloc` after `new → seen` transition).
- [ ] T073 [US7] Implement `lib/features/inquiries/presentation/pages/admin_inquiry_oversight_page.dart` (REPLACES the Sub-Phase A stub) per contracts/phase16-admin-oversight-overlay.md + R-106. The page composes a reused `InquiryInboxPage`-style widget tree with the `AdminTierBanner` at the top of the body + an additional `PublisherFilterDropdown` in the AppBar `actions:`. The `InquiryInboxBloc` is constructed with a `tier: AdminTier()` parameter so the underlying data source reads cross-publisher via the RLS `inquiries_select_admin` policy. The PublisherFilterDropdown queries publishers via the existing publisher/profile data path (or a thin lookup `SELECT DISTINCT publisher_user_id, full_name FROM listings JOIN profiles ON ... LIMIT 100`).
- [ ] T074 [US3,US4,US6,US7] Run `flutter pub run build_runner build --delete-conflicting-outputs` to regenerate `lib/core/di/injection.config.dart`. Verify all 5 BLoCs + 2 cubits are registered. Run `flutter analyze` → expected: zero new warnings.
- [ ] T075 [US4] Manual smoke test on Pixel 8 Pro AVD per memory `feedback_avd_acceptable_qa.md` + quickstart.md §6: sign in as a publisher with ≥ 1 approved listing and ≥ 1 pre-seeded `new`-status inquiry → navigate to `/inquiries` → confirm inbox renders newest-first with decrypted phone + status badge + message snippet → tap a row → confirm detail page renders + status auto-flips `new → seen` → flip to `responded` → confirm UI update + server-side persistence (verify via Supabase MCP `execute_sql`).
- [ ] T076 [US7] Manual smoke test: sign in as admin (a user with `inquiries.view_all`) → navigate to `/admin/inquiries` → confirm `AdminTierBanner` renders + cross-publisher rows visible + decrypted phone visible. Sign out, sign in as non-admin → manually navigate to `/admin/inquiries` URL → confirm redirect to `/home` per the route guard. Flip T061–T076 in the same commit.

**Phase Checkpoint**: The full publisher inbox UX is shippable. The admin oversight surface works. Status mutations persist. The unread-count cubit is registered as a singleton but not yet consumed (Sub-Phase H wires it into the home AppBar).

---

## Phase 8: Sub-Phase H — Entry-point wiring (ContactBlock rewire + home AppBar inbox action)

**Purpose**: Replace the Phase 13 `ContactBlock` Coming-soon snackbar handlers with the working CTAs; insert the `InquiriesAppBarAction` into the home page's AppBar; wire the `AppLifecycleListener` for badge refresh on app foreground-resume.

**Goal**: After Phase 8, the listing details page's three CTAs work end-to-end (Call, WhatsApp, Send Inquiry); the home page's AppBar shows the inbox icon with badge for publishers; the full Phase 16 feature is shippable.

- [ ] T077 [US1,US2,US3] Update `lib/features/listing_details/presentation/widgets/contact_block.dart` per contracts/phase16-contact-block-rewire.md. Changes:
  - Constructor signature: `const ContactBlock({super.key, required this.listing})` (was `const ContactBlock({super.key})`).
  - Add `final Listing listing;`.
  - Replace the `StatelessWidget.build` body with a `BlocProvider<ContactCtaCubit>` host providing `ContactCtaCubit(listing: listing)` via `getIt`'s `@factoryParam`.
  - Inside the provider, a `BlocBuilder<ContactCtaCubit, ContactCtaState>` returns `SizedBox.shrink()` when `state.isSelfContact`; otherwise renders the three CTAs preserving the existing button styles, icons, and order.
  - Call CTA handler: `_onCallPressed(context, state.phone!)` → `getIt<RecordLeadEvent>()(listingId: listing.id, eventType: LeadEventType.phoneRevealed)` THEN `launchUrl(Uri.parse('tel:$phone'))`; on launch failure show `SnackBar(content: Text(l10n.contact_dialer_unavailable))`.
  - WhatsApp CTA handler: similar but URL is `'https://wa.me/${state.whatsapp!.replaceAll('+', '')}'` with `LaunchMode.externalApplication`; event-type `whatsappClicked`.
  - Send Inquiry CTA handler: `showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => InquiryFormSheet(listingId: listing.id))`.
  - Delete the `_showComingSoon` helper.
  - Imports: `package:url_launcher/url_launcher.dart`, `package:flutter_bloc/flutter_bloc.dart`, `../../../../core/di/injection.dart`, the `Listing` type from Phase 10, `../../../inquiries/{domain,presentation}/...`.
- [ ] T078 [US1,US2,US3] Update `lib/features/listing_details/presentation/pages/listing_details_page.dart` `_SuccessBody` — change the `ContactBlock()` invocation to `ContactBlock(listing: aggregate.listing)`. No other change to the page.
- [ ] T079 [US4] Create `lib/features/home/presentation/widgets/inquiries_app_bar_action.dart` per contracts/phase16-home-appbar-inbox-action.md. `StatelessWidget` returning a `BlocBuilder<InquiriesUnreadCubit, InquiriesUnreadState>`. When `!state.canShowEntry` → `SizedBox.shrink()`. Otherwise renders a `Stack` of (a) `IconButton` with `Icons.inbox_outlined` (or `Icons.mark_email_unread_outlined` when count > 0), tooltip `l10n.home_inquiries_action_tooltip`, `onPressed: () => context.push(AppRoutes.inquiries)`; (b) `Positioned(top: AppSpacing.xs, end: AppSpacing.xs, child: UnreadCountBadge(count: state.count))` when count > 0.
- [ ] T080 [US4] Update `lib/features/home/presentation/pages/home_page.dart`:
  - Insert `const InquiriesAppBarAction()` into `AppBar.actions:` between the existing `LocaleToggleAction()` (currently `actions[0]`) and the existing sign-in/profile `IconButton` (currently `actions[1]`). After this edit: `actions[0]` = LocaleToggleAction; `actions[1]` = InquiriesAppBarAction; `actions[2]` = sign-in/profile IconButton.
  - Convert `HomePage` from `StatelessWidget` to `StatefulWidget` (if not already) so an `AppLifecycleListener` can be registered in `initState`. (Check the current shape; the Phase 13 home page may already be a `StatefulWidget` — preserve its existing state.)
  - In `_HomePageState.initState`: register `AppLifecycleListener(onResume: () => getIt<InquiriesUnreadCubit>().refresh())`. Also call `getIt<InquiriesUnreadCubit>().refresh()` once on first build so the badge is correct on cold launch.
  - In `dispose`: dispose the lifecycle listener.
  - Add the import `import '../widgets/inquiries_app_bar_action.dart';`.
- [ ] T081 [US1,US2,US3,US4] Run `flutter analyze` → expected: zero new warnings. Run `flutter build apk --debug --dart-define-from-file=.env.json` → expected: success.
- [ ] T082 [US1,US2,US3] Manual smoke test per quickstart.md §4 + §5: launch app on Pixel 8 Pro AVD; navigate to an approved listing whose `phone` AND `whatsapp` are set; tap Call → confirm dialer hand-off + lead event row exists (verify via Supabase MCP); tap WhatsApp → confirm WhatsApp/browser hand-off + lead event row exists; tap Send Inquiry → confirm modal sheet opens, fill form, submit → confirm success snackbar + atomic two-row insert (verify via Supabase MCP).
- [ ] T083 [US1,US2,US3] Manual smoke test edge cases: (a) listing with `phone` empty → Call CTA hidden; (b) listing with `whatsapp` empty (but `phone` set) → WhatsApp CTA rendered-but-disabled per Q1=B-refined; (c) sign in as the publisher of a listing → open that listing → confirm all 3 CTAs hidden per FR-001d (`ContactBlock` collapses to `SizedBox.shrink()`).
- [ ] T084 [US4] Manual smoke test the home AppBar inbox action: sign in as a publisher with ≥ 1 approved listing + ≥ 1 `new`-status inquiry → confirm inbox icon visible in home AppBar with badge showing count; tap → navigate to `/inquiries`; tap a `new` row → detail page auto-flips status to `seen` → return to home → confirm badge decremented; background then resume app → confirm badge refreshes. Sign out → confirm home AppBar shows NO inbox icon (the gate hides for zero-approved-listing users). Flip T077–T084 in the same commit.

**Phase Checkpoint**: All three contact CTAs work; the home AppBar inbox entry is visible for publishers with badges accurate in real-time; the full Phase 16 user-facing surface is shippable.

---

## Final Phase: Polish & cross-cutting verification

**Purpose**: Run the load-bearing grep gates + `pg_dump` smoke check + the SC-matrix final walk from quickstart.md §10.

- [ ] T085 [US5] Wire-level isolation verification per quickstart.md §3a + §3b + §3c (covers SC-006, SC-007, SC-015, SC-016). Run each sub-check via Supabase MCP `execute_sql` with `SET ROLE` simulation:
  - **(a) Cross-tenant publisher SELECT** (SC-006): capture publisher-A's `SELECT * FROM public.v_inquiries_inbox` → confirm zero rows whose `listing_id` belongs to publisher-B; capture publisher-B's query → confirm zero rows from publisher-A. Symmetric isolation.
  - **(b) Anonymous direct SELECT denied** (SC-007): `SET ROLE anon; SELECT * FROM public.inquiries;` → expected ERROR or 0 rows. `SELECT * FROM public.v_inquiries_inbox;` → expected ERROR (no GRANT to anon). `SELECT * FROM public.lead_events;` → expected ERROR or 0 rows. `RESET ROLE;`.
  - **(c) Cross-tenant UPDATE denied** (SC-015): as publisher-B, attempt `UPDATE public.inquiries SET status='closed' WHERE id IN (SELECT id FROM public.inquiries i JOIN public.listings l ON l.id = i.listing_id WHERE l.publisher_user_id = '<publisher-A's uuid>')` → expected: 0 rows affected (RLS USING predicate hides them). Cross-tenant write isolation matches cross-tenant read isolation.
  - **(d) Lead-events metadata tier visibility** (SC-016): as publisher-A, `SELECT * FROM public.v_lead_events_publisher LIMIT 1` → confirm response columns are `(id, listing_id, user_id, event_type, created_at)` only — NO `metadata` column. As admin with `inquiries.view_all`, `SELECT id, event_type, metadata FROM public.v_lead_events_admin LIMIT 1` → confirm `metadata` is a non-null JSONB with `ip` + `user_agent` keys. As publisher-A, attempt `SELECT * FROM public.v_lead_events_admin LIMIT 1` → expected: 0 rows (the view's defensive WHERE predicate fails closed).
- [ ] T086 [US3,US5] `pg_dump` smoke check per quickstart.md §3d + SC-005: submit a recognizable test inquiry (e.g., phone `+963991234567`); take a `pg_dump` of the live project; `grep -F '+963991234567' <dump>` → expected zero matches.
- [ ] T087 [US3,US4,US7] Grep gates per quickstart.md §9: zero matches for each of (a) `package:supabase_flutter|package:postgrest` under `lib/features/inquiries/domain/` + `presentation/`; (b) `Text(['\"]` (literal-string `Text()`) under `lib/features/inquiries/`; (c) `Color(0x[0-9A-Fa-f]{8})|fontSize:\\s*[0-9]+\\.[0-9]+` under `lib/features/inquiries/`; (d) `flutter_phone_direct_caller|firebase_messaging|sentry|amplitude|mixpanel` in `pubspec.yaml`; (e) `_showComingSoon` in `lib/features/listing_details/presentation/widgets/contact_block.dart`; (f) `user\\.role == 'admin'` under `lib/`; (g) [FR-024a guard per analysis C1] `grep -RE "WHERE\\s+updated_at\\s*=" lib/features/inquiries/data/` returns zero matches — defends against accidentally adding optimistic-concurrency to the status UPDATE path; (h) [FR-035 guard per analysis C2] `git diff <merge-base> -- lib/features/listing_details/presentation/widgets/per_listing_action_block.dart` returns zero changes — the Favorite/Share/Report stubs MUST remain untouched in this PR.
- [ ] T088 [US4] Vault decrypt failure handling per quickstart.md §6e + FR-026: corrupt one test inquiry's `inquirer_phone_encrypted` (via Supabase MCP `execute_sql` `UPDATE public.inquiries SET inquirer_phone_encrypted = '\\x00'::bytea WHERE id = '<test id>'`); open the inbox containing that inquiry → confirm row renders without crash; phone field shows the "Phone unavailable" placeholder; other rows render correctly. Restore by submitting a fresh test inquiry.
- [ ] T089 [US1..US7] Final SC matrix walk per quickstart.md §10: tick each of SC-001..SC-017 in `quickstart.md` AND in `specs/016-contact-inquiries/SC_MATRIX.md` (create the matrix file if absent, modeled on `specs/015-map-view/SC_MATRIX.md`). Any unticked SC becomes a deferred item recorded in `specs/016-contact-inquiries/DEFERRED.md`.
- [ ] T090 [US1..US7] Final commit: ensure all Phase 16 files (migrations, contracts, plan/spec/research/data-model/quickstart/tasks, lib/features/inquiries/, lib/features/home/widgets/inquiries_app_bar_action.dart, lib/l10n/app_{ar,en}.arb, lib/l10n/app_localizations*.dart, pubspec.yaml, pubspec.lock, lib/core/routing/app_router.dart, lib/features/listing_details/presentation/widgets/contact_block.dart, lib/features/listing_details/presentation/pages/listing_details_page.dart, lib/features/home/presentation/pages/home_page.dart, lib/core/di/injection.config.dart) are committed. Flip T085–T090 in the final commit.

**Phase Checkpoint**: All grep gates pass; `pg_dump` smoke check passes; the SC matrix is complete (or remaining items are explicitly deferred). The Phase 16 PR is ready for review.

---

## Touch-Fan Table

For each phase, list the shared files modified. The orchestrator uses this to (a) warn each sub-agent up front about expected file conflicts, (b) pick merge order least-touch-first.

- **Phase 1 (Sub-Phase A — Bootstrap)**: `pubspec.yaml`, `pubspec.lock`, `lib/core/routing/app_router.dart`, `lib/features/inquiries/domain/entities/inquiry_status.dart` (CREATE), `lib/features/inquiries/domain/entities/lead_event_type.dart` (CREATE), `lib/features/inquiries/presentation/pages/inquiry_inbox_page.dart` (CREATE stub), `lib/features/inquiries/presentation/pages/inquiry_detail_page.dart` (CREATE stub), `lib/features/inquiries/presentation/pages/admin_inquiry_oversight_page.dart` (CREATE stub), `lib/core/di/injection.config.dart` (REGENERATED but no new registrations).
- **Phase 2 (Sub-Phase B — Backend schema + trigger)**: `supabase/migrations/2026052712000{1,2,5}_*.sql` (CREATE), `supabase/docs/inquiries.md` (CREATE), `supabase/docs/lead_events.md` (CREATE). Vault key setup is out-of-band (no file touched).
- **Phase 3 (Sub-Phase C — Policies + views)**: `supabase/migrations/2026052712000{3,4,7,8}_*.sql` (CREATE), `supabase/docs/inquiries.md` (APPEND RLS matrix), `supabase/docs/lead_events.md` (APPEND RLS matrix).
- **Phase 4 (Sub-Phase D — RPCs + decrypt + advisor)**: `supabase/migrations/2026052712000{6,9,10,11,12}_*.sql` (CREATE).
- **Phase 5 (Sub-Phase G — Localization)**: `lib/l10n/app_ar.arb` (APPEND ~32 keys), `lib/l10n/app_en.arb` (APPEND ~32 keys), `lib/l10n/app_localizations.dart` (REGENERATED), `lib/l10n/app_localizations_ar.dart` (REGENERATED), `lib/l10n/app_localizations_en.dart` (REGENERATED).
- **Phase 6 (Sub-Phase E — Domain + data layer)**: `lib/features/inquiries/domain/entities/{inquiry,lead_event,inquiry_submission}.dart` (CREATE), `lib/features/inquiries/domain/repositories/{inquiry,lead_event}_repository.dart` (CREATE), `lib/features/inquiries/domain/usecases/*.dart` (6 CREATE), `lib/features/inquiries/data/models/{inquiry,lead_event}_dto.dart` (CREATE), `lib/features/inquiries/data/datasources/supabase_inquiries_datasource.dart` (CREATE), `lib/features/inquiries/data/repositories/{inquiry,lead_event}_repository_impl.dart` (CREATE), `lib/core/di/injection.config.dart` (REGENERATED — adds 9 registrations).
- **Phase 7 (Sub-Phase F — Presentation)**: `lib/features/inquiries/presentation/bloc/*.dart` (5 BLoCs + 2 cubits CREATE), `lib/features/inquiries/presentation/pages/inquiry_inbox_page.dart` (UPDATE — replaces stub), `lib/features/inquiries/presentation/pages/inquiry_detail_page.dart` (UPDATE — replaces stub), `lib/features/inquiries/presentation/pages/admin_inquiry_oversight_page.dart` (UPDATE — replaces stub), `lib/features/inquiries/presentation/sheets/inquiry_form_sheet.dart` (CREATE), `lib/features/inquiries/presentation/widgets/{inbox_status_badge,unread_count_badge,inquiry_message_snippet,admin_tier_banner}.dart` (CREATE), `lib/core/di/injection.config.dart` (REGENERATED — adds 7 more registrations).
- **Phase 8 (Sub-Phase H — Entry-point wiring)**: `lib/features/listing_details/presentation/widgets/contact_block.dart` (UPDATE — full rewire), `lib/features/listing_details/presentation/pages/listing_details_page.dart` (UPDATE — pass `listing` arg to ContactBlock; minimal one-line change), `lib/features/home/presentation/widgets/inquiries_app_bar_action.dart` (CREATE), `lib/features/home/presentation/pages/home_page.dart` (UPDATE — insert AppBar action + wire AppLifecycleListener).
- **Final Phase (Polish)**: `specs/016-contact-inquiries/SC_MATRIX.md` (CREATE), `specs/016-contact-inquiries/DEFERRED.md` (CREATE if needed).

**High-conflict files** (modified by multiple phases — orchestrator merges these LAST):

1. `lib/core/di/injection.config.dart` — regenerated by Phases 1, 6, 7. Always pure regeneration; no manual merge.
2. `lib/l10n/app_localizations*.dart` — regenerated by Phase 5. Pure regeneration.
3. `supabase/docs/inquiries.md` + `supabase/docs/lead_events.md` — created in Phase 2, appended in Phase 3. Section-aware append; no overlap.

**Cross-feature touches** (files OUTSIDE `lib/features/inquiries/` that Phase 16 modifies):

- `pubspec.yaml` + `pubspec.lock` (Phase 1)
- `lib/core/routing/app_router.dart` (Phase 1)
- `lib/features/listing_details/presentation/widgets/contact_block.dart` (Phase 8)
- `lib/features/listing_details/presentation/pages/listing_details_page.dart` (Phase 8 — one-line constructor change)
- `lib/features/home/presentation/pages/home_page.dart` (Phase 8 — AppBar actions insert + lifecycle listener wiring)
- `lib/features/home/presentation/widgets/inquiries_app_bar_action.dart` (Phase 8 — greenfield)
- `lib/l10n/app_{ar,en}.arb` (Phase 5)

---

## Dependency Audit

Re-reading plan.md §Phase Dependencies. For EVERY declared "Sub-Phase B depends on Sub-Phase A" line, the specific consumed symbol or file is named below. Anything that cannot be named is a false dependency.

| From | To | Specific consumed symbol/file (real, not "uses concepts") |
|------|-----|---------------------------------------------------------|
| Phase 3 (C) | Phase 2 (B) | `public.inquiries` + `public.lead_events` tables — defined in migrations `20260527120001_create_inquiries_table.sql` + `20260527120002_create_lead_events_table.sql`. Phase 3's policy migrations apply `CREATE POLICY ... ON public.inquiries` directly against these tables. **REAL.** |
| Phase 3 (C) | Phase 4 (D) | `public.decrypt_inquirer_phone(uuid)` function — defined in `20260527120006_create_decrypt_inquirer_phone_fn.sql`. Phase 3's `v_inquiries_inbox` view (`20260527120007`) projects `decrypt_inquirer_phone(i.id) AS inquirer_phone_decrypted`. The function migration's `20260527120006` filename sorts before the view's `20260527120007`, so apply order is satisfied. **REAL** (with file-ordering caveat). |
| Phase 4 (D) | Phase 2 (B) | `public.inquiries.inquirer_phone_encrypted` column + `public.lead_events` table — defined in `20260527120001` + `20260527120002`. Phase 4's `submit_inquiry` writes both rows; `decrypt_inquirer_phone` reads `inquirer_phone_encrypted`; `record_lead_event` writes `lead_events`; `get_inbox_unread_count` reads `inquiries`. **REAL.** |
| Phase 6 (E) | Phase 1 (A) | `InquiryStatus` enum at `lib/features/inquiries/domain/entities/inquiry_status.dart`; `LeadEventType` enum at `lib/features/inquiries/domain/entities/lead_event_type.dart`. Phase 6's `Inquiry.status` field is typed `InquiryStatus`; `LeadEvent.eventType` is `LeadEventType`. **REAL.** |
| Phase 6 (E) | Phase 3 (C) | `public.v_inquiries_inbox` view (defined in `20260527120007`); `public.v_lead_events_publisher` + `public.v_lead_events_admin` views (defined in `20260527120008`). Phase 6's `SupabaseInquiriesDatasource.loadInbox()` queries the inbox view; `loadLeadEventsByListing()` queries the lead-events views. **REAL.** |
| Phase 6 (E) | Phase 4 (D) | `public.submit_inquiry(uuid, text, text, text)` (`20260527120009`); `public.record_lead_event(uuid, text)` (`20260527120010`); `public.get_inbox_unread_count()` (`20260527120011`). Phase 6's datasource invokes all three via `.rpc(...)`. **REAL.** |
| Phase 7 (F) | Phase 1 (A) | `AppRoutes.inquiries` + `AppRoutes.inquiryDetail` + `AppRoutes.adminInquiries` constants in `lib/core/routing/app_router.dart`; `InquiryStatus.allowedTransitions` in `lib/features/inquiries/domain/entities/inquiry_status.dart`. Phase 7's pages are registered at these routes; the detail page's status-mutation buttons consult `allowedTransitions`. **REAL.** |
| Phase 7 (F) | Phase 6 (E) | Six use case classes at `lib/features/inquiries/domain/usecases/*.dart` (`SubmitInquiry`, `RecordLeadEvent`, `LoadInquiryInbox`, `LoadInquiryDetail`, `UpdateInquiryStatus`, `LoadInboxUnreadCount`); `Inquiry` + `LeadEvent` entities at `lib/features/inquiries/domain/entities/`. Phase 7's BLoCs inject every use case in their constructors. **REAL.** |
| Phase 7 (F) | Phase 5 (G) | Generated getters in `lib/l10n/app_localizations.dart` — specifically `inquiry_form_title`, `inquiry_inbox_app_bar_title`, `inquiry_detail_*`, `admin_inquiries_*`, `inquiry_status_*` (~25 of the 32 keys). Phase 7's pages + sheet + widgets read these getters. **REAL.** |
| Phase 8 (H) | Phase 1 (A) | `AppRoutes.inquiries` constant in `lib/core/routing/app_router.dart`. Phase 8's `InquiriesAppBarAction.onPressed` calls `context.push(AppRoutes.inquiries)`. **REAL.** |
| Phase 8 (H) | Phase 6 (E) | `RecordLeadEvent` use case at `lib/features/inquiries/domain/usecases/record_lead_event.dart`; `LeadEventType` enum (re-imported via the use case's param signature). Phase 8's `ContactBlock` Call + WhatsApp handlers invoke `getIt<RecordLeadEvent>()(listingId: ..., eventType: ...)`. **REAL.** |
| Phase 8 (H) | Phase 7 (F) | `ContactCtaCubit` at `lib/features/inquiries/presentation/bloc/contact_cta_cubit.dart`; `InquiryFormSheet` at `lib/features/inquiries/presentation/sheets/inquiry_form_sheet.dart`; `InquiriesUnreadCubit` at `lib/features/inquiries/presentation/bloc/inquiries_unread_cubit.dart`; `UnreadCountBadge` at `lib/features/inquiries/presentation/widgets/unread_count_badge.dart`. Phase 8's `ContactBlock` instantiates `ContactCtaCubit` + shows `InquiryFormSheet`; Phase 8's `InquiriesAppBarAction` consumes `InquiriesUnreadCubit` state + renders `UnreadCountBadge`. **REAL.** |
| Phase 8 (H) | Phase 5 (G) | `l10n.contact_dialer_unavailable`, `l10n.contact_whatsapp_app_unavailable`, `l10n.contact_whatsapp_disabled_tooltip`, `l10n.home_inquiries_action_tooltip` — generated getters in `lib/l10n/app_localizations.dart`. Phase 8's ContactBlock surfaces launcher-failure snackbars + the home AppBar action tooltip read these. **REAL.** |

**Audit result**: 13 declared dependencies; 13 named consumers. **Zero false dependencies.** No "easier in sequence" or "uses concepts from" wording remains; every edge is grounded in a specific symbol or file. The dependency graph is as lean as the structure permits.

---

## Wave Plan

Computed by topological sort of the dependency-audit graph above. Cap: 4 phases per wave unless tests-only / docs-only (cap 6 with justification). The `/wave all --auto` orchestrator executes this without re-deriving.

- **Wave 1**: Phase 1, Phase 2, Phase 5 (3 phases — no unmet deps; all kick off in parallel)
  - Phase 1 deps: none.
  - Phase 2 deps: none (the Vault key setup in T014 is out-of-band — not a Phase dep).
  - Phase 5 deps: none (ARB additions are textual; codegen regenerates from scratch).
- **Wave 2**: Phase 3, Phase 4 (2 phases — both depend only on Phase 2 from Wave 1)
  - Phase 3 deps: Phase 2 (tables) + Phase 4 (function name) — but Phase 4 runs in parallel here; the file-ordering trick (T029 lands `20260527120006` BEFORE T025's `20260527120007`) satisfies apply-order strictly via filename ascending. The phases run as separate sub-agents but the migration apply happens at Phase 4's T034 which applies BOTH Phase 3's view migrations AND Phase 4's function migrations in correct order.
  - Phase 4 deps: Phase 2 (tables).
- **Wave 3**: Phase 6 (1 phase — depends on Phases 1+3+4, all in earlier waves)
  - Phase 6 deps: Phase 1 (enums), Phase 3 (views), Phase 4 (RPCs). All in Waves 1+2.
- **Wave 4**: Phase 7 (1 phase — depends on Phases 1+5+6)
  - Phase 7 deps: Phase 1 (route constants + enum's `allowedTransitions`), Phase 5 (ARB getters), Phase 6 (use cases + entities).
- **Wave 5**: Phase 8 (1 phase — depends on Phases 1+5+6+7)
  - Phase 8 deps: Phase 1 (`AppRoutes.inquiries`), Phase 5 (ARB getters), Phase 6 (`RecordLeadEvent`), Phase 7 (`ContactCtaCubit`, `InquiryFormSheet`, `InquiriesUnreadCubit`, `UnreadCountBadge`).
- **Wave 6**: Final Phase (Polish — 1 phase, depends on all prior phases for verification scope)

**Total parallelism**: Wave 1 = 3×, Wave 2 = 2×, Wave 3..6 = 1× each. Wall-clock savings vs sequential 9-phase chain ≈ 40%.

**Critical path**: Phase 2 → Phase 4 → Phase 6 → Phase 7 → Phase 8 → Final Polish. Phases 1, 3, 5 fold into adjacent waves without elongating the critical path.

---

## Model Routing per Phase

Per the heuristic — Opus for atomic transactions / rollback / invariants / state machines / cross-currency / FX / posting / ledger / GL / RLS / concurrency; Sonnet for everything else (scaffolding, l10n, DAO CRUD, widgets, tests, docs).

- **Phase 1 (Sub-Phase A — Bootstrap)**: **Sonnet** (pubspec, route constants, enum-with-static-map, stub pages — all scaffolding).
- **Phase 2 (Sub-Phase B — Backend schema + transition trigger)**: **Opus** (state-machine transition trigger with allowed-pair lookup + RAISE EXCEPTION SQLSTATE; Vault-encrypted column; multi-table schema with FK ON DELETE RESTRICT — invariant-heavy backend work).
- **Phase 3 (Sub-Phase C — RLS policies + views)**: **Opus** (three-tier RLS rule is the load-bearing Constitution III boundary; metadata-masking column projection is the privacy invariant; non-trivial to get right — RLS bugs are catastrophic).
- **Phase 4 (Sub-Phase D — RPCs + Vault decrypt + advisor hardening)**: **Opus** (atomic two-row INSERT in `submit_inquiry`; Vault encrypt+decrypt via `pgsodium.crypto_aead_det_*`; SECURITY DEFINER + three-tier auth check in `decrypt_inquirer_phone`; IP/UA capture from trusted server context — all transaction-and-invariant work).
- **Phase 5 (Sub-Phase G — ARB localization)**: **Sonnet** (textual bilingual key additions; no logic).
- **Phase 6 (Sub-Phase E — Domain + data layer)**: **Sonnet** (entities, repository interfaces, use cases, DTOs, datasource — standard Clean Architecture CRUD scaffolding; the atomic-write guarantee is enforced server-side from Phase 4, not in this layer).
- **Phase 7 (Sub-Phase F — Presentation: inbox + detail + form sheet + cubits + admin)**: **Sonnet** (BLoC + Cubit scaffolding, widget trees, pagination, status-mutation UI — standard Flutter presentation work; the transition allowlist is server-enforced from Phase 2's trigger).
- **Phase 8 (Sub-Phase H — Entry-point wiring)**: **Sonnet** (ContactBlock handler swap, AppBar action insertion, AppLifecycleListener wiring — surgical Flutter edits).
- **Final Phase (Polish)**: **Sonnet** (grep gates, pg_dump check, SC matrix tick-through — verification work).

**Summary line for the orchestrator**:

```
Phase 1: Sonnet (bootstrap). Phase 2: Opus (state-machine trigger + Vault column). Phase 3: Opus (three-tier RLS). Phase 4: Opus (atomic two-row insert + Vault decrypt). Phase 5: Sonnet (ARB l10n). Phase 6: Sonnet (domain + data scaffolding). Phase 7: Sonnet (presentation). Phase 8: Sonnet (entry-point wiring). Final: Sonnet (polish + verification).
```

3 Opus phases (B, C, D — all in backend Waves 1+2) carry the load-bearing transaction-and-invariant work. 6 Sonnet phases (A, G, E, F, H, Polish) handle the scaffolding/CRUD/UI/textual work. Wave 2's two Opus phases run in parallel — both can saturate the Opus budget independently.
