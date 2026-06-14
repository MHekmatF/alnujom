# Spec 031 — Detail-style create form, stay-live edit revisions, full Syria locations, smarter assistant

**Branch:** `031-detail-form-revisions-locations-ai` · **One PR** · squash-merge `--admin`
**Predecessor:** Phase 030 (`030-storage-search-crm-nav`, PR #79 merged).

Four user-requested features, built by a 4-agent parallel wave (disjoint file ownership;
shared files wired centrally).

## Features
- **F1 — Detail-style create form.** A second "add listing" flow that mirrors the listing-
  DETAILS page layout (a single empty fill-in screen), available via an in-page toggle on
  create alongside the existing 7-step stepper (kept for comparison). Reuses the same
  `ListingFormBloc` + `submit_listing` path. Create-only.
- **F2 — Stay-live edit revisions.** Editing an APPROVED listing creates a pending
  `listing_revisions` row; the live listing stays publicly visible on its old content until an
  admin approves, at which point the proposed fields + media manifest swap in atomically. No
  public downtime; the listing id (deep links, favorites, inquiries) is preserved.
- **F3 — Full Syria locations dataset.** Populate governorates → districts/cities →
  neighborhoods from an open Syrian admin-division dataset (ar+en names + centroids), with a
  default "center" area per city so every city is publishable. Idempotent seed
  (`ON CONFLICT DO NOTHING`); no schema change; stays Syria-only.
- **F4 — Smarter assistant (no LLM).** City/neighborhood matching, area-size + "at least N
  rooms", amenities/furnished features (also wired as real search filters), and smarter
  market-stat answers + a gentle follow-up chip when a query is vague.

## Constraints (standing)
Arabic-first RTL + light/dark. Token linter, l10n parity + literals, `flutter analyze
--fatal-infos` all green. Every ARB key gets an `@override` in `_DebugAppLocalizations`. NO new
automated tests. Migrations via Supabase MCP. SECURITY DEFINER RPCs: `SET search_path`, REVOKE
PUBLIC + appropriate GRANT, alias tables; admin RPCs gate on `listings.review`.

## Out of scope / deferred
Multi-country locations (no countries table; Syria-only). Editing media-heavy revisions beyond
the manifest model. LLM-based assistant. The new detail-style form for EDIT mode (edit uses the
stepper).

See the full implementation plan in the PR description and the session plan file.
