# Implementation Plan: Contact, Inquiries & Lead Events

**Branch**: `016-contact-inquiries` | **Date**: 2026-05-25 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/016-contact-inquiries/spec.md`

## Summary

Phase 16 ships the publisher-to-visitor contact pipeline: the working implementation of the three Phase 13 Coming-soon stubs (Call / WhatsApp / Send inquiry) in `lib/features/listing_details/presentation/widgets/contact_block.dart`, plus the publisher-side inbox at `lib/features/inquiries/` that consumes the written inquiries, plus the lead-event substrate that captures every contact-tap as a row in `public.lead_events` for the eventual analytics surface. The plan ships: (a) two new Supabase migrations — `public.inquiries` with a Vault-backed `inquirer_phone` column per ADR-0001 and the soft-terminal `closed`-reopen status workflow + `public.lead_events` with the four-event-type CHECK constraint (`phone_revealed`, `whatsapp_clicked`, `inquiry_sent`, `favorite_added` — the last reserved for Phase 17 to avoid a schema change there); (b) two privileged SECURITY DEFINER RPCs — `public.submit_inquiry(...)` writing both the inquiry row AND its companion `inquiry_sent` lead event atomically in one transaction so a half-state is impossible per FR-009 + FR-017, and `public.record_lead_event(...)` writing a single tap-event row with server-captured IP+user-agent per Q5=B; (c) three RLS-gated read paths — `public.v_inquiries_inbox` view masking `inquirer_phone` for the cross-tenant default while a SECURITY DEFINER `public.decrypt_inquirer_phone(uuid)` function exposes plaintext to the three-tier authorized readers (listing publisher, signed-in original sender, admins with `inquiries.view_all`); a `public.v_lead_events_publisher` view masking `metadata` per FR-014b for the publisher tier; a `public.v_lead_events_admin` view (or column-GRANT toggle) exposing `metadata` for the admin tier; (d) one BEFORE UPDATE trigger on `inquiries` enforcing the allowed-transition allowlist server-side per FR-021a + FR-024 so an invalid transition (e.g., `closed → new`) is rejected at the data layer, not merely hidden in UI; (e) a new Flutter feature folder `lib/features/inquiries/` containing the publisher-facing inbox page + per-inquiry detail view + BLoCs + status-mutation use cases + the unread-count badge that the home AppBar consumes; (f) replacement of the Phase 13 `ContactBlock` three-stub handlers with working CTAs — Call records `phone_revealed` and hands off to the Android system dialer via `tel:`; WhatsApp records `whatsapp_clicked` and hands off via `https://wa.me/<E.164-without-plus>`; "Send inquiry" opens an `InquiryFormSheet` modal (E.164-validated phone, 2000-char-capped message per Q7=B) that calls the `submit_inquiry` RPC; the WhatsApp CTA renders-but-disables when `listings.whatsapp` is empty per Q1=B-refined; all three CTAs hide entirely when the viewer is the listing's own publisher per FR-001d; (g) addition of a top-level inbox AppBar action icon to the home page `actions:` slot (per R-103 placement decision derived from Q6=B), visible only when the signed-in user owns ≥1 approved listing, with an unread-count badge that updates on app foreground-resume + on pull-to-refresh + on every `new → seen` auto-transition; (h) ARB-driven localization for ~32 new bilingual keys covering the form chrome, inbox row + status labels, launcher-failure error messages, character-counter wording, and admin-oversight section labels; (i) ONE new pubspec package: `url_launcher: ^6.3.0` for `tel:` and `https:` (wa.me) launches — pre-locked as the Flutter-team-maintained Android-supported launcher with no Google-Play-Services hard dependency, consistent with Phase 15 R-88's direct-APK distribution rule.

**Technical approach**: The contact-inquiries feature follows the same Clean Architecture pattern as Phases 13–15 (`presentation/bloc` → `domain/usecases` → `domain/repositories` → `data/repositories` → `data/datasources` → `core/network`). The Vault-decrypt boundary (the Constitution Principle III + ADR-0001 load-bearing check) is enforced inside the `decrypt_inquirer_phone(uuid)` SECURITY DEFINER function whose body re-evaluates the three-tier visibility rule on every call — the Flutter `data/` layer never sees ciphertext, never sees a non-authorized-reader's plaintext, and never has any way to bypass the gate. The atomic inquiry-write boundary (the FR-009 + FR-017 no-partial-state guarantee) is enforced by wrapping the two-row insert in a single PL/pgSQL function so PostgreSQL's transaction semantics give us "both or neither" for free — no application-layer try/catch can leak a half-state. The transition-allowlist enforcement (Q2=B soft-terminal + Q8=A last-write-wins) is a BEFORE UPDATE trigger on `inquiries.status` that consults a static allowed-pair lookup; an invalid transition (e.g., `closed → new`) is rejected with a structured error code that the Flutter client surfaces as a localized message. The lead-event capture (Q5=B IP+UA into `metadata`) reads `inet_client_addr()` and `request.headers->>'user-agent'` from the trusted server-side request context — never from a client-supplied header — so a malicious client cannot spoof the captured IP. The inbox unread-count badge consumes a SECURITY DEFINER RPC `public.get_inbox_unread_count()` returning a single integer (the count of `new`-status inquiries on listings the caller owns); the RPC is cheap (indexed on `(listing_id, status)`) and the Flutter BLoC re-fetches on app foreground-resume + on every status-mutation event. The inquiry form is presented as a modal bottom sheet (R-98 — in-context, lower interruption cost than push-route, lower implementation cost than a wholly new route + page) anchored to the listing details surface. The publisher inbox is a paginated `ListView` with cursor-based pagination on `(created_at DESC, id DESC)` matching Phase 13's home-feed convention (R-104). The admin oversight surface (US7) is a thin route-guarded reuse of the publisher inbox page styled with an admin-tier banner — no separate page tree is built (R-106 fold-pattern). Lead-event reads for the publisher tier go through `v_lead_events_publisher` which omits `metadata` at the column level per FR-014b — no application-layer masking exists.

## Technical Context

**Language/Version**: Dart 3.9+ / Flutter 3.35.2 (existing); PostgreSQL 15 (Supabase) / PL/pgSQL.

**Primary Dependencies** (added in Phase 16 Sub-Phase A):

