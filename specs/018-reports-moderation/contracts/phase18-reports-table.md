# Contract — `public.reports` table

**Migration**: `supabase/migrations/20260530120001_create_reports_table.sql` (Sub-Phase B)

## Columns

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | UUID | PK, `DEFAULT gen_random_uuid()` |
| `listing_id` | UUID | NOT NULL, FK → `public.listings(id)` `ON DELETE RESTRICT` |
| `reporter_user_id` | UUID | NOT NULL, FK → `auth.users(id)` `ON DELETE CASCADE` |
| `reason` | TEXT | NOT NULL, CHECK ∈ 8 canonical reasons |
| `note` | TEXT | NULL, CHECK `char_length ≤ 1000` |
| `status` | TEXT | NOT NULL, DEFAULT `'new'`, CHECK ∈ {`new`,`reviewing`,`resolved`,`dismissed`} |
| `reviewing_by` | UUID | NULL, FK → `auth.users(id)` `ON DELETE SET NULL` |
| `reviewing_started_at` | TIMESTAMPTZ | NULL |
| `resolved_by` | UUID | NULL, FK → `auth.users(id)` `ON DELETE SET NULL` |
| `resolved_at` | TIMESTAMPTZ | NULL |
| `resolution` | TEXT | NULL (records the action) |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT `now()` |

## Indices

- `idx_reports_status_created (status, created_at DESC)` — admin queue.
- `idx_reports_reporter_created (reporter_user_id, created_at DESC)` — My-Reports + banner.
- `idx_reports_listing (listing_id)` — FK + sibling-resolve scan.
- `ux_reports_open_per_reporter_listing (reporter_user_id, listing_id) WHERE status IN ('new','reviewing')` — UNIQUE; the open-report dedup backstop (FR-004).

## Lifecycle

`new` → (optional `reviewing` via `start_report_review`) → terminal `resolved` / `dismissed`. Resolution sets `resolved_by`/`resolved_at`/`resolution`. RLS enabled (policies in `20260530120003`).

## Smoke tests

1. Insert via `submit_report` → row with `status='new'`, `reporter_user_id = auth.uid()`.
2. Second open report for same `(reporter, listing)` → unique-index violation / `already_reported` (FR-004).
3. After resolution, a fresh insert for the same pair succeeds (terminal rows outside the partial index).
4. `DELETE FROM auth.users WHERE id = <reporter>` cascades the reports; paired `moderation_actions.report_id` SET-NULLs (R-131).
