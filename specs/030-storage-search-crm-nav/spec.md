# Spec 030 — Storage compression, smarter search, auto-CRM, Reels tab, profile drawer

**Branch:** `030-storage-search-crm-nav` · **One PR** · squash-merge `--admin`
**Predecessor:** Phase 029 (`029-crm-reels-growth`, PR #78 merged).

Five post-029 refinements requested by the user, built by a 5-agent parallel wave (disjoint
file ownership; shared files wired centrally).

## Features
- **F1 — Video compression + thumbnails.** Listing videos upload RAW today (≤30MB, no
  transcode). Add `video_compress`: transcode to **720p** before upload (progress in the
  existing upload UI, fall back to original on failure), and generate a real poster
  thumbnail stored on the video's `listing_media.thumbnail_path` (new column) so Reels uses
  a true video frame. Images are already compressed (1920px/q85) — unchanged.
- **F2 — Smarter bilingual search.** Expand the assistant's property-type keyword map with
  curated Arabic+English synonyms / transliterations / common misspellings (filla→villa,
  house/بيت/منزل→apartment, …) plus a guarded Levenshtein-1 typo fallback for Latin tokens.
- **F3 — Auto-create CRM leads.** AFTER-INSERT triggers on inquiries/conversations/viewings
  auto-create a `crm_lead` for the listing's publisher (idempotent IF-NOT-EXISTS, anon-safe),
  + one-time backfill. The manual "Add to CRM" control becomes "View in CRM".
- **F4 — Reels bottom-nav tab.** Reels **replaces** the Search tab (search stays reachable via
  the home search bar). New `/reels` route + `ReelsTabPage` (vertical feed + bottom nav).
- **F5 — Profile drawer.** A new right-side (RTL) navigation drawer holds the publisher/admin
  tools, activity, reports, and settings; the profile keeps only identity + account essentials
  + favorites + sign-out. Hamburger added to the home app bar.

## Constraints (standing)
Arabic-first RTL + light/dark. Token linter, l10n parity + literals, `flutter analyze
--fatal-infos` all green. Every ARB key gets an `@override` in `_DebugAppLocalizations`
(`lib/core/localization/app_strings.dart`). NO new automated tests. Migrations via Supabase MCP.
SECURITY DEFINER triggers: `SET search_path = public`, IF-NOT-EXISTS dedup.

## Out of scope / deferred
Re-compressing existing uploaded videos; agency/ad image post-processing (already
picker-limited); details-page gallery using the new video thumbnail (Reels poster only this
phase); a full StatefulShellRoute refactor (per-page `Scaffold.drawer` is sufficient).

See the full implementation plan in the PR description and the session plan file.