- `url_launcher: ^6.3.0` (NEW — Flutter-team-maintained launcher for `tel:` and `https:` schemes; pre-locked constitutional choice; Android-supported without Google Play Services hard dep, consistent with Phase 15 R-88's direct-APK distribution constraint)

**Inherited dependencies** (already in `pubspec.yaml`, no version change): `flutter`, `flutter_localizations`, `supabase_flutter`, `flutter_bloc`, `go_router`, `get_it`, `injectable`, `intl`, `cached_network_image`, `flutter_secure_storage`, `equatable`, `flutter_map` (Phase 15), `latlong2` (Phase 15), `geolocator` (Phase 15), `permission_handler` (Phase 15).

**Storage**: Supabase Postgres adds two new tables — `public.inquiries` and `public.lead_events` — under `supabase/migrations/`. Both consume the Phase 4 Vault scaffolding (`pgsodium` extension + `vault` schema enabled in `supabase/migrations/20260506120006_enable_vault.sql`) for the `inquirer_phone` encrypted column per ADR-0001. Both reference `public.listings(id)` (Phase 10) with `ON DELETE RESTRICT` per Q4=C. The `lead_events.user_id` and `inquiries.sender_user_id` columns reference `auth.users(id)` with `ON DELETE SET NULL` (per FR-013 + FR-014). Phase 16 adds four new SECURITY DEFINER PL/pgSQL functions (`submit_inquiry`, `record_lead_event`, `decrypt_inquirer_phone`, `get_inbox_unread_count`), one BEFORE UPDATE trigger function (`enforce_inquiry_transition`), and three views (`v_inquiries_inbox` masking phone for default reads, `v_lead_events_publisher` masking `metadata`, `v_lead_events_admin` exposing `metadata`). No new extension is enabled; `pgsodium` from Phase 4 covers Vault.

**Testing**: Per project convention (memory `feedback_no_new_tests.md`), no new automated tests are added in Phase 16. Existing tests remain. Manual UI verification on the reference Infinix Note 8 + Pixel 8 Pro AVD (per memory `user_test_device.md` and `feedback_avd_acceptable_qa.md`) is the gate; `quickstart.md` captures the recipe — including a `pg_dump | grep` smoke check confirming no plaintext inquirer phones ever serialize to a backup, and a wire-level capture confirming cross-tenant publisher isolation.

**Target Platform**: Android only (Constitution Principle XI). Minimum SDK per existing Phase 1 baseline. Reference device: Infinix Note 8 (Helio G80, 6 GB RAM, Android 10/11) for hands-on verification; Pixel 8 Pro emulator (Android 14, 412 dp width) for secondary checks per the standard project test matrix.

**Project Type**: Mobile app (Flutter) + Supabase backend — existing layout per `lib/features/<feature>/{presentation,domain,data}/` and `supabase/{migrations,functions,policies,seed}/`.

**Performance Goals**:

- Call CTA tap → dialer hand-off within 1 second + `phone_revealed` lead event inserted within the same window (SC-001).
- WhatsApp CTA tap → WhatsApp app hand-off within 1 second + `whatsapp_clicked` lead event inserted within the same window (SC-002).
- Inquiry form submission → success confirmation within 2 seconds, atomic 2-row insert guaranteed (SC-003).
- Publisher inbox initial load → first paint within 2 seconds on a standard Syrian 4G connection (cursor query on indexed `(listing_id, created_at DESC)`).
- Status mutation persist → server round-trip within 1 second; UI optimistic-update + reconcile-on-response (Q8=A last-write-wins).
- Unread-count badge refresh on app foreground-resume → updated count rendered within 1 second of resume event.

**Constraints**:

- The `inquirer_phone` plaintext MUST NEVER appear in any wire-level response to a non-authorized reader (anonymous, non-owner publisher, non-admin user) per FR-010 + FR-023 + SC-004 + SC-005 — enforced by the `decrypt_inquirer_phone` function's three-tier check + `v_inquiries_inbox` view masking the encrypted column.
- The two-row insert on inquiry submission MUST be atomic — never a half-state per FR-009 + FR-017. Enforced by wrapping both inserts in a single PL/pgSQL function body so PostgreSQL transaction semantics make it impossible to leak one without the other.
- The `lead_events.metadata` column carrying `{ip, user_agent}` MUST be visible to admins only per FR-014b + Q5=B. Enforced by column-level masking in `v_lead_events_publisher` (the publisher-tier read path omits the column).
- The inquiry-status state machine MUST allow exactly: `new → seen`, `seen → responded`, `responded → closed`, `closed → seen`, `closed → responded` per FR-021a + Q2=B. All other transitions MUST be rejected by a BEFORE UPDATE trigger — server-side enforcement, not UI-only hiding.
- The WhatsApp CTA's enabled-state MUST depend strictly on `listings.whatsapp` per FR-001b + Q1=B-refined — no fallback to `listings.phone`. The CTA is rendered-but-disabled when `whatsapp` is empty so the visitor sees the channel exists.
- The three contact CTAs MUST hide entirely when the signed-in viewer is the listing's own publisher per FR-001d (compare `auth.uid()` to `listing.publisher_user_id`).
- The top-level inbox entry MUST be hidden from users with zero approved listings per FR-019 (gate computed in the home-page AppBar action builder via `context.read<InquiriesUnreadCubit>().state.canShowEntry`).
- The unread-count badge MUST decrement in real time on every `new → seen` auto-transition per FR-019a (the inbox BLoC emits an `UnreadCountDecremented` event that the home AppBar listens to).
- Constitution IX-clean: no `package:supabase_flutter` imports outside `lib/features/inquiries/data/`. The `Inquiry`, `LeadEvent`, `InquiryStatus`, `LeadEventType`, `InquiryRepository`, `LeadEventRepository` all live in `domain/` and import zero Supabase types.
- Constitution V (Arabic-first localization) and VI (design tokens) apply — all ~32 new strings flow through ARB; all new widgets read from `Theme.of(context)` / project token API.
- The Phase 13 `ListingLocationBlock` MUST NOT be modified (Phase 12 Q8=A widget purity); the `ContactBlock` IS the surface Phase 16 modifies — its three Coming-soon snackbar handlers are replaced with working handlers but the surrounding widget tree (button styles, icons, ordering) is preserved per FR-001.
- The Phase 13 `PerListingActionBlock` (Favorite / Share / Report) MUST NOT be modified per FR-035 — those stubs remain until Phases 17, 18, and a future share-wiring phase take them over.

**Scale/Scope**:

- 8 sub-phases (A through H) organized into 4 waves with parallel execution where the dependency graph permits.
- 12 new Supabase migrations: 2 tables (`20260527120001`, `20260527120002`), 1 trigger (`...120005`), 1 decrypt function (`...120006`), 1 inbox view (`...120007`), 1 multi-view file (`...120008` packs both `v_lead_events_publisher` + `v_lead_events_admin`), 2 RPCs (`...120009`, `...120010`), 1 unread-count RPC (`...120011`), 2 policies migrations (`...120003`, `...120004`), and 1 advisor-hardening (`...120012`). Counts add to 12 files / 13 logical artifacts (the multi-view file packs 2). 0 schema changes to existing tables.
- 1 new Flutter feature folder (`lib/features/inquiries/`) with ~38 new Dart files (5 entities + 2 repository interfaces + 6 use cases + 2 DTOs + 1 datasource + 2 repository impls + 11 BLoC/cubit files counting per-bloc event + state splits + 3 pages + 1 sheet + 4 widgets = 37; plus 1 widget under `lib/features/home/presentation/widgets/`); 4 existing files updated (`app_router.dart`, `home_page.dart`, `contact_block.dart`, `listing_details_page.dart`); 1 new pubspec dependency.
- ~42 new bilingual ARB keys (Arabic + English): 4 ContactBlock-additions + 14 inquiry-form-sheet + 6 inbox-page + 5 inbox-status-badge + 9 inquiry-detail + 3 admin-oversight + 1 home-AppBar-action — final breakdown in Sub-Phase G tasks T038–T042.
- 12 plan-time research decisions (R-97 through R-108) resolved in `research.md`.
- 12 contract files in `contracts/` covering the `inquiries` + `lead_events` tables, the policies, the 4 RPCs, the trigger, the decrypt function, the views, the ContactBlock rewire, the inquiry form sheet, the publisher-inbox page composition, the home-AppBar inbox-action wiring, and the admin-oversight overlay.

---

## Constitution Check

*GATE: All 12 principles evaluated. No violations.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First Development (NON-NEGOTIABLE) | **Pass** | `specs/016-contact-inquiries/spec.md` exists with 7 user stories, 33+ FRs (FR-001..FR-035 plus FR-001a..FR-001d, FR-014a, FR-014b, FR-019a, FR-021a, FR-021b, FR-024a), 17 SCs, 8 clarifications resolved (3 in `/speckit-specify`: Q1 WhatsApp render-but-disable, Q2 soft-terminal closed-reopen, Q3 no publisher-side spam UX; 5 in `/speckit-clarify`: Q4 ON DELETE RESTRICT, Q5 IP+UA admin-only, Q6 top-level entry+badge, Q7 2000-char message cap, Q8 last-write-wins). This plan + the data-model + contracts + quickstart land before any implementation. |
| II. Source-Controlled Backend | **Pass** | Every backend artifact (2 tables, 4 functions, 1 trigger, 3 views, 2 policies migrations, 1 advisor-hardening) is checked in as files under `supabase/migrations/` and `supabase/policies/`. Per-table docs land under `supabase/docs/inquiries.md` and `supabase/docs/lead_events.md`. The Supabase MCP `apply_migration` is used to apply them; the canonical source-of-truth is the migration files. |
| III. Security-First Supabase (NON-NEGOTIABLE) | **Pass** | The Vault-encrypted `inquirer_phone` column is reachable only via the `decrypt_inquirer_phone(uuid)` SECURITY DEFINER function whose body re-evaluates the three-tier rule (sender / publisher / admin) on every call — no client-side filter is sufficient (FR-010 + FR-023 + Constitution III + ADR-0001). RLS on `inquiries` SELECT denies anonymous reads and partitions by the same three-tier rule (FR-022). RLS on `inquiries` UPDATE allows only the listing publisher AND only the allowed transitions per FR-024 + Q2=B (enforced by the `enforce_inquiry_transition` BEFORE UPDATE trigger). The `lead_events.metadata` IP+UA column is masked from the publisher tier per Q5=B via the `v_lead_events_publisher` view's column projection (FR-014b). All four new RPCs are SECURITY DEFINER with explicit `SET search_path = pg_catalog, public` to defend against schema-injection per the Phase 9 / Phase 10 advisor-hardening convention. |
| IV. Clean Architecture Flutter | **Pass** | The new `lib/features/inquiries/` feature follows the standard 3-layer structure: `presentation/{bloc,pages,widgets,sheets}/`, `domain/{entities,repositories,usecases}/`, `data/{datasources,models,repositories}/`. Business rules (transition allowlist, atomic-submit guarantee, three-tier decrypt gate, self-contact hide rule, unread-count refresh semantics) live in `domain/` use cases. The `InquiryInboxBloc`, `InquiryDetailBloc`, `InquiryFormBloc`, `ContactCtaCubit`, and `InquiriesUnreadCubit` extend BLoC / Cubit per Constitution IV. No `StatefulWidget` business-logic deviations. |
| V. Arabic-First Localization | **Pass** | ~32 new strings (Call/WhatsApp/Send-inquiry CTA labels — REUSED from Phase 13 ARB but re-verified; inquiry form chrome; inbox empty state; inbox row labels; per-inquiry detail view labels; status labels including localized `new`/`seen`/`responded`/`closed`/`spam`; status-mutation button labels; admin-tier banner; launcher-failure error messages — "WhatsApp unavailable", "Dialer unavailable") land in both `app_ar.arb` AND `app_en.arb` in Sub-Phase G. No inline `Text('...')` string literals in any new feature code; grep gate in quickstart. Arabic copy is Syrian-friendly Levantine (e.g., "إرسال استفسار" rather than stiffer MSA "إرسال استعلام"). |
| VI. Theme System & Design Tokens | **Pass** | All new widgets consume Phase 2 tokens (`AppSpacing`, `AppRadii`, `Theme.of(context).colorScheme`, `Theme.of(context).textTheme`). The `ContactBlock` rewire REUSES the existing button styles. The new widgets (`InquiryFormSheet`, `InboxPage`, `InquiryDetailPage`, `InboxStatusBadge`, `UnreadCountBadge`, `InquiryMessageSnippet`, `AdminTierBanner`) all read from `Theme.of(context)` + `AppSpacing` + `AppRadii`. No inline hex literals, no raw pixel constants, no untokenized typography. |
| VII. Dynamic Roles & Permissions | **Pass** | The admin oversight surface (US7) is gated by the `inquiries.view_all` permission seeded in the Phase 6 catalog (per IMPLEMENTATION_PLAN §9.1, default mapping: `admin` role). Phase 16 verifies the permission is present (no schema change to `permissions` table — the seed already includes it from Phase 6) and consumes it via `PermissionChecker.has('inquiries.view_all')` to (a) gate the admin route's `redirect`, (b) gate the admin-tier banner on the inbox page, (c) drive the RLS predicate in `inquiries` SELECT + `v_lead_events_admin`. No hardcoded role check (`if (user.role == 'admin')`) is introduced — verified by SC-011 grep gate. |
| VIII. Approval Workflow & Publisher Identity | **Pass** | Inquiries are written only against `status = 'approved'` listings (enforced by the `submit_inquiry` RPC's listing-validity check per FR-018). The publisher's private identity (legal_name, national_id, private_contact_methods per ADR-0001) is unaffected by Phase 16 — those columns remain in Vault and are not projected by any new view or RPC. The inquirer's `inquirer_phone` joins the same Vault-protected class per ADR-0001 phase mapping (Phase 16 row in the ADR's per-phase table) — it is encrypted at rest and decrypted only by authorized readers. The self-contact-hide rule (FR-001d) preserves publisher dignity. |
| IX. Future Backend Portability | **Pass** | The `Inquiry`, `LeadEvent`, `InquiryStatus`, `LeadEventType` entities, the `InquiryRepository` + `LeadEventRepository` interfaces, and all six use cases live in `lib/features/inquiries/domain/` and import zero `package:supabase_flutter` / zero `package:postgrest` / zero Supabase types. Concrete Supabase access lives in `lib/features/inquiries/data/datasources/supabase_inquiries_datasource.dart` behind the repository interfaces. A grep gate in quickstart verifies no Supabase imports under `lib/features/inquiries/domain/` or `lib/features/inquiries/presentation/`. |
| X. Testable AI Workflow | **Pass** | Every sub-phase task in Phase 2 (tasks.md, forthcoming) will carry explicit acceptance criteria derived from the FRs and SCs in `spec.md`. The `quickstart.md` captures end-to-end manual verification with one step per SC including the load-bearing wire-level capture for SC-004 (cross-tenant publisher isolation) and the `pg_dump \| grep` smoke check for SC-005 (no plaintext phone leakage). Wire-level inspection commands and SQL fixture queries are spelled out. The `/wave` orchestrator uses the Touch-fan notes below to merge sub-phases in conflict-free order. |
| XI. Android-First MVP | **Pass** | The single new dependency `url_launcher: ^6.3.0` ships first-class Android support; it does NOT require Google Play Services. The `tel:` and `https:` URI schemes are part of the Android OS contract (the system dialer + browser/WhatsApp handle them). Android manifest gains NO new permissions in Phase 16 — `tel:` does not require `CALL_PHONE` because we use ACTION_DIAL (the dialer opens pre-populated; the user confirms), and `https:` requires no permission. No iOS Info.plist, no Flutter Web, no desktop targets. |
| XII. No Hidden Product Decisions | **Pass** | All 8 product clarifications (3 from `/speckit-specify` + 5 from `/speckit-clarify`) are recorded in `spec.md`'s "Clarifications" section with rationale. The 12 plan-time research decisions (R-97..R-108) are recorded in `research.md`. Future-spec deferrals (inquirer-side "my inquiries" view, publisher-side spam-flagging UX, rate limiting, listing-transfer mechanics, publisher analytics dashboard, Realtime fan-out + FCM push) are explicitly forward-stated in `spec.md` Assumptions + this plan's research decisions. No silent product picks: the inquiry form modal-vs-route shape, the top-level inbox entry placement, the character-counter trigger threshold, and the admin oversight surface design are all explicitly decided in `research.md`. |

**Result**: All gates pass. `## Complexity Tracking` is empty.

---

## Project Structure

### Documentation (this feature)

```text
specs/016-contact-inquiries/
├── plan.md                     # This file (/speckit-plan output)
├── spec.md                     # /speckit-specify + /speckit-clarify output (committed)
├── research.md                 # Phase 0 output (R-97..R-108)
├── data-model.md               # Phase 1 output (full SQL migration bodies + Dart entities + FR/SC verification map)
├── quickstart.md               # Phase 1 output (end-to-end manual recipe)
├── contracts/
│   ├── phase16-inquiries-table.md
│   ├── phase16-lead-events-table.md
│   ├── phase16-inquiries-policies.md
│   ├── phase16-lead-events-policies.md
│   ├── phase16-submit-inquiry-rpc.md
│   ├── phase16-record-lead-event-rpc.md
│   ├── phase16-decrypt-inquirer-phone-fn.md
│   ├── phase16-get-inbox-unread-count-rpc.md
│   ├── phase16-enforce-inquiry-transition-trigger.md
│   ├── phase16-contact-block-rewire.md
│   ├── phase16-inquiry-form-sheet.md
│   ├── phase16-inbox-page-composition.md
│   ├── phase16-home-appbar-inbox-action.md
│   └── phase16-admin-oversight-overlay.md
└── checklists/
    └── requirements.md         # /speckit-specify quality checklist (committed)
```

### Source Code (repository root)

```text
H:\alnujom-project\
├── lib/
│   ├── core/
│   │   ├── routing/
│   │   │   └── app_router.dart                                       # UPDATE — add AppRoutes.inquiries + AppRoutes.inquiryDetail(id) + AppRoutes.adminInquiries + GoRoute registrations
│   │   └── security/
│   │       └── permission_checker.dart                               # READ-ONLY — consumed by admin route guard; no edit
│   ├── features/
│   │   ├── listing_details/
│   │   │   └── presentation/
│   │   │       ├── widgets/
│   │   │       │   └── contact_block.dart                            # UPDATE — replace 3 Coming-soon snackbar handlers with real handlers
│   │   │       └── pages/
│   │   │           └── listing_details_page.dart                     # UPDATE — pass listing arg to ContactBlock
│   │   ├── home/
│   │   │   └── presentation/
│   │   │       ├── pages/
│   │   │       │   └── home_page.dart                                # UPDATE — insert InquiriesAppBarAction in AppBar actions
│   │   │       └── widgets/
│   │   │           └── inquiries_app_bar_action.dart                 # CREATE
│   │   └── inquiries/                                                # CREATE — new feature folder
│   │       ├── data/
│   │       │   ├── datasources/
│   │       │   │   └── supabase_inquiries_datasource.dart            # CREATE
│   │       │   ├── models/
│   │       │   │   ├── inquiry_dto.dart                              # CREATE
│   │       │   │   └── lead_event_dto.dart                           # CREATE
│   │       │   └── repositories/
│   │       │       ├── inquiry_repository_impl.dart                  # CREATE
│   │       │       └── lead_event_repository_impl.dart               # CREATE
│   │       ├── domain/
│   │       │   ├── entities/
│   │       │   │   ├── inquiry.dart                                  # CREATE
│   │       │   │   ├── lead_event.dart                               # CREATE
│   │       │   │   ├── inquiry_status.dart                           # CREATE (Sub-Phase A)
│   │       │   │   ├── lead_event_type.dart                          # CREATE (Sub-Phase A)
│   │       │   │   └── inquiry_submission.dart                       # CREATE
│   │       │   ├── repositories/
│   │       │   │   ├── inquiry_repository.dart                       # CREATE
│   │       │   │   └── lead_event_repository.dart                    # CREATE
│   │       │   └── usecases/
│   │       │       ├── submit_inquiry.dart                           # CREATE
│   │       │       ├── record_lead_event.dart                        # CREATE
│   │       │       ├── load_inquiry_inbox.dart                       # CREATE
│   │       │       ├── load_inquiry_detail.dart                      # CREATE
│   │       │       ├── update_inquiry_status.dart                    # CREATE
│   │       │       └── load_inbox_unread_count.dart                  # CREATE
│   │       └── presentation/
│   │           ├── bloc/
│   │           │   ├── inquiry_inbox_bloc.dart                       # CREATE
│   │           │   ├── inquiry_inbox_event.dart                      # CREATE
│   │           │   ├── inquiry_inbox_state.dart                      # CREATE
│   │           │   ├── inquiry_detail_bloc.dart                      # CREATE
│   │           │   ├── inquiry_detail_event.dart                     # CREATE
│   │           │   ├── inquiry_detail_state.dart                     # CREATE
│   │           │   ├── inquiry_form_bloc.dart                        # CREATE
│   │           │   ├── inquiry_form_event.dart                       # CREATE
│   │           │   ├── inquiry_form_state.dart                       # CREATE
│   │           │   ├── inquiries_unread_cubit.dart                   # CREATE
│   │           │   └── contact_cta_cubit.dart                        # CREATE
│   │           ├── pages/
│   │           │   ├── inquiry_inbox_page.dart                       # CREATE (stub in A; fills in F)
│   │           │   ├── inquiry_detail_page.dart                      # CREATE (stub in A; fills in F)
│   │           │   └── admin_inquiry_oversight_page.dart             # CREATE (stub in A; fills in F)
│   │           ├── sheets/
│   │           │   └── inquiry_form_sheet.dart                       # CREATE
│   │           └── widgets/
│   │               ├── inbox_status_badge.dart                       # CREATE
│   │               ├── unread_count_badge.dart                       # CREATE
│   │               ├── inquiry_message_snippet.dart                  # CREATE
│   │               └── admin_tier_banner.dart                        # CREATE
│   └── l10n/
│       ├── app_ar.arb                                                # UPDATE — add ~32 Arabic keys
│       └── app_en.arb                                                # UPDATE — add same ~32 English keys
├── pubspec.yaml                                                      # UPDATE — add url_launcher: ^6.3.0
└── supabase/
    ├── migrations/
    │   ├── 20260527120001_create_inquiries_table.sql                 # CREATE
    │   ├── 20260527120002_create_lead_events_table.sql               # CREATE
    │   ├── 20260527120003_create_inquiries_policies.sql              # CREATE
    │   ├── 20260527120004_create_lead_events_policies.sql            # CREATE
    │   ├── 20260527120005_create_enforce_inquiry_transition_trigger.sql  # CREATE
    │   ├── 20260527120006_create_decrypt_inquirer_phone_fn.sql       # CREATE
    │   ├── 20260527120007_create_v_inquiries_inbox_view.sql          # CREATE
    │   ├── 20260527120008_create_v_lead_events_views.sql             # CREATE
    │   ├── 20260527120009_create_submit_inquiry_rpc.sql              # CREATE
    │   ├── 20260527120010_create_record_lead_event_rpc.sql           # CREATE
    │   ├── 20260527120011_create_get_inbox_unread_count_rpc.sql      # CREATE
    │   └── 20260527120012_phase16_advisor_hardening.sql              # CREATE
    └── docs/
        ├── inquiries.md                                              # CREATE
        └── lead_events.md                                            # CREATE
```

**Structure Decision**: Phase 16 adds one new feature folder (`lib/features/inquiries/`) following the established Clean Architecture pattern from Phases 5–15. Four existing files receive entry-point additions (`app_router.dart`, `contact_block.dart`, `listing_details_page.dart`, `home_page.dart`) — minimal patches per file. Twelve new Supabase migrations land under `supabase/migrations/` (each narrowly scoped to one artifact for review-ability, matching the Phase 7/9/10 multi-migration convention). One new pubspec dependency (`url_launcher`). No new packages outside `lib/features/inquiries/{data,domain,presentation}/`.

---

## Phase Dependencies

> **User-mandated discipline (per /speckit-plan invocation)**: Every "Sub-Phase B depends on Sub-Phase A" line below names the specific file path OR exported symbol that B consumes from A. Lines like "easier in sequence" or "uses concepts from" are FORBIDDEN. Self-audit count is at the end of this section.

### Sub-Phase A — Bootstrap: pubspec, route slots, domain skeleton

**Scope**:

1. Add `url_launcher: ^6.3.0` to `pubspec.yaml`; run `flutter pub get`.
2. Add the following route constants to `lib/core/routing/app_router.dart`:
   - `AppRoutes.inquiries = '/inquiries'` (publisher inbox)
   - `AppRoutes.inquiryDetail = '/inquiries/:id'` + a helper `AppRoutes.inquiryDetailFor(String id) => '/inquiries/$id'`
   - `AppRoutes.adminInquiries = '/admin/inquiries'` (admin oversight)
   - Plus matching `AppRouteNames.*` constants for go_router named routes per Phase 13 R-71 pattern.
3. Register three `GoRoute` entries: `/inquiries` → stub `InquiryInboxPage` (filled in Sub-Phase F); `/inquiries/:id` → stub `InquiryDetailPage`; `/admin/inquiries` → stub `AdminInquiryOversightPage` with a `redirect:` that calls `PermissionChecker.has('inquiries.view_all')` and 404s to home if denied.
4. Create skeleton directories under `lib/features/inquiries/` for `data/{datasources,models,repositories}/`, `domain/{entities,repositories,usecases}/`, `presentation/{bloc,pages,sheets,widgets}/`.
5. Create `lib/features/inquiries/domain/entities/inquiry_status.dart` defining the `enum InquiryStatus { new_, seen, responded, closed, spam }` (note: `new_` is the Dart-safe name since `new` is reserved) and an `allowedTransitions` static-method utility returning the set of valid transitions per FR-021a + Q2=B: `new_ → seen`; `seen → responded`, `closed`; `responded → closed`, `seen`; `closed → seen, responded`. The `spam` enum value has no outbound transitions in this allowlist (per Q3=B, Phase 16 ships no write path TO `spam` from the publisher tier; the value is read-only for the publisher).
6. Create `lib/features/inquiries/domain/entities/lead_event_type.dart` defining the `enum LeadEventType { phoneRevealed, whatsappClicked, inquirySent, favoriteAdded }` — `favoriteAdded` is exported here even though Phase 16 ships no write path; Phase 17 will consume it without a domain-layer change per FR-014.
7. Create stub `lib/features/inquiries/presentation/pages/inquiry_inbox_page.dart` and `inquiry_detail_page.dart` and `admin_inquiry_oversight_page.dart` — each rendering an empty `Scaffold` with `AppBar` + placeholder body — wired to the routes so the dependency graph is testable end-to-end before Sub-Phase F fills them.

**In-spec deps**: none.

**Cross-phase deps**:

- A imports `package:alnujom/core/security/permission_checker.dart` (Phase 6) for the `/admin/inquiries` route's `redirect` predicate. The file already exists; no churn.

**Touch fan**: `pubspec.yaml`, `lib/core/routing/app_router.dart`, `lib/features/inquiries/domain/entities/inquiry_status.dart` (CREATE), `lib/features/inquiries/domain/entities/lead_event_type.dart` (CREATE), `lib/features/inquiries/presentation/pages/inquiry_inbox_page.dart` (CREATE stub), `lib/features/inquiries/presentation/pages/inquiry_detail_page.dart` (CREATE stub), `lib/features/inquiries/presentation/pages/admin_inquiry_oversight_page.dart` (CREATE stub).

---

### Sub-Phase B — Backend schema: `inquiries` + `lead_events` tables + transition trigger

**Scope**:

1. Create migration `supabase/migrations/20260527120001_create_inquiries_table.sql`:
   - Table `public.inquiries` with columns per FR-013: `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`, `listing_id uuid NOT NULL REFERENCES public.listings(id) ON DELETE RESTRICT` per Q4=C, `sender_user_id uuid NULL REFERENCES auth.users(id) ON DELETE SET NULL`, `sender_name text NOT NULL CHECK (length(trim(sender_name)) BETWEEN 1 AND 100)`, `inquirer_phone_encrypted bytea NULL` (Vault-encrypted ciphertext column — populated by the `submit_inquiry` RPC via `vault.encrypt(...)` per ADR-0001; plaintext never enters the column directly), `inquirer_phone_key_id uuid NOT NULL` (Vault key identifier for the encryption operation; defaulted to a project-wide key created via `vault.create_secret(...)` in a one-time setup or via this migration's preamble), `message text NOT NULL CHECK (length(trim(message)) BETWEEN 1 AND 2000)` per Q7=B, `status text NOT NULL DEFAULT 'new' CHECK (status IN ('new','seen','responded','closed','spam'))`, `created_at timestamptz NOT NULL DEFAULT now()`, `updated_at timestamptz NOT NULL DEFAULT now()`.
   - Indexes per FR-015: `CREATE INDEX idx_inquiries_listing_created ON public.inquiries (listing_id, created_at DESC)`; `CREATE INDEX idx_inquiries_listing_status ON public.inquiries (listing_id, status, created_at DESC) WHERE status IN ('new','seen','responded')`; `CREATE INDEX idx_inquiries_sender ON public.inquiries (sender_user_id) WHERE sender_user_id IS NOT NULL`.
   - Trigger `set_updated_at` (reuses the project-wide `public.set_updated_at()` helper from Phase 4) — BEFORE UPDATE on row, sets `updated_at = now()`.
   - `ALTER TABLE public.inquiries ENABLE ROW LEVEL SECURITY`.
2. Create migration `supabase/migrations/20260527120002_create_lead_events_table.sql`:
   - Table `public.lead_events` with columns per FR-014: `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`, `listing_id uuid NOT NULL REFERENCES public.listings(id) ON DELETE RESTRICT` per Q4=C, `user_id uuid NULL REFERENCES auth.users(id) ON DELETE SET NULL`, `event_type text NOT NULL CHECK (event_type IN ('phone_revealed','whatsapp_clicked','inquiry_sent','favorite_added'))`, `metadata jsonb NULL`, `created_at timestamptz NOT NULL DEFAULT now()`.
   - Indexes per FR-015: `CREATE INDEX idx_lead_events_listing_created ON public.lead_events (listing_id, created_at DESC)`; `CREATE INDEX idx_lead_events_listing_type ON public.lead_events (listing_id, event_type, created_at DESC)`.
   - `ALTER TABLE public.lead_events ENABLE ROW LEVEL SECURITY`.
3. Create migration `supabase/migrations/20260527120005_create_enforce_inquiry_transition_trigger.sql`:
   - Function `public.enforce_inquiry_transition()` returning `trigger` as `SECURITY DEFINER SET search_path = pg_catalog, public`: on UPDATE, if `OLD.status = NEW.status` return `NEW`; otherwise validate the `(OLD.status, NEW.status)` pair against the static allowlist `[('new','seen'), ('seen','responded'), ('seen','closed'), ('responded','closed'), ('responded','seen'), ('closed','seen'), ('closed','responded')]` (covers Q2=B soft-terminal reopen) and additionally allow any-non-spam-state → `'spam'` (so future admin moderation can flip); if the pair is invalid, `RAISE EXCEPTION 'invalid_inquiry_transition: % -> %', OLD.status, NEW.status USING ERRCODE = '23514'`. Return `NEW` for valid transitions.
   - Trigger `trg_inquiries_enforce_transition BEFORE UPDATE OF status ON public.inquiries FOR EACH ROW EXECUTE FUNCTION public.enforce_inquiry_transition()`.
4. Create `supabase/docs/inquiries.md` and `supabase/docs/lead_events.md` documenting columns, RLS posture (forward-stated; populated by Sub-Phase C), transition allowlist, EXPLAIN expectations, and the Vault-encrypted-column contract.

**In-spec deps**: none.

**Cross-phase deps**:

- B's `inquiries.listing_id` and `lead_events.listing_id` reference `public.listings(id)` (Phase 10's `supabase/migrations/20260519120002_create_listings.sql`).
- B's `inquiries.sender_user_id` and `lead_events.user_id` reference `auth.users(id)` (Phase 1 Supabase baseline; Phase 5 profile rows trigger off this).
- B's `set_updated_at` trigger consumes `public.set_updated_at()` function defined in `supabase/migrations/20260506120002_create_profiles.sql` (Phase 4).
- B's Vault-encrypted column `inquiries.inquirer_phone_encrypted` consumes the `pgsodium` extension + `vault` schema enabled in `supabase/migrations/20260506120006_enable_vault.sql` (Phase 4). The actual encrypt/decrypt operations are written by Sub-Phase D following the Phase 5 `20260510120004_profiles_vault_pii_helpers.sql` pattern.

**Touch fan**: `supabase/migrations/20260527120001_create_inquiries_table.sql` (CREATE), `supabase/migrations/20260527120002_create_lead_events_table.sql` (CREATE), `supabase/migrations/20260527120005_create_enforce_inquiry_transition_trigger.sql` (CREATE), `supabase/docs/inquiries.md` (CREATE), `supabase/docs/lead_events.md` (CREATE).

---

### Sub-Phase C — Backend policies + views (RLS three-tier rule + metadata masking)

**Scope**:

1. Create migration `supabase/migrations/20260527120003_create_inquiries_policies.sql`:
   - SELECT policy `inquiries_select_publisher`: `USING (EXISTS (SELECT 1 FROM public.listings l WHERE l.id = inquiries.listing_id AND l.publisher_user_id = auth.uid()))`.
   - SELECT policy `inquiries_select_sender`: `USING (sender_user_id = auth.uid() AND sender_user_id IS NOT NULL)`.
   - SELECT policy `inquiries_select_admin`: `USING (public.current_user_has_permission('inquiries.view_all'))`.
   - INSERT: blocked at the table level (`REVOKE INSERT ON public.inquiries FROM authenticated, anon`); writes go through the `submit_inquiry` RPC (Sub-Phase D) which is SECURITY DEFINER.
   - UPDATE policy `inquiries_update_publisher`: `USING (EXISTS (SELECT 1 FROM public.listings l WHERE l.id = inquiries.listing_id AND l.publisher_user_id = auth.uid())) WITH CHECK (...same predicate...)`. The `enforce_inquiry_transition` trigger from Sub-Phase B validates the transition; the policy validates the actor. No sender-side or anonymous-side UPDATE policy is created (FR-024).
   - DELETE: blocked entirely (no policy; the table's RLS default of "deny" applies). Inquiries are immutable historical records.
2. Create migration `supabase/migrations/20260527120004_create_lead_events_policies.sql`:
   - SELECT policy `lead_events_select_publisher`: `USING (EXISTS (SELECT 1 FROM public.listings l WHERE l.id = lead_events.listing_id AND l.publisher_user_id = auth.uid()))`. Paired with the `v_lead_events_publisher` view (Sub-Phase C step 4) which omits the `metadata` column at projection level per FR-014b.
   - SELECT policy `lead_events_select_admin`: `USING (public.current_user_has_permission('inquiries.view_all'))`. Admins select from `v_lead_events_admin` which projects every column including `metadata`.
   - INSERT/UPDATE/DELETE: all blocked at the table level (`REVOKE INSERT, UPDATE, DELETE ON public.lead_events FROM authenticated, anon`); writes go through `record_lead_event` RPC (Sub-Phase D) and the table is otherwise immutable.
3. Create migration `supabase/migrations/20260527120007_create_v_inquiries_inbox_view.sql`:
   - View `public.v_inquiries_inbox` with projection: `i.id`, `i.listing_id`, `l.title AS listing_title`, `l.status AS listing_status`, `i.sender_user_id`, `i.sender_name`, `i.message`, `i.status`, `i.created_at`, `i.updated_at`, AND `public.decrypt_inquirer_phone(i.id) AS inquirer_phone_decrypted` (the function from Sub-Phase D evaluates the three-tier rule per call and returns NULL if the caller is not authorized; the view does not need its own gate because the function self-gates).
   - The view inherits RLS from `public.inquiries` (no `SECURITY INVOKER` override; Postgres 15 default semantic is the policies on the base table apply).
   - `GRANT SELECT ON public.v_inquiries_inbox TO authenticated`. NOT granted to `anon` — anonymous users cannot read the inbox per FR-022.
4. Create migration `supabase/migrations/20260527120008_create_v_lead_events_views.sql`:
   - View `public.v_lead_events_publisher` projecting `id, listing_id, user_id, event_type, created_at` (note: `metadata` omitted per Q5=B + FR-014b). `GRANT SELECT ON public.v_lead_events_publisher TO authenticated`.
   - View `public.v_lead_events_admin` projecting every column including `metadata`. The view's body adds a `WHERE public.current_user_has_permission('inquiries.view_all')` predicate so even direct selects against the view fail closed for non-admins. `GRANT SELECT ON public.v_lead_events_admin TO authenticated`.
5. Update `supabase/docs/inquiries.md` and `supabase/docs/lead_events.md` with the RLS matrix from steps 1–4.

**In-spec deps**:

- C depends on Sub-Phase B — the `public.inquiries` and `public.lead_events` tables defined in `20260527120001_create_inquiries_table.sql` and `20260527120002_create_lead_events_table.sql` MUST exist before C's policy migrations can be applied.
- C depends on Sub-Phase D — `v_inquiries_inbox` calls `public.decrypt_inquirer_phone(uuid)` defined in `20260527120006_create_decrypt_inquirer_phone_fn.sql` by D. Apply-order is B → D → C-views, with C's view migration `20260527120007` sequenced strictly after D's function migration `20260527120006` by filename ascending order.

**Cross-phase deps**:

- C consumes the `public.current_user_has_permission(text)` helper from `supabase/migrations/20260515120005_create_permission_predicate.sql` (Phase 6).
- C verifies the `inquiries.view_all` permission row is present in `public.permissions` — seeded in Phase 6 / IMPLEMENTATION_PLAN §9.1. If absent, this sub-phase ALSO inserts the seed row in `20260527120003_create_inquiries_policies.sql`'s preamble (idempotent `INSERT ... ON CONFLICT DO NOTHING`).

**Touch fan**: `supabase/migrations/20260527120003_create_inquiries_policies.sql` (CREATE), `supabase/migrations/20260527120004_create_lead_events_policies.sql` (CREATE), `supabase/migrations/20260527120007_create_v_inquiries_inbox_view.sql` (CREATE), `supabase/migrations/20260527120008_create_v_lead_events_views.sql` (CREATE), `supabase/docs/inquiries.md` (UPDATE — append RLS matrix), `supabase/docs/lead_events.md` (UPDATE — append RLS matrix).

---

### Sub-Phase D — Backend write paths + decrypt function + unread-count RPC

**Scope**:

1. Create migration `supabase/migrations/20260527120006_create_decrypt_inquirer_phone_fn.sql`:
   - Function `public.decrypt_inquirer_phone(p_inquiry_id uuid) RETURNS text` as `SECURITY DEFINER SET search_path = pg_catalog, public, vault`.
   - Body: SELECT the inquiry's `inquirer_phone_encrypted` + `listing_id` + `sender_user_id`. Evaluate the three-tier rule: caller is the listing's publisher (`SELECT l.publisher_user_id = auth.uid() FROM public.listings l WHERE l.id = inquiry.listing_id`) OR caller is the original sender (`inquiry.sender_user_id = auth.uid() AND inquiry.sender_user_id IS NOT NULL`) OR caller holds `inquiries.view_all` (`public.current_user_has_permission('inquiries.view_all')`). If none of the three, RETURN NULL (silent fail). If authorized, `RETURN vault.decrypt(inquirer_phone_encrypted, inquirer_phone_key_id)::text` returning the plaintext E.164 string. Decrypt failures (corrupt ciphertext, key issues) are caught and return NULL so the inbox row renders with the FR-026 "Phone unavailable" placeholder.
   - `GRANT EXECUTE ON FUNCTION public.decrypt_inquirer_phone(uuid) TO authenticated`. NOT granted to `anon`.
2. Create migration `supabase/migrations/20260527120009_create_submit_inquiry_rpc.sql`:
   - Function `public.submit_inquiry(p_listing_id uuid, p_sender_name text, p_inquirer_phone text, p_message text) RETURNS uuid` as `SECURITY DEFINER SET search_path = pg_catalog, public, vault`.
   - Body: validate `p_sender_name` length 1..100; validate `p_inquirer_phone` E.164 format via a regex (`^\+[1-9]\d{6,14}$`); validate `p_message` length 1..2000; validate `p_listing_id` references an existing listing with `status = 'approved'` AND `publisher_user_id <> auth.uid()` (self-contact gate per FR-001d, defense-in-depth). On any validation failure `RAISE EXCEPTION` with a structured error code (e.g., `invalid_phone`, `message_too_long`, `listing_not_approved`, `self_contact_blocked`). On success: encrypt the phone via `vault.encrypt(p_inquirer_phone, ...)`; INSERT the inquiry row capturing `auth.uid()` as `sender_user_id` (or NULL for anonymous); INSERT the companion `inquiry_sent` `lead_events` row capturing IP+UA from the request context (`inet_client_addr()` + `current_setting('request.headers', true)::jsonb->>'user-agent'`); both INSERTs are in the same PL/pgSQL function body so they atomically commit or roll back. RETURN the inquiry's `id`.
   - `GRANT EXECUTE ON FUNCTION public.submit_inquiry(uuid, text, text, text) TO authenticated, anon` — anonymous submission is allowed per FR-008.
3. Create migration `supabase/migrations/20260527120010_create_record_lead_event_rpc.sql`:
   - Function `public.record_lead_event(p_listing_id uuid, p_event_type text) RETURNS uuid` as `SECURITY DEFINER SET search_path = pg_catalog, public`.
   - Body: validate `p_event_type IN ('phone_revealed','whatsapp_clicked')` — the `'inquiry_sent'` event-type goes through `submit_inquiry` only; the `'favorite_added'` event-type is reserved for Phase 17. Validate `p_listing_id` references an `approved` listing. Validate `phone` is non-empty for `'phone_revealed'` and `whatsapp` is non-empty for `'whatsapp_clicked'` per FR-018. Capture IP+UA the same way as `submit_inquiry`. INSERT the lead_events row. RETURN the row's `id`.
   - `GRANT EXECUTE ON FUNCTION public.record_lead_event(uuid, text) TO authenticated, anon`.
4. Create migration `supabase/migrations/20260527120011_create_get_inbox_unread_count_rpc.sql`:
   - Function `public.get_inbox_unread_count() RETURNS integer` as `SECURITY DEFINER SET search_path = pg_catalog, public`.
   - Body: `RETURN (SELECT COUNT(*)::integer FROM public.inquiries i JOIN public.listings l ON l.id = i.listing_id WHERE l.publisher_user_id = auth.uid() AND i.status = 'new')`. Uses `idx_inquiries_listing_status` partial index for cheap execution.
   - `GRANT EXECUTE ON FUNCTION public.get_inbox_unread_count() TO authenticated`. NOT granted to `anon`.
5. Create migration `supabase/migrations/20260527120012_phase16_advisor_hardening.sql`:
   - Apply Supabase advisor recommendations matching the Phase 9 / 10 / 11 / 14 / 15 hardening pattern: explicit `search_path` settings on each new function (already done in the function bodies above; this migration is a safety-net `ALTER FUNCTION ... SET search_path = ...` for each), explicit `REVOKE ALL ON FUNCTION ... FROM PUBLIC` then re-`GRANT EXECUTE` to the appropriate roles. Also `REVOKE ALL ON TABLE public.inquiries, public.lead_events FROM authenticated, anon` then explicit `GRANT SELECT ON public.v_inquiries_inbox, public.v_lead_events_publisher TO authenticated` and `GRANT SELECT ON public.v_lead_events_admin TO authenticated`.

**In-spec deps**:

- D depends on Sub-Phase B — `submit_inquiry` writes to `public.inquiries` (defined in `20260527120001_create_inquiries_table.sql`) and `public.lead_events` (defined in `20260527120002_create_lead_events_table.sql`); `record_lead_event` writes to `public.lead_events`; `get_inbox_unread_count` reads from `public.inquiries`; `decrypt_inquirer_phone` reads from `public.inquiries.inquirer_phone_encrypted` (column defined in B).

**Cross-phase deps**:

- D's `decrypt_inquirer_phone` consumes `public.current_user_has_permission('inquiries.view_all')` from Phase 6's `20260515120005_create_permission_predicate.sql`.
- D's `submit_inquiry` and `record_lead_event` consume the project-wide IP/UA capture pattern from Phase 11 (`inet_client_addr()` + `current_setting('request.headers', true)::jsonb`).
- D's Vault encrypt/decrypt operations consume the `vault.encrypt(text, ...)` and `vault.decrypt(bytea, ...)` API enabled in Phase 4's `20260506120006_enable_vault.sql` and used in Phase 5's `20260510120004_profiles_vault_pii_helpers.sql`.
- D consumes `auth.uid()` (Supabase Auth standard).

**Touch fan**: `supabase/migrations/20260527120006_create_decrypt_inquirer_phone_fn.sql` (CREATE), `supabase/migrations/20260527120009_create_submit_inquiry_rpc.sql` (CREATE), `supabase/migrations/20260527120010_create_record_lead_event_rpc.sql` (CREATE), `supabase/migrations/20260527120011_create_get_inbox_unread_count_rpc.sql` (CREATE), `supabase/migrations/20260527120012_phase16_advisor_hardening.sql` (CREATE).

---

### Sub-Phase E — Domain + data layer for the inquiries feature

**Scope**:

1. Define `Inquiry` domain entity at `lib/features/inquiries/domain/entities/inquiry.dart` with `Equatable` fields: `id` (String), `listingId` (String), `listingTitle` (String — denormalized from the view per FR-020), `listingStatus` (ListingStatus — re-exported from Phase 10), `senderUserId` (String?), `senderName` (String), `decryptedPhone` (String? — null when caller is not authorized OR decrypt failed per FR-026), `message` (String), `status` (InquiryStatus from Sub-Phase A), `createdAt` (DateTime), `updatedAt` (DateTime).
2. Define `LeadEvent` domain entity at `lib/features/inquiries/domain/entities/lead_event.dart`: `id`, `listingId`, `userId?`, `eventType` (LeadEventType from Sub-Phase A), `metadata` (Map<String, dynamic>? — null for the publisher tier per FR-014b), `createdAt`.
3. Define `InquirySubmission` value object at `lib/features/inquiries/domain/entities/inquiry_submission.dart`: `listingId`, `senderName`, `phone` (validated E.164), `message` (1..2000 chars validated). Includes `validate()` returning `Result.success(InquirySubmission)` or `Result.failure(Failure)` per-field.
4. Define `InquiryRepository` abstract interface at `lib/features/inquiries/domain/repositories/inquiry_repository.dart`:
   - `Future<Result<String, Failure>> submitInquiry(InquirySubmission submission)`
   - `Future<Result<List<Inquiry>, Failure>> loadInbox({InquiryStatus? statusFilter, String? listingIdFilter, String? cursor, int limit = 30})`
   - `Future<Result<Inquiry, Failure>> loadDetail(String inquiryId)`
   - `Future<Result<Unit, Failure>> updateStatus(String inquiryId, InquiryStatus newStatus)`
   - `Future<Result<int, Failure>> loadUnreadCount()`
5. Define `LeadEventRepository` abstract interface at `lib/features/inquiries/domain/repositories/lead_event_repository.dart`:
   - `Future<Result<String, Failure>> recordEvent({required String listingId, required LeadEventType eventType})`
   - `Future<Result<List<LeadEvent>, Failure>> loadByListing(String listingId, {DateTime? since})` — admin-only path; RLS denies non-admin reads via the view.
6. Define six use cases at `lib/features/inquiries/domain/usecases/`: `submit_inquiry.dart`, `record_lead_event.dart`, `load_inquiry_inbox.dart`, `load_inquiry_detail.dart`, `update_inquiry_status.dart`, `load_inbox_unread_count.dart`. Each is a single-method use case wrapping the corresponding repository call.
7. Define `InquiryDto` at `lib/features/inquiries/data/models/inquiry_dto.dart` mirroring the `v_inquiries_inbox` row shape; `fromJson` factory + `toEntity()` mapping DTO → `Inquiry`. The `inquirer_phone_decrypted` field on the DTO is nullable; `toEntity()` passes it through to `Inquiry.decryptedPhone`.
8. Define `LeadEventDto` at `lib/features/inquiries/data/models/lead_event_dto.dart` mirroring `v_lead_events_publisher` (the default tier — `metadata` field absent) OR `v_lead_events_admin` (metadata included). The DTO has an optional `metadata` field; the data source chooses which view to query based on caller's tier.
9. Implement `SupabaseInquiriesDatasource` at `lib/features/inquiries/data/datasources/supabase_inquiries_datasource.dart`:
   - `submitInquiry(submission)` → calls `supabase.rpc('submit_inquiry', params: {...})`.
   - `loadInbox(...)` → queries `public.v_inquiries_inbox` with cursor pagination on `(created_at, id)`.
   - `loadDetail(inquiryId)` → queries `public.v_inquiries_inbox WHERE id = $1`.
   - `updateStatus(inquiryId, newStatus)` → issues UPDATE against `public.inquiries SET status = $newStatus WHERE id = $inquiryId`; server-side UPDATE policy + transition trigger validate.
   - `loadUnreadCount()` → calls `supabase.rpc('get_inbox_unread_count')`.
   - `recordLeadEvent({listingId, eventType})` → calls `supabase.rpc('record_lead_event', params: {...})`.
   - `loadLeadEventsByListing(listingId, {tier})` → queries `v_lead_events_publisher` or `v_lead_events_admin` based on tier.
10. Implement `InquiryRepositoryImpl` and `LeadEventRepositoryImpl` at `lib/features/inquiries/data/repositories/`.
11. Register all 6 use cases + 2 repositories + 1 datasource with `@injectable` annotations; regenerate `lib/core/di/injection.config.dart` via `build_runner`.

**In-spec deps**:

- E depends on Sub-Phase A — `Inquiry.status` is typed as `InquiryStatus` exported from `lib/features/inquiries/domain/entities/inquiry_status.dart` (A); `LeadEvent.eventType` is typed as `LeadEventType` exported from `lib/features/inquiries/domain/entities/lead_event_type.dart` (A).
- E depends on Sub-Phase C — `SupabaseInquiriesDatasource.loadInbox()` issues `select()` against `public.v_inquiries_inbox` (column projection defined in `supabase/migrations/20260527120007_create_v_inquiries_inbox_view.sql` by C); `loadLeadEventsByListing()` issues `select()` against `v_lead_events_publisher` and `v_lead_events_admin` (defined in `supabase/migrations/20260527120008_create_v_lead_events_views.sql` by C).
- E depends on Sub-Phase D — `submitInquiry()` invokes `public.submit_inquiry(uuid, text, text, text)` defined in `20260527120009_create_submit_inquiry_rpc.sql` by D; `recordLeadEvent()` invokes `public.record_lead_event(uuid, text)` defined in `20260527120010_create_record_lead_event_rpc.sql` by D; `loadUnreadCount()` invokes `public.get_inbox_unread_count()` defined in `20260527120011_create_get_inbox_unread_count_rpc.sql` by D.

**Cross-phase deps**:

- E imports `package:alnujom/core/errors/{failure,result}.dart` (Phase 1) for the `Result<T, Failure>` return type.
- E imports `package:alnujom/shared/domain/value_objects/phone_number.dart` (Phase 5) for the `InquirySubmission` phone-validation routine.
- E imports `package:alnujom/features/listing_form/domain/entities/listing.dart` (Phase 10) for the `ListingStatus` enum re-exported in `Inquiry.listingStatus`.

**Touch fan**: `lib/features/inquiries/domain/entities/inquiry.dart` (CREATE), `lib/features/inquiries/domain/entities/lead_event.dart` (CREATE), `lib/features/inquiries/domain/entities/inquiry_submission.dart` (CREATE), `lib/features/inquiries/domain/repositories/inquiry_repository.dart` (CREATE), `lib/features/inquiries/domain/repositories/lead_event_repository.dart` (CREATE), `lib/features/inquiries/domain/usecases/submit_inquiry.dart` (CREATE), `lib/features/inquiries/domain/usecases/record_lead_event.dart` (CREATE), `lib/features/inquiries/domain/usecases/load_inquiry_inbox.dart` (CREATE), `lib/features/inquiries/domain/usecases/load_inquiry_detail.dart` (CREATE), `lib/features/inquiries/domain/usecases/update_inquiry_status.dart` (CREATE), `lib/features/inquiries/domain/usecases/load_inbox_unread_count.dart` (CREATE), `lib/features/inquiries/data/models/inquiry_dto.dart` (CREATE), `lib/features/inquiries/data/models/lead_event_dto.dart` (CREATE), `lib/features/inquiries/data/datasources/supabase_inquiries_datasource.dart` (CREATE), `lib/features/inquiries/data/repositories/inquiry_repository_impl.dart` (CREATE), `lib/features/inquiries/data/repositories/lead_event_repository_impl.dart` (CREATE), `lib/core/di/injection.config.dart` (REGENERATED).

---

### Sub-Phase F — Presentation: inbox + detail + form sheet + cubits + admin overlay

**Scope**:

1. Implement `InquiryFormBloc` at `lib/features/inquiries/presentation/bloc/inquiry_form_bloc.dart`:
   - Events: `InquiryFormFieldChanged({InquiryFormField field, String value})`, `InquiryFormSubmitted()`.
   - States: `InquiryFormEditing({name, phone, message, validationErrors})`, `InquiryFormSubmitting()`, `InquiryFormSubmitted(inquiryId)`, `InquiryFormFailed(failure)`.
   - On `InquiryFormSubmitted`: build `InquirySubmission`, validate, call `SubmitInquiry` use case, emit Submitting → Submitted/Failed.
2. Implement `InquiryFormSheet` at `lib/features/inquiries/presentation/sheets/inquiry_form_sheet.dart` — a Material `showModalBottomSheet`-presented `BlocProvider<InquiryFormBloc>` wrapping a `Column` with three `TextField`s (name, phone, message) + character counter under the message field (visible when typed length crosses ~80% of cap per FR-006 + R-108) + submit button. The form's BlocListener navigates back to the listing details page on `InquiryFormSubmitted` and surfaces a localized snackbar.
3. Implement `ContactCtaCubit` at `lib/features/inquiries/presentation/bloc/contact_cta_cubit.dart` — exposes `ContactCtaState({phone, whatsapp, showCall, showWhatsApp, whatsappEnabled, showInquiry, isSelfContact})`. Constructed in `ContactBlock` with the listing's `phone`, `whatsapp`, `publisherUserId`, and current `auth.uid()`. Computes:
   - `isSelfContact = (publisherUserId == auth.uid())`.
   - `showCall = !isSelfContact && phone is non-empty AND validates as E.164`.
   - `showWhatsApp = !isSelfContact` (always rendered for non-self-contact per Q1=B-refined).
   - `whatsappEnabled = whatsapp is non-empty AND validates as E.164` (strict source-of-truth, no fallback to `phone`).
   - `showInquiry = !isSelfContact`.
4. Implement `InquiryInboxBloc` at `lib/features/inquiries/presentation/bloc/inquiry_inbox_bloc.dart`:
   - Events: `InquiryInboxOpened()`, `InquiryInboxRefreshRequested()`, `InquiryInboxMoreLoaded()`, `InquiryInboxStatusFilterChanged(InquiryStatus?)`, `InquiryInboxListingFilterChanged(String?)`.
   - States: `InquiryInboxLoading`, `InquiryInboxLoaded({inquiries, hasMore, statusFilter, listingFilter})`, `InquiryInboxError(failure)`.
5. Implement `InquiryInboxPage` at `lib/features/inquiries/presentation/pages/inquiry_inbox_page.dart` — replaces Sub-Phase A's stub. Composition: `AppBar` with `DeepLinkAwareBackButton` (Phase 15's extracted widget); body is a `RefreshIndicator` wrapping a `ListView.builder` over `state.inquiries`; each tile shows `InboxStatusBadge`, decrypted phone (or "Phone unavailable" placeholder per FR-026), listing title, `InquiryMessageSnippet`, timestamp; tap → `context.go(AppRoutes.inquiryDetailFor(id))`; pull-to-refresh dispatches `InquiryInboxRefreshRequested`; the AppBar `actions` slot has a status-filter dropdown + per-listing filter dropdown. Empty state per FR-019 / SC-012.
6. Implement `InquiryDetailBloc` at `lib/features/inquiries/presentation/bloc/inquiry_detail_bloc.dart`:
   - Events: `InquiryDetailOpened(String id)`, `MarkResponded()`, `MarkClosed()`, `ReopenToSeen()`, `ReopenToResponded()`.
   - States: `InquiryDetailLoading`, `InquiryDetailLoaded(inquiry)`, `InquiryDetailError(failure)`.
   - On `InquiryDetailOpened`: call `LoadInquiryDetail(id)`; if the loaded inquiry's status is `new`, immediately dispatch the auto `new → seen` transition by calling `UpdateInquiryStatus(id, seen)` and re-load. The transition success triggers an `InquiriesUnreadCubit.decrement()` side-effect.
   - On any of the four mutation events: call `UpdateInquiryStatus(id, newStatus)`, optimistically emit a new `InquiryDetailLoaded` with the updated status, and on failure roll back per Q8=A last-write-wins.
7. Implement `InquiryDetailPage` at `lib/features/inquiries/presentation/pages/inquiry_detail_page.dart` — replaces Sub-Phase A's stub. Composition: `AppBar` with `DeepLinkAwareBackButton`; body shows the full `message` text, the decrypted callback phone (with a "Tap to call" affordance that launches `tel:`), the inquirer's name, the listing reference (tappable, navigates to `/listings/:id`), the current status badge, and 1–4 status-mutation buttons whose visibility depends on the current status per the FR-021a allowlist.
8. Implement `InquiriesUnreadCubit` at `lib/features/inquiries/presentation/bloc/inquiries_unread_cubit.dart`:
   - State: `InquiriesUnreadState({count, canShowEntry})` — `canShowEntry` is true when the signed-in user owns ≥1 approved listing.
   - Methods: `refresh()` (calls `LoadInboxUnreadCount` use case), `decrement()` (called after a successful `new → seen` transition).
   - Registered as `@lazySingleton` so the home AppBar action and the inquiry detail bloc share the same instance.
9. Implement `UnreadCountBadge` at `lib/features/inquiries/presentation/widgets/unread_count_badge.dart` — a small circular badge composed from `AppRadii.full` + accent token. Hidden when count is 0.
10. Implement `InboxStatusBadge` at `lib/features/inquiries/presentation/widgets/inbox_status_badge.dart` — colored `Chip` per `InquiryStatus` value reading colors from design tokens.
11. Implement `InquiryMessageSnippet` at `lib/features/inquiries/presentation/widgets/inquiry_message_snippet.dart` — truncates message to ~120 chars + ellipsis.
12. Implement `AdminTierBanner` at `lib/features/inquiries/presentation/widgets/admin_tier_banner.dart`.
13. Implement `AdminInquiryOversightPage` at `lib/features/inquiries/presentation/pages/admin_inquiry_oversight_page.dart` — replaces Sub-Phase A's stub. Composition: identical to `InquiryInboxPage` but the BLoC is configured to read cross-publisher (the RLS `inquiries_select_admin` policy unlocks this); add `AdminTierBanner` at the top of the body; add a per-publisher filter dropdown to the AppBar actions.
14. Register all new BLoCs + cubits with `@injectable`; regenerate DI config.

**In-spec deps**:

- F depends on Sub-Phase A — `InquiryInboxPage` is registered at `AppRoutes.inquiries` (constant in `lib/core/routing/app_router.dart` by A); `InquiryDetailPage` is registered at `AppRoutes.inquiryDetail` / `AppRoutes.inquiryDetailFor(id)` by A; `AdminInquiryOversightPage` is registered at `AppRoutes.adminInquiries` by A. Status-mutation button visibility consults `InquiryStatus.allowedTransitions` defined in `lib/features/inquiries/domain/entities/inquiry_status.dart` by A.
- F depends on Sub-Phase E — Every BLoC constructor injects a use case (`SubmitInquiry`, `LoadInquiryInbox`, `LoadInquiryDetail`, `UpdateInquiryStatus`, `LoadInboxUnreadCount`, `RecordLeadEvent`) defined in `lib/features/inquiries/domain/usecases/` by E. Every page renders `Inquiry` / `LeadEvent` entities defined in `lib/features/inquiries/domain/entities/` by E.
- F depends on Sub-Phase G — All page chrome, sheet labels, status badges, mutation button labels, character counter, success snackbar, and empty state text consume getters from `lib/l10n/app_localizations.dart` regenerated by G when ARB keys land.

**Cross-phase deps**:

- F imports `lib/core/widgets/deep_link_aware_back_button.dart` (extracted in Phase 15 Sub-Phase B) for the inbox + detail + admin AppBar `leading` slots.
- F imports `lib/features/auth/presentation/bloc/auth_bloc.dart` (Phase 5) for `auth.uid()` resolution in `ContactCtaCubit.isSelfContact` computation.
- F imports `lib/core/di/injection.dart` for `getIt<T>()` lookups in the cubit construction sites.

**Touch fan**: `lib/features/inquiries/presentation/bloc/inquiry_form_bloc.dart` (CREATE), `lib/features/inquiries/presentation/bloc/inquiry_form_event.dart` (CREATE), `lib/features/inquiries/presentation/bloc/inquiry_form_state.dart` (CREATE), `lib/features/inquiries/presentation/bloc/inquiry_inbox_bloc.dart` (CREATE), `lib/features/inquiries/presentation/bloc/inquiry_inbox_event.dart` (CREATE), `lib/features/inquiries/presentation/bloc/inquiry_inbox_state.dart` (CREATE), `lib/features/inquiries/presentation/bloc/inquiry_detail_bloc.dart` (CREATE), `lib/features/inquiries/presentation/bloc/inquiry_detail_event.dart` (CREATE), `lib/features/inquiries/presentation/bloc/inquiry_detail_state.dart` (CREATE), `lib/features/inquiries/presentation/bloc/inquiries_unread_cubit.dart` (CREATE), `lib/features/inquiries/presentation/bloc/contact_cta_cubit.dart` (CREATE), `lib/features/inquiries/presentation/pages/inquiry_inbox_page.dart` (UPDATE — replaces Sub-Phase A's stub), `lib/features/inquiries/presentation/pages/inquiry_detail_page.dart` (UPDATE — replaces Sub-Phase A's stub), `lib/features/inquiries/presentation/pages/admin_inquiry_oversight_page.dart` (UPDATE — replaces Sub-Phase A's stub), `lib/features/inquiries/presentation/sheets/inquiry_form_sheet.dart` (CREATE), `lib/features/inquiries/presentation/widgets/inbox_status_badge.dart` (CREATE), `lib/features/inquiries/presentation/widgets/unread_count_badge.dart` (CREATE), `lib/features/inquiries/presentation/widgets/inquiry_message_snippet.dart` (CREATE), `lib/features/inquiries/presentation/widgets/admin_tier_banner.dart` (CREATE), `lib/core/di/injection.config.dart` (REGENERATED).

---

### Sub-Phase G — Localization: add ~32 bilingual ARB keys

**Scope**:

Add the following keys to BOTH `lib/l10n/app_ar.arb` AND `lib/l10n/app_en.arb`:

- ContactBlock (Phase 13 ARB already has `cta_call`, `cta_whatsapp`, `cta_send_inquiry` — no rename): `contact_call_disabled_tooltip`, `contact_whatsapp_disabled_tooltip` (per Q1=B-refined disabled-state hint), `contact_dialer_unavailable`, `contact_whatsapp_app_unavailable`.
- Inquiry form sheet: `inquiry_form_title`, `inquiry_form_name_label`, `inquiry_form_name_placeholder`, `inquiry_form_phone_label`, `inquiry_form_message_label`, `inquiry_form_message_placeholder`, `inquiry_form_message_counter` (with `{remaining}` placeholder), `inquiry_form_submit_button`, `inquiry_form_success_snackbar`, `inquiry_form_validation_name_required`, `inquiry_form_validation_phone_invalid`, `inquiry_form_validation_message_required`, `inquiry_form_validation_message_too_long`, `inquiry_form_submission_failed`.
- Inbox page: `inquiry_inbox_app_bar_title`, `inquiry_inbox_empty_state`, `inquiry_inbox_filter_status_label`, `inquiry_inbox_filter_listing_label`, `inquiry_inbox_load_more`, `inquiry_inbox_anonymous_sender_label`.
- Inbox status badge: `inquiry_status_new`, `inquiry_status_seen`, `inquiry_status_responded`, `inquiry_status_closed`, `inquiry_status_spam`.
- Inquiry detail page: `inquiry_detail_app_bar_title`, `inquiry_detail_callback_phone_label`, `inquiry_detail_phone_unavailable_placeholder`, `inquiry_detail_tap_to_call_action`, `inquiry_detail_listing_link_label`, `inquiry_detail_mark_responded_action`, `inquiry_detail_mark_closed_action`, `inquiry_detail_reopen_to_seen_action`, `inquiry_detail_reopen_to_responded_action`.
- Admin oversight: `admin_inquiries_tier_banner`, `admin_inquiries_app_bar_title`, `admin_inquiries_publisher_filter_label`.
- Home AppBar action: `home_inquiries_action_tooltip`.

Total: ~32 keys (final count locked at sub-phase implementation time). After ARB updates, run `flutter gen-l10n` to regenerate `lib/l10n/app_localizations.dart` and the per-locale getter classes.

**In-spec deps**: none.

**Cross-phase deps**:

- G runs `flutter gen-l10n` which regenerates `lib/l10n/app_localizations.dart`, `app_localizations_ar.dart`, `app_localizations_en.dart`. The generated file is consumed by Sub-Phase F (every page + sheet + widget) and Sub-Phase H (ContactBlock rewire + home AppBar action).

**Touch fan**: `lib/l10n/app_ar.arb` (UPDATE), `lib/l10n/app_en.arb` (UPDATE), `lib/l10n/app_localizations.dart` (REGENERATED), `lib/l10n/app_localizations_ar.dart` (REGENERATED), `lib/l10n/app_localizations_en.dart` (REGENERATED).

---

### Sub-Phase H — Entry-point wiring: ContactBlock rewire + home AppBar inbox action

**Scope**:

1. **H1 — ContactBlock rewire**: Update `lib/features/listing_details/presentation/widgets/contact_block.dart` per FR-001..FR-005 + FR-001a..FR-001d:
   - Convert `ContactBlock` from a `StatelessWidget` to a `BlocProvider<ContactCtaCubit>` host. The cubit is constructed with the listing's `phone`, `whatsapp`, `publisherUserId`, and current `auth.uid()`.
   - The widget tree under the provider reads `ContactCtaState` via `BlocBuilder` to decide visibility:
     - If `state.isSelfContact`, render `SizedBox.shrink()` — FR-001d.
     - Otherwise render the three CTAs preserving the existing button styles, icons, and order:
       - Call CTA: visible when `state.showCall`; tap handler dispatches `RecordLeadEvent(listingId, LeadEventType.phoneRevealed)` use case, then calls `url_launcher.launchUrl(Uri.parse('tel:${state.phone}'))`; on launch failure, shows localized "Dialer unavailable" snackbar.
       - WhatsApp CTA: rendered always for non-self-contact; ENABLED only when `state.whatsappEnabled` per Q1=B-refined; disabled state shows `contact_whatsapp_disabled_tooltip` via long-press. Tap handler: same pattern as Call but URL is `https://wa.me/${state.whatsapp.replaceAll('+', '')}` and event-type is `LeadEventType.whatsappClicked`.
       - Send Inquiry CTA: visible when `state.showInquiry`. Tap handler: `showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => InquiryFormSheet(listingId: listing.id))`.
   - Constructor signature changes from `const ContactBlock({super.key})` to `const ContactBlock({super.key, required this.listing})`.
   - The `_showComingSoon` helper is deleted.
2. **H2 — Listing details page consumer update**: Update `lib/features/listing_details/presentation/pages/listing_details_page.dart` `_SuccessBody` — change `ContactBlock()` invocation to `ContactBlock(listing: aggregate.listing)`. No other change.
3. **H3 — Home AppBar inbox action**: Create `lib/features/home/presentation/widgets/inquiries_app_bar_action.dart`:
   - A `BlocBuilder<InquiriesUnreadCubit, InquiriesUnreadState>` rendering `SizedBox.shrink()` when `state.canShowEntry` is false (user has zero approved listings); otherwise rendering an `IconButton` with `Icons.inbox_outlined` (or `Icons.mark_email_unread_outlined` when count > 0) and a `Stack`-overlaid `UnreadCountBadge` when count > 0.
   - `tooltip` reads `l10n.home_inquiries_action_tooltip`.
   - `onPressed` calls `context.push(AppRoutes.inquiries)`.
4. **H4 — Home page insertion**: Update `lib/features/home/presentation/pages/home_page.dart` to insert `const InquiriesAppBarAction()` into the AppBar `actions:` slot between `LocaleToggleAction` and the existing sign-in/profile `IconButton`. Also wire an `AppLifecycleListener` in the home page's `State.initState` that calls `getIt<InquiriesUnreadCubit>().refresh()` on `AppLifecycleState.resumed` (and once at first build) per FR-019a.

**In-spec deps**:

- H depends on Sub-Phase A — `AppRoutes.inquiries` constant defined in `lib/core/routing/app_router.dart` by A.
- H depends on Sub-Phase E — `ContactCtaCubit` (constructed inside `ContactBlock`) consumes `RecordLeadEvent` use case at `lib/features/inquiries/domain/usecases/record_lead_event.dart` defined by E; `LeadEventType` enum at `lib/features/inquiries/domain/entities/lead_event_type.dart` defined by A (re-exported via E's use case).
- H depends on Sub-Phase F — `ContactCtaCubit` defined at `lib/features/inquiries/presentation/bloc/contact_cta_cubit.dart` by F; `InquiryFormSheet` at `lib/features/inquiries/presentation/sheets/inquiry_form_sheet.dart` by F; `InquiriesUnreadCubit` at `lib/features/inquiries/presentation/bloc/inquiries_unread_cubit.dart` by F; `UnreadCountBadge` at `lib/features/inquiries/presentation/widgets/unread_count_badge.dart` by F.
- H depends on Sub-Phase G — `l10n.contact_dialer_unavailable`, `l10n.contact_whatsapp_app_unavailable`, `l10n.contact_whatsapp_disabled_tooltip`, `l10n.home_inquiries_action_tooltip` getters generated from `app_ar.arb` / `app_en.arb` by G.

**Cross-phase deps**:

- H2 imports `package:alnujom/features/listing_details/domain/entities/listing_details_aggregate.dart` (Phase 13) — already imported in the page; no new import needed.
- H1 imports `package:url_launcher/url_launcher.dart` (added by Sub-Phase A's `pubspec.yaml` update).
- H3 + H4 import `package:alnujom/l10n/app_localizations.dart` (regenerated by G).
- H3 + H4 import `package:alnujom/core/routing/app_router.dart` for `AppRoutes.inquiries` (Sub-Phase A's addition).

**Touch fan**: `lib/features/listing_details/presentation/widgets/contact_block.dart` (UPDATE — full rewire), `lib/features/listing_details/presentation/pages/listing_details_page.dart` (UPDATE — pass `listing: aggregate.listing` to `ContactBlock`), `lib/features/home/presentation/widgets/inquiries_app_bar_action.dart` (CREATE), `lib/features/home/presentation/pages/home_page.dart` (UPDATE — insert action into `AppBar.actions` + wire `AppLifecycleListener`).

---

### Self-audit — undeclared consumer check

Total declared "Sub-Phase B depends on Sub-Phase A" lines: **13**. Every line names the specific symbol or file path consumed.

| From | To | Named consumer |
|------|-----|---------------|
| C | B | `public.inquiries` + `public.lead_events` tables defined in `20260527120001_create_inquiries_table.sql` + `20260527120002_create_lead_events_table.sql` |
| C | D | `public.decrypt_inquirer_phone(uuid)` function defined in `20260527120006_create_decrypt_inquirer_phone_fn.sql` |
| D | B | `public.inquiries.inquirer_phone_encrypted` column + `public.lead_events` table defined in `20260527120001` + `20260527120002` |
| E | A | `InquiryStatus` enum at `lib/features/inquiries/domain/entities/inquiry_status.dart`; `LeadEventType` enum at `lib/features/inquiries/domain/entities/lead_event_type.dart` |
| E | C | `public.v_inquiries_inbox` view defined in `20260527120007_create_v_inquiries_inbox_view.sql`; `v_lead_events_publisher` + `v_lead_events_admin` views defined in `20260527120008_create_v_lead_events_views.sql` |
| E | D | `public.submit_inquiry(...)` RPC in `20260527120009`; `public.record_lead_event(...)` RPC in `20260527120010`; `public.get_inbox_unread_count()` RPC in `20260527120011` |
| F | A | `AppRoutes.inquiries` + `AppRoutes.inquiryDetail` + `AppRoutes.adminInquiries` constants in `lib/core/routing/app_router.dart`; `InquiryStatus.allowedTransitions` in `lib/features/inquiries/domain/entities/inquiry_status.dart` |
| F | E | Six use case classes at `lib/features/inquiries/domain/usecases/*.dart`; `Inquiry` + `LeadEvent` entities at `lib/features/inquiries/domain/entities/*.dart` |
| F | G | Generated getters in `lib/l10n/app_localizations.dart` (all ~32 keys consumed by inbox/detail/sheet/badges) |
| H | A | `AppRoutes.inquiries` constant in `lib/core/routing/app_router.dart` |
| H | E | `RecordLeadEvent` use case at `lib/features/inquiries/domain/usecases/record_lead_event.dart`; `LeadEventType` enum at `lib/features/inquiries/domain/entities/lead_event_type.dart` |
| H | F | `ContactCtaCubit` at `lib/features/inquiries/presentation/bloc/contact_cta_cubit.dart`; `InquiryFormSheet` at `lib/features/inquiries/presentation/sheets/inquiry_form_sheet.dart`; `InquiriesUnreadCubit` at `lib/features/inquiries/presentation/bloc/inquiries_unread_cubit.dart`; `UnreadCountBadge` at `lib/features/inquiries/presentation/widgets/unread_count_badge.dart` |
| H | G | `l10n.contact_dialer_unavailable`, `l10n.contact_whatsapp_app_unavailable`, `l10n.contact_whatsapp_disabled_tooltip`, `l10n.home_inquiries_action_tooltip` getters in `lib/l10n/app_localizations.dart` |

**Zero deps lack a named consumer.** No "easier in sequence" or "uses concepts from" wording. Cross-phase deps (to predecessor Phase 1–15 artifacts) are listed separately under each sub-phase's "Cross-phase deps" subsection and similarly name the consumed file or symbol.

### Wave summary

| Wave | Sub-Phases | Parallelism | Conflict map |
|------|------------|-------------|--------------|
| 1 | A, B, G | 3 sub-phases run in parallel (no inter-deps). A touches `pubspec.yaml`, `lib/core/routing/app_router.dart`, and new domain files under `lib/features/inquiries/domain/entities/`. B touches new files under `supabase/migrations/2026052712000{1,2,5}*.sql` + `supabase/docs/{inquiries,lead_events}.md`. G touches `lib/l10n/app_{ar,en}.arb` + regenerates `lib/l10n/app_localizations*.dart`. No two Wave 1 sub-phases share any file → zero merge conflict within the wave. |
| 2 | C, D | 2 sub-phases in parallel. C depends on B (Wave 1); D depends on B (Wave 1). C also has a name-only dependency on D's `decrypt_inquirer_phone` function — the dependency is satisfied by strict filename-ascending apply order (D's `20260527120006` lands before C's view migration `20260527120007`). C touches `2026052712000{3,4,7,8}*.sql` + appends to `supabase/docs/*.md`. D touches `2026052712000{6,9,10,11,12}*.sql`. No file overlap except the `supabase/docs/*.md` files — C appends the RLS matrix; D may also append RPC documentation; the `/wave` orchestrator merges by section heading or sequences D's docs append after C's. |
| 3 | E, F | 2 sub-phases. E depends on A (Wave 1), C (Wave 2), D (Wave 2). F depends on A (Wave 1), E (Wave 3), G (Wave 1). F's dependency on E is unavoidable — F MUST run after E within this wave (or F runs on a worktree branched off E's commit). The `/wave` orchestrator sequences E first within the wave, then F. E touches new files under `lib/features/inquiries/{data,domain}/` only. F touches new files under `lib/features/inquiries/presentation/` + replaces Sub-Phase A's three stub pages. E + F both regenerate `lib/core/di/injection.config.dart` via `build_runner` from scratch — no manual merge needed (the file is generated). |
| 4 | H | Runs alone. Depends on A (Wave 1), E (Wave 3), F (Wave 3), G (Wave 1). H's file conflicts are with existing files: `lib/features/listing_details/presentation/widgets/contact_block.dart` (UPDATE — full rewrite of the three handler functions, surrounding widget tree preserved), `lib/features/listing_details/presentation/pages/listing_details_page.dart` (UPDATE — one-line constructor change `ContactBlock(listing: aggregate.listing)`), `lib/features/home/presentation/pages/home_page.dart` (UPDATE — insert into AppBar `actions` slot + wire `AppLifecycleListener`). The new file `lib/features/home/presentation/widgets/inquiries_app_bar_action.dart` is greenfield. |

Total wall-clock parallelism: ~3× in Wave 1, ~2× in Wave 2, ~1.5× in Wave 3 (E then F sequenced), 1× in Wave 4 — versus a naive sequential 8-step chain. The leaner dependency graph saves ~45% of sequential wall-clock time on a parallel-capable executor.

---

## Research Decisions (R-97..R-108)

See [research.md](research.md) for full per-decision rationale + rejected alternatives.

| ID | Decision area | Locked answer |
|----|--------------|--------------|
| R-97 | URL launcher package | `url_launcher: ^6.3.0` (Flutter-team-maintained; Android-supported without Google Play Services hard dep; pre-locked for `tel:` + `https:` schemes) |
| R-98 | Inquiry form presentation shape | Modal bottom sheet (`showModalBottomSheet`) over push-route — lower interruption cost, in-context anchored to the originating listing details page |
| R-99 | Transition allowlist enforcement | BEFORE UPDATE trigger on `inquiries.status` with a static allowed-pair lookup; rejects invalid transitions with SQLSTATE 23514 (CHECK violation); enforces FR-021a + Q2=B server-side |
| R-100 | Privileged decrypt path shape | SECURITY DEFINER function `decrypt_inquirer_phone(uuid)` returning text (NULL when unauthorized); inlined into `v_inquiries_inbox` view's projection; self-gates per call so no separate RLS layer is needed on the function itself |
| R-101 | Unread-count read path | SECURITY DEFINER RPC `get_inbox_unread_count()` returning integer; backed by `idx_inquiries_listing_status` partial index; called by `InquiriesUnreadCubit` on home AppBar build + on app resume + after every `new → seen` transition |
| R-102 | IP+UA capture source | Server-side trusted request context (`inet_client_addr()` for IP; `current_setting('request.headers', true)::jsonb->>'user-agent'` for UA); never client-supplied |
| R-103 | Home AppBar inbox action placement | `actions:` slot between `LocaleToggleAction` and the existing sign-in/profile `IconButton`; hidden when user owns zero approved listings; badge composed inline via `Stack` + custom `UnreadCountBadge` widget |
| R-104 | Inbox pagination | Cursor-based on `(created_at DESC, id DESC)` matching Phase 13's home-feed convention; `limit 30` per page; `loadMore` extends the cursor |
| R-105 | Self-contact CTA hide rule | Computed at cubit construction time by comparing `auth.uid()` to `listing.publisher_user_id`; if equal, `ContactBlock` short-circuits to `SizedBox.shrink()` |
| R-106 | Admin oversight surface design | Thin reuse of `InquiryInboxPage` — same composition but constructed with a different `loadInbox` mode (admin tier, RLS-authorized cross-publisher read); + `AdminTierBanner` overlay; + per-publisher filter dropdown; NOT a separate page tree |
| R-107 | Write path: Edge Function vs SECURITY DEFINER RPC | SECURITY DEFINER RPC (4 of them: submit_inquiry, record_lead_event, decrypt_inquirer_phone, get_inbox_unread_count). Consistent with Phase 9's `update_exchange_rate_rpc`, Phase 10's `submit_listing_rpc`, Phase 12's `approve_listing` (atomic wrapper version), Phase 14's `search_listings`, Phase 15's `search_map`. No Edge Function for Phase 16. |
| R-108 | Character counter trigger threshold | Live counter rendered when typed length crosses 80% of 2000-char cap (i.e., ≥ 1600 chars); below threshold, counter is hidden to reduce form chrome at the common case |

## Complexity Tracking

*Empty. All 12 Constitution principles pass. No violations require justification.*
