# Implementation Plan: Ads & Banners Admin Module (Phase 21)

**Branch**: `021-ads-banners` (spec tracked via `.specify/feature.json` → `specs/021-ads-banners`) | **Date**: 2026-06-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/021-ads-banners/spec.md`

## Summary

Phase 21 ships the **first-party banner-ads module**: an `ads.manage`-gated admin surface to author / schedule / place / soft-delete banner ads (each with an image, an OPTIONAL bilingual caption, a link target, and a per-placement priority), plus a placement-aware **`AdSlot`** rendered on home / search-results / listing-details that serves only the **eligible** ads (active + in-window + not archived) for each placement as a priority-ordered **auto-advancing carousel**, and records a **click** when a user taps one (clicks only — no impressions). It is the first consumer of the `ads.manage` permission (already seeded on `admin` + `super_admin` in Phase 6) and the first owner of the three reserved ads tables (`ads`, `ad_placements`, `ad_impressions`), the public-read `ads` storage bucket, and the click-recording write path. Phase 21 also **flips the Phase 20 "coming soon" Ads dashboard tile** to a navigable tile behind a new `requireAdsManageRedirect` route guard.

**Backend** (9 migrations, `20260601120006`–`…014`): the three tables (RLS on, all client writes REVOKEd — RPC-only, matching the Phase 18 reports / Phase 19 agencies posture); a SECURITY DEFINER serving view `v_ads_serving` (the Phase 14 `v_listings_public` / Phase 19 `v_agencies` definer-view idiom); the public `ads` storage bucket (the Phase 19 `agency-assets` idiom); admin-gated write RPCs (`create_ad` / `update_ad` / `set_ad_active` / `archive_ad`) that re-check `ads.manage` server-side; a public click-recorder RPC `record_ad_event` that mirrors Phase 16's `record_lead_event` SECURITY DEFINER RPC (NOT an Edge Function — see research R-167); and `log_audit()` triggers on ad creation + soft-delete. **Frontend** (`lib/features/ads/`): the shared domain/data layers, the admin CRUD surface, and the public `AdSlot` + serving cubit wired into the three host surfaces. **Zero new dependencies** (`url_launcher`, `go_router`, `image_picker`/`image`/`flutter_image_compress`, `cached_network_image` all already present), **zero new permission keys**, **zero §9.1 catalog or role-seed changes**, **no third-party ad network**, **clicks-only** tracking.

## Technical Context

**Language/Version**: Dart 3.9+ / Flutter 3.35.2 (existing); PostgreSQL 15 (Supabase); PL/pgSQL
**Primary Dependencies**: `supabase_flutter`, `flutter_bloc`, `get_it` + `injectable`, `go_router`, `equatable`, `intl`, `cached_network_image`, `url_launcher`, `image_picker`, `image`, `flutter_image_compress` (ALL already in `pubspec.yaml`; Phase 21 adds ZERO new deps per FR-025)
**Storage**: Supabase Postgres — 3 NEW tables (`ads`, `ad_placements`, `ad_impressions`), 1 NEW SECURITY DEFINER view (`v_ads_serving`), 5 NEW SECURITY DEFINER RPCs (4 admin writers + 1 public click-recorder), 1 NEW public storage bucket (`ads`). NO change to any existing table, enum, or the §9.1 permission catalog.
**Testing**: Manual on-device verification (Infinix Note 8 + Pixel 8 Pro AVD) per the project's no-new-tests MVP convention (memory `feedback_no_new_tests`); SQL/RPC wire-level permission checks; `flutter analyze` + the full CI linter suite (format / design-tokens / l10n-parity / l10n-literals / SDK-boundary — memory `project_wave_run_full_verify_suite`)
**Target Platform**: Android (minSdk per project); Arabic-first RTL + English LTR
**Project Type**: Mobile app (Flutter) + Supabase backend — the established two-tree layout
**Performance Goals**: Serving read is a single bounded per-placement query against `v_ads_serving` (no full-table scan, no client-side filtering — FR-013); carousel is a lightweight client-side `PageView` + UI timer (no network/Realtime — FR-010); `AdSlot` collapses to zero height when no eligible ad (no reflow — FR-012)
**Constraints**: ZERO new deps (FR-025); ZERO new permission keys / no §9.1 change / no role-seed change (FR-026); no third-party ad network (FR-026); clicks-only — no impression logging (FR-016); checks-at-both-ends for every write AND for the public read (FR-019/FR-020/FR-021); no hardcoded role branch — gating is the data-driven `ads.manage` key (FR-022); soft-delete only — click history retained (FR-006)
**Scale/Scope**: 9 migrations; 1 Flutter feature tree (`lib/features/ads/` — domain + data + admin presentation + public AdSlot); 3 host-surface insertions (home, search, details); 1 new admin route + guard; 1 dashboard-tile flip; ~45 l10n keys

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First Development | ✅ Pass | spec.md + 7 clarifications complete before this plan; data-model / contracts / quickstart accompany it |
| II. Source-Controlled Backend | ✅ Pass | 9 migration files under `supabase/migrations/` (tables, view, bucket, RPCs, audit triggers, advisor hardening); applied via Supabase MCP per `project_supabase_apply_via_mcp`; no Studio-only changes |
| III. Security-First Supabase | ✅ Pass | RLS on all 3 new tables; ALL client writes REVOKEd (RPC-only); admin writers re-check `ads.manage` server-side; public read restricted to the eligible window via the definer view; `ad_impressions` admin-read-only + RPC-only write; `ads` bucket write-gated to `ads.manage` — checks-at-both-ends (FR-019/020/021) |
| IV. Clean Architecture | ✅ Pass | `lib/features/ads/{domain,data,admin/presentation,presentation}`; `supabase_flutter` types confined to `data/`; business rules in use cases |
| V. Arabic-First Localization | ✅ Pass | ~45 new keys in both `app_ar.arb` + `app_en.arb`; ad captions are admin-authored bilingual content shown per locale; RTL-safe admin forms + carousel |
| VI. Theme System | ✅ Pass | Phase 2 tokens only; no inline hex/font/padding (FR-024); AdSlot + status chips + pickers themed |
| VII. Dynamic Roles & Permissions | ✅ Pass | Every authoring action gated by the data-driven `ads.manage` key (no hardcoded role branch — FR-022); ad creation + soft-delete write `audit_logs` rows via `log_audit()` triggers (FR-007) |
| VIII. Approval Workflow & Identity | ✅ Pass (N/A-leaning) | No publisher-identity or approval mutation; ads are admin-authored promotional content, not user listings |
| IX. Future Backend Portability | ✅ Pass | `AdsAdminRepository` / `AdsServingRepository` interfaces in `domain/`; `supabase_flutter` only in `data/` |
| X. Testable AI Workflow | ✅ Pass | Per-FR / per-SC verification map in data-model + quickstart; the `record_ad_event`-as-RPC divergence from the plan's §6.7 "Edge Function" wording is recorded (research R-167) and reconciled into the spec |
| XI. Android-First MVP | ✅ Pass | No iOS/Web/desktop code; no new plugin |
| XII. No Hidden Decisions | ✅ Pass | 7 clarifications resolved in spec; every plan-time choice recorded as a locked decision (research R-164..R-178) with rejected alternatives |

**Gate result**: PASS — no violations, no Complexity Tracking rows needed.

## Project Structure

### Documentation (this feature)

```text
specs/021-ads-banners/
├── plan.md              # This file
├── research.md          # Phase 0 — locked decisions R-164..R-178
├── data-model.md        # Phase 1 — full migration SQL + Dart entities + per-FR/SC map
├── quickstart.md        # Phase 1 — end-to-end manual verification recipe
├── contracts/           # Phase 1 — 5 interface contracts
│   ├── phase21-ads-tables.md
│   ├── phase21-ads-serving-view.md
│   ├── phase21-ads-write-rpcs.md
│   ├── phase21-ads-storage.md
│   └── phase21-ads-ui-and-entry-points.md
├── checklists/
│   └── requirements.md  # spec quality checklist (from /speckit-specify)
└── tasks.md             # Phase 2 — (/speckit-tasks)
```

### Source Code (repository root)

```text
lib/features/ads/                          # NEW — ads feature tree
├── domain/
│   ├── entities/        # Ad, AdLinkKind, AdPlacement, AdStatus, AdPlacementAssignment, ServingAd
│   ├── repositories/    # AdsAdminRepository, AdsServingRepository (abstract)
│   └── usecases/        # CreateAd, UpdateAd, SetAdActive, ArchiveAd, LoadAds,
│                        #   LoadServingAds, RecordAdClick, UploadAdImage
├── data/
│   ├── datasources/     # SupabaseAdsAdminDatasource, SupabaseAdsServingDatasource
│   ├── dtos/            # AdDto, ServingAdDto
│   └── repositories/    # AdsAdminRepositoryImpl, AdsServingRepositoryImpl
├── admin/presentation/
│   ├── bloc/            # AdsAdminCubit
│   ├── pages/           # AdsListPage, AdEditorPage
│   └── widgets/         # placement_picker, link_target_picker, schedule_picker, ad_status_chip
└── presentation/
    ├── bloc/            # AdSlotCubit (serving)
    └── widgets/         # ad_slot.dart, ad_carousel.dart, ad_banner_card.dart

