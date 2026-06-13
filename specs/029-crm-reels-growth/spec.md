# Spec 029 — CRM, Charts, Form Polish, Reels, 360° Upload, Admin Locations

**Branch:** `029-crm-reels-growth` · **One PR** · squash-merge `--admin`
**Predecessor:** Phase 028 (`028-premium-worth-pass`, PR #77 merged to `main`).

A growth-features wave on top of the merged premium pass. Six features, built by 5 parallel
agents with disjoint file ownership; shared files (ARBs, `app_strings.dart`, `pubspec.yaml`,
DI codegen) wired centrally by the orchestrator from agent manifests. `app_router.dart` is
deliberately untouched — every new page is reached by `Navigator.push` (chat / viewings /
lead-analytics precedent).

## Features

- **F1 — CRM for publishers (full).** Lead pipeline (stages new → contacted → viewing →
  negotiation → won/lost) over existing inquiries/chats/viewings, private notes, and
  **follow-up reminders** delivered by device-local notifications (no server scheduler — pg_cron
  is not installed). New `lib/features/crm/**`, `lib/core/notifications/local_reminder_scheduler.dart`,
  tables `crm_leads` / `crm_notes` / `crm_reminders`, RPC `crm_lead_timeline`.
- **F2 — Richer dashboards.** Hand-built token charts (no chart package) on BOTH the publisher
  dashboard and a new admin analytics page, derived from existing data only (no new tracking).
  Shared `lib/core/widgets/charts/`. Also fixes the `publisher_dashboard_counts` `'pending'`
  bug (always-0 KPI → `'pending_review'`).
- **F3 — Add-listing enhancement.** Behaviour-preserving polish of the 7-step flow: review step
  shows resolved names + a live preview card, drag-reorder media grid, per-step validation
  summary, keyboard polish, media tips.
- **F4 — Reels.** Home entry → fullscreen vertical in-app video feed (official `video_player`),
  strict 3-controller memory window, mute-by-default, tap-through to listing. RPC `list_video_reels`.
- **F5 — 360° photo upload.** Dedicated "Add 360° photo" CTA in the media step (equirectangular
  aspect gate, no watermark, stored `kind='panorama'`) + camera-app help links. The existing
  panorama viewer and the "mark existing photo as 360°" toggle are retained.
- **F6 — Admin-manageable locations.** Closes the verified blocker: `areas.centroid_lat/lng` are
  NOT NULL but the create-area path omits them, so admin area creation hard-fails today. Adds a
  centroid map-pin picker + manual lat/lng to the area editor.

## Constraints (standing)
Arabic-first RTL + light/dark. Token linter (`tool/lint_design_tokens.dart`), l10n parity +
literals linters, and `flutter analyze --fatal-infos` all green. Every new ARB key gets an
`@override` in `_DebugAppLocalizations` (`lib/core/localization/app_strings.dart`). NO new
automated tests (MVP rule). Migrations applied via Supabase MCP, never `db push`. New SECURITY
DEFINER functions: `REVOKE ALL FROM PUBLIC` first; alias every table (RETURNS TABLE OUT-param
collisions); never an invoker view INNER-JOINing an RLS table.

## Out of scope / deferred
Agency-shared CRM leads (leads are personal to the publisher this phase). True 360° hardware
capture/stitching (upload only). Video thumbnail generation (reels use the listing's main image
as poster). Server-side reminder scheduling (revisit if pg_cron is ever installed).

See the full implementation plan in the PR description and the session plan file.
