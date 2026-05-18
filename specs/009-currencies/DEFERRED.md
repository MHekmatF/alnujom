# Phase 9 Deferred Work

Captured: 2026-05-18

## Resolved During Implementation

- Empty-state copy on latest-rate sublines: Resolved. Implemented `rateNotSetHint` and wired it through `latest_rate_subline.dart` and empty history states.
- Loading-state UX details: Resolved. Currency pages use standard Flutter progress indicators and existing Phase 2 spacing tokens.
- Supabase advisor performance follow-up: Resolved. Added migration `20260518120008_phase9_fk_index_hardening.sql` with covering indexes for `exchange_rates.set_by`, `exchange_rates.target_currency`, and `user_preferences.display_currency`. Confirmed no `unindexed_foreign_keys` advisor for these columns in the post-fix run.

## Accepted As-Is For Phase 9

- Edge Function rate limiting: Accepted as-is. Phase 9 implements `update_exchange_rate` as a permission-checked Postgres RPC per R-06, not an Edge Function. Server-side permission checks and RLS remain the security boundary.
- `source` text sanitization: Accepted as-is. Phase 9 relies on admin-only write access plus the Postgres `CHECK (source IS NULL OR length(source) <= 500)` constraint.
- `update_exchange_rate` SECURITY DEFINER advisor warning: Accepted as-is for Phase 9. The RPC must be executable by `authenticated` so the Flutter client can call it, and it re-checks `currencies.manage` internally before writing.

## Deferred

- ICU symbol fallback for future custom currencies: Deferred until the first non-USD/SYP custom currency is added by an admin. Current formatter behavior uses the stored `currencies.symbol` value plus explicit SYP locale handling.
- Phase 9 full quickstart device walk (T093): Deferred to reviewer/manual QA. Steps requiring the reference Infinix Note 8, multiple users, or two-device propagation were not executed in this session. When walked, also update `quickstart.md` Step 1 to list the now-eight Phase 9 migrations (originally documented as five).
- Supabase advisor SECURITY DEFINER follow-up: Accepted as-is for `update_exchange_rate`. The advisor still flags it because it is callable by `authenticated`, but the Phase 9 design intentionally uses a permission-checked RPC and revokes `PUBLIC`/`anon` execution in `20260518120005_phase9_advisor_hardening.sql`.