lib/features/home/presentation/pages/
└── home_page.dart                         # AMENDED — AdSlot(home_top_banner) + AdSlot(home_middle_banner)

lib/features/search/presentation/pages/
└── search_page.dart                       # AMENDED — AdSlot(search_results_banner)

lib/features/listing_details/presentation/pages/
└── listing_details_page.dart              # AMENDED — AdSlot(listing_details_banner)

lib/features/admin/dashboard/presentation/widgets/
└── dashboard_sections.dart                # AMENDED — Ads tile comingSoon → enabled + route

lib/core/routing/
├── app_router.dart                        # AMENDED — adminAds route/name + GoRoute under /admin
└── auth_redirect.dart                     # AMENDED — requireAdsManageRedirect guard

lib/l10n/{app_ar.arb, app_en.arb}          # AMENDED — ~45 ads keys

supabase/migrations/
├── 20260601120006_create_ads.sql                       # PB
├── 20260601120007_create_ad_placements.sql             # PB
├── 20260601120008_create_ad_impressions.sql            # PB
├── 20260601120009_create_v_ads_serving.sql             # PB
├── 20260601120010_create_ads_storage.sql               # PB
├── 20260601120011_create_ad_write_rpcs.sql             # PB
├── 20260601120012_create_record_ad_event_rpc.sql       # PB
├── 20260601120013_create_ad_audit_triggers.sql         # PB
└── 20260601120014_phase21_advisor_hardening.sql        # PB
```

**Structure Decision**: Established two-tree layout (Flutter `lib/features/` + Supabase `supabase/`). The new `lib/features/ads/` tree mirrors the Phase 19 `agency/` + Phase 18 `admin/reports/` Clean-Arch shape, with the admin CRUD under `ads/admin/presentation/` and the public slot under `ads/presentation/widgets/` (the plan's `lib/features/ads/widgets/AdSlot.dart` shorthand). Migration timestamps continue the series after Phase 20's last (`20260601120005`).

## Implementation Phases

> Phase 21 is one PR, decomposed into four implementation phases so `/wave` can fan out two wide waves. The split is along the build-edge boundary: **PB** (all SQL) and **PD** (Flutter domain+data) implement the shared contract from `data-model.md`/`contracts/` and share NO Dart symbol, so they run in parallel; **PA** (admin UI) and **PS** (serving UI) each import PD's Dart symbols but not each other's, so they run in parallel after PD.

### PB — Backend: tables, serving view, storage, RPCs, audit (9 migrations)
All SQL under `supabase/migrations/`. (1) `ads` table — `id`, `title`, `image_path`, `caption_ar`/`caption_en` (both-or-neither CHECK), `link_kind` CHECK∈(external,listing,search,category,agency) + `link_value`, `start_at`/`end_at` (window CHECK), `is_active`, `archived_at` (soft-delete marker), `created_by`, timestamps + `set_updated_at` trigger; RLS on; `ads_select_admin` SELECT policy `USING (current_user_has_permission('ads.manage'))`; `REVOKE INSERT,UPDATE,DELETE … FROM authenticated, anon`. (2) `ad_placements` — PK `(ad_id, placement_key)`, `placement_key` CHECK (5 keys), `priority` INT; FK `ad_id … ON DELETE CASCADE`; admin SELECT; REVOKE writes. (3) `ad_impressions` — clicks only: `kind` CHECK∈('click') DEFAULT 'click', `ad_id`/`placement_key`/`user_id` (nullable)/`occurred_at`/`metadata`; admin SELECT; REVOKE writes. (4) `v_ads_serving` SECURITY DEFINER view joining eligible `ads`+`ad_placements` (active + `archived_at IS NULL` + in-window), exposing only serving fields; GRANT SELECT to anon+authenticated. (5) `ads` storage bucket (public, image mime, size cap) + `storage.objects` policies (public read; `ads.manage`+path-shape write). (6) admin write RPCs `create_ad`/`update_ad`/`set_ad_active`/`archive_ad` (SECURITY DEFINER, re-check `ads.manage` → raise `permission_denied`/42501, bind `created_by := auth.uid()`, replace placements atomically). (7) `record_ad_event(p_ad_id, p_placement_key)` (SECURITY DEFINER, GRANT to anon+authenticated, validates the ad is eligible+assigned, inserts a `click`; mirrors `record_lead_event`). (8) `log_audit()` triggers: AFTER INSERT → `ad.created`; AFTER UPDATE OF `archived_at` WHEN newly-non-null → `ad.deleted`; (additive) AFTER UPDATE OF `is_active` → `ad.activation_changed`. (9) advisor hardening (search_path on the view/RPCs). Apply in timestamp order via Supabase MCP; run `get_advisors` after.
**Touch fan**: `supabase/migrations/20260601120006..014_*.sql` (9 new files only — no shared-file contention; distinct timestamps after `…005`).

### PD — Flutter domain + data (entities, DTOs, repositories, datasources, use cases, DI)
Build `lib/features/ads/domain/` (entities `Ad`, `AdLinkKind`, `AdPlacement`, `AdStatus` [derived], `AdPlacementAssignment`, `ServingAd`; abstract `AdsAdminRepository` + `AdsServingRepository`; use cases `CreateAd`/`UpdateAd`/`SetAdActive`/`ArchiveAd`/`LoadAds`/`UploadAdImage`/`LoadServingAds`/`RecordAdClick`) and `lib/features/ads/data/` (`AdDto`/`ServingAdDto`; `SupabaseAdsAdminDatasource` calling the `create_ad`/`update_ad`/`set_ad_active`/`archive_ad` RPCs + admin `ads` select + `ads` bucket `uploadBinary`/`getPublicUrl`; `SupabaseAdsServingDatasource` selecting `v_ads_serving` per placement + calling `record_ad_event`; `@LazySingleton(as:)` repo impls). All Supabase access string-keyed per `contracts/` — compiles and analyzes WITHOUT the DB applied. Regenerate DI (`dart run build_runner build --delete-conflicting-outputs`).
**Touch fan**: `lib/features/ads/domain/**`, `lib/features/ads/data/**` (new), `lib/core/di/injection.config.dart` (codegen).

### PA — Admin CRUD surface + route + guard + dashboard-tile flip + l10n
Build `lib/features/ads/admin/presentation/` (`AdsAdminCubit`; `AdsListPage` — list with derived status chips [active/scheduled/expired/inactive/archived] + an archived filter; `AdEditorPage` — title, image pick/upload, optional ar+en caption, `link_target_picker` [external URL | listing | search | category | agency], `schedule_picker` [start/end, start<end validation], placement multi-select with priority, active toggle; soft-delete action). Register the route end-to-end: `AppRoutes.adminAds='/admin/ads'` + `AppRouteNames.adminAds` + a `GoRoute(path:'ads', redirect: requireAdsManageRedirect, …)` under `/admin` in `app_router.dart`; add `requireAdsManageRedirect` to `auth_redirect.dart` (mirrors `requireAuditLogsViewRedirect` — single `checker.has(PermissionKeys.adsManage)` → `/admin?denied=ads`). Flip the Ads tile in `dashboard_sections.dart` from `DashboardSectionState.comingSoon` (no route) to `enabled` + `route: AppRoutes.adminAds`. Add ads admin l10n keys + DI.
**Touch fan**: `lib/features/ads/admin/**` (new), `lib/core/routing/app_router.dart`, `lib/core/routing/auth_redirect.dart`, `lib/features/admin/dashboard/presentation/widgets/dashboard_sections.dart`, `lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb`, `lib/core/di/injection.config.dart` (codegen).

### PS — Public AdSlot + serving cubit + host-surface insertions + l10n
Build `lib/features/ads/presentation/` (`AdSlotCubit` loading `LoadServingAds(placement)`; `ad_slot.dart` — collapses to `SizedBox.shrink()` when no eligible ad [FR-012], renders one banner statically or `ad_carousel.dart` [`PageView` + auto-advance `Timer` + manual swipe, looping] for ≥2; `ad_banner_card.dart` — `CachedNetworkImage` + optional locale-matched caption; on tap → `RecordAdClick` then open target [`launchUrl(...externalApplication)` for external; `context.push`/`go` to listing `/listings/:id` / search / `/agency/:id` / category for in-app], best-effort non-blocking [FR-017], graceful fallback [FR-018]). Insert `AdSlot(placement: …)` into the three host surfaces: `home_page.dart` (top — `SliverToBoxAdapter` after `MapEntryTile`; mid — single slot after the first feed page), `search_page.dart` (after the Arabic hint / before results), `listing_details_page.dart` (after `ReporterStatusBanner`). Add AdSlot l10n keys + DI.
**Touch fan**: `lib/features/ads/presentation/**` (new), `lib/features/home/presentation/pages/home_page.dart`, `lib/features/search/presentation/pages/search_page.dart`, `lib/features/listing_details/presentation/pages/listing_details_page.dart`, `lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb`, `lib/core/di/injection.config.dart` (codegen).

## Phase Dependencies

> Rule honored: every declared "B depends on A" names the exact file path AND the exported symbol B consumes from A. A Dart datasource calling a Postgres RPC/view by string name, or SQL migrations sharing a database, are **runtime/DB contracts** — they compile and `flutter analyze` independently — so they are listed separately as "Runtime/DB contracts," NOT as build-order edges. Cross-phase edits to the same shared file (ARBs, `injection.config.dart`) are **merge-contention** items handled by Touch-fan merge order, NOT build edges (no symbol crosses).

**Declared code dependencies (build/merge order edges):**

- **PA depends on PD** — `lib/features/ads/admin/presentation/bloc/ads_admin_cubit.dart` and `ad_editor_page.dart` (PA) import the abstract `AdsAdminRepository` + the entities `Ad`/`AdPlacement`/`AdPlacementAssignment`/`AdLinkKind`/`AdStatus` + the use cases `CreateAd`/`UpdateAd`/`SetAdActive`/`ArchiveAd`/`LoadAds`/`UploadAdImage`, all defined under `lib/features/ads/domain/` by PD. Without PD's symbols, PA does not compile.
- **PS depends on PD** — `lib/features/ads/presentation/bloc/ad_slot_cubit.dart` and `ad_banner_card.dart` (PS) import the abstract `AdsServingRepository` + the `ServingAd`/`AdPlacement`/`AdLinkKind` entities + the use cases `LoadServingAds`/`RecordAdClick`, all defined under `lib/features/ads/domain/` by PD. Without PD's symbols, PS does not compile.

**Runtime/DB contracts (NOT build-order edges — no named Dart symbol crosses the boundary):**

- PD's `SupabaseAdsAdminDatasource` calls the Postgres RPCs `create_ad`/`update_ad`/`set_ad_active`/`archive_ad` (created by PB) via `supabase.rpc('…')`, selects the `ads` table, and uploads to the `ads` bucket — all string-keyed runtime calls, not Dart imports. PD compiles and `flutter analyze`s without PB applied. End-to-end admin verification (quickstart) requires PB applied.
- PD's `SupabaseAdsServingDatasource` selects `v_ads_serving` and calls `record_ad_event` (created by PB) by string name — runtime contract, not a Dart import. Live serving/click behavior requires PB applied.
- Within PB, migration `…011`/`…012`'s RPCs `INSERT INTO public.ads`/`public.ad_placements`/`public.ad_impressions` and `…009`'s view selects them — tables created by `…006`/`…007`/`…008`. This is a **DB apply-order** dependency satisfied automatically by the migration timestamp order (`…006` < `…007` < … < `…014`); it is internal to PB (one sub-agent, one ordered file set), not a cross-phase edge.

**Self-audit**: Declared code deps = **2** (PA→PD, PS→PD). Deps lacking a named consumer = **0** — each names the consuming file(s) AND the imported symbol(s). PB has **0** inbound/outbound Dart edges (its only relationships are runtime contracts + internal DB apply-order). PD has **0** Dart edge to PB. PA and PS have **0** edge to each other (PS's in-app deep-link targets consume PRE-EXISTING route constants `AppRoutes.listingDetailsFor`/`AppRoutes.search`/`/agency/:id` from prior phases, NOT PA's new `AppRoutes.adminAds`). Graph is minimal — no over-conservative edges.

**Resulting execution waves:**

- **Wave 1 (parallel):** PB, PD — no Dart edge between them; both implement the shared `contracts/` interface.
- **Wave 2 (parallel):** PA, PS — each depends on PD only, not on each other.

**Merge-order guidance for `/wave`** (from Touch-fan overlap, not code edges): three phases regenerate `lib/core/di/injection.config.dart` (PD, PA, PS) and two append to both `lib/l10n/app_ar.arb` + `lib/l10n/app_en.arb` (PA, PS). Merge order: **PD → PA → PS** (PD first as both successors import it; PA/PS order between themselves is free). Each successor sub-agent MUST rebase on the merged predecessor and re-run `dart run build_runner build --delete-conflicting-outputs` to regenerate `injection.config.dart`, and union the ARB key sets (additive — ads keys are namespaced `ads*`/`adSlot*`/`adAdmin*`, so no key collision is expected, but the l10n-parity linter MUST pass post-merge per `project_wave_run_full_verify_suite`). **PB merges independently** in any order — it touches only its 9 new migration files (no shared-file contention) — but MUST be APPLIED (via Supabase MCP, `project_supabase_apply_via_mcp`) before the quickstart's live verification of PD/PA/PS. The PS host-surface edits (`home_page.dart`, `search_page.dart`, `listing_details_page.dart`) and the PA dashboard/route edits touch DISJOINT files, so PA and PS do not contend outside the ARB + `injection.config.dart` pair.

## Complexity Tracking

No constitution violations. No complexity exceptions required.

*Plan version: 1.0 | Generated by /speckit-plan | Aligned with constitution v1.0.0*
