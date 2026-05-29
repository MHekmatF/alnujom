# reports

## Purpose

`public.reports` is the Phase 18 moderation-report store. Each row records one
signed-in user's complaint about one **approved** listing. Reports are sensitive
moderation data: a row is readable only by its reporter OR by a holder of the
`reports.manage` permission. There is NO publisher visibility, NO aggregate
save/report count, and NO anonymous reader path (FR-025..FR-028).

Authoritative interface contract:
[`specs/018-reports-moderation/contracts/phase18-reports-table.md`](../../specs/018-reports-moderation/contracts/phase18-reports-table.md).

## Shape

Defined in `supabase/migrations/20260530120001_create_reports_table.sql`. Direct
client writes are blocked at the table level (Migration 3 revokes
INSERT/UPDATE/DELETE) so every row originates from the `submit_report` SECURITY
DEFINER RPC (Migration 6), and every mutation flows through the
`resolve_report_internal` / `start_report_review` RPCs (Migration 7).

| Column | Type | Constraint | Notes |
|--------|------|-----------|-------|
| `id` | `uuid` | PK, DEFAULT `gen_random_uuid()` | Report identifier. |
| `listing_id` | `uuid` | NOT NULL, FK -> `public.listings(id)` ON DELETE RESTRICT | The reported listing. RESTRICT preserves the report against accidental listing hard-deletes; see FK behaviors below. |
| `reporter_user_id` | `uuid` | NOT NULL, FK -> `auth.users(id)` ON DELETE CASCADE | The reporting user. Un-forgeable: set by `submit_report` from `auth.uid()`. |
| `reason` | `text` | NOT NULL, CHECK in 8 reasons | One of `fake_listing`, `wrong_price`, `already_sold_or_rented`, `duplicate`, `spam`, `wrong_location`, `inappropriate_content`, `other`. |
| `note` | `text` | NULL, CHECK `char_length <= 1000` | Optional reporter free-text. |
| `status` | `text` | NOT NULL, DEFAULT `'new'`, CHECK in {`new`,`reviewing`,`resolved`,`dismissed`} | Lifecycle state. |
| `reviewing_by` | `uuid` | NULL, FK -> `auth.users(id)` ON DELETE SET NULL | Soft-claim holder set by `start_report_review`. |
| `reviewing_started_at` | `timestamptz` | NULL | When the soft claim was taken. |
| `resolved_by` | `uuid` | NULL, FK -> `auth.users(id)` ON DELETE SET NULL | The resolving moderator. |
| `resolved_at` | `timestamptz` | NULL | When resolution happened. |
| `resolution` | `text` | NULL | Records the resolving action (`dismiss`/`hide`/`mark_duplicate`/`delete`). |
| `metadata` | `jsonb` | NULL | Optional reporter IP / user-agent capture (FR-010(e), mirrors `lead_events.metadata`). |
| `created_at` | `timestamptz` | NOT NULL, DEFAULT `now()` | Server-generated; drives queue + My-Reports newest-first ordering. |

## Lifecycle

`new` -> (optional `reviewing` via `start_report_review`) -> terminal `resolved`
or `dismissed`. Resolution sets `resolved_by` / `resolved_at` / `resolution`.

## Indices

| Index | Definition | Purpose |
|-------|-----------|---------|
| `idx_reports_status_created` | `(status, created_at DESC)` | Admin queue: newest-first by status. |
| `idx_reports_reporter_created` | `(reporter_user_id, created_at DESC)` | My-Reports list + per-listing reporter banner lookup. |
| `idx_reports_listing` | `(listing_id)` | FK support + sibling auto-resolve scan. |
| `ux_reports_open_per_reporter_listing` | UNIQUE `(reporter_user_id, listing_id) WHERE status IN ('new','reviewing')` | Open-report dedup backstop (FR-004). |

### Open-report dedup index

`ux_reports_open_per_reporter_listing` is a **partial unique** index that admits
at most one OPEN (`new` or `reviewing`) report per `(reporter, listing)` pair.
Terminal rows (`resolved` / `dismissed`) fall outside the predicate, so a fresh
report for the same pair succeeds after the prior one is resolved. The
`submit_report` RPC performs a friendly `EXISTS` pre-check (raising
`already_reported`); this index is the race backstop that guarantees the
invariant even under concurrent submits.

## FK delete behaviors (R-131)

| FK column | References | ON DELETE behavior | Rationale |
|-----------|-----------|-------------------|-----------|
| `listing_id` | `public.listings(id)` | **RESTRICT** | Listings soft-delete via `status='deleted'`; RESTRICT never fires normally and defends against accidental hard-deletes so the report (and its My-Reports/banner rows) survives. |
| `reporter_user_id` | `auth.users(id)` | **CASCADE** | Deleting an account removes its reports with no orphans (mirrors `favorites` / `user_preferences` precedent). |
| `reviewing_by` | `auth.users(id)` | **SET NULL** | The report survives the soft-claiming moderator's account deletion. |
| `resolved_by` | `auth.users(id)` | **SET NULL** | The report survives the resolving moderator's account deletion (attribution goes null, row stays). |

## RLS posture (forward-stated)

- **Migration 1 (this file)**: `ALTER TABLE public.reports ENABLE ROW LEVEL
  SECURITY` is set. NO policies are attached. Default-deny means direct reads
  from any client session return zero rows until Migration 3 attaches the
  reader policy.
- **Migration 3 (`20260530120003_create_reports_policies.sql`)** will add:
  - `reports_select_self_or_admin` -- SELECT for `authenticated` where
    `reporter_user_id = auth.uid()` OR
    `public.current_user_has_permission('reports.manage')`.
  - `REVOKE INSERT, UPDATE, DELETE ON public.reports FROM authenticated, anon` --
    no client write path; creation via `submit_report` RPC only, mutation via
    the resolve/claim RPCs only.
  - No `anon` policy -- anonymous sessions are denied entirely (FR-027).
  - No publisher path and no aggregate count anywhere (FR-028).

The full live reader/writer matrix lands in Migration 3 (data-model section 1.9)
and is appended to this doc in Sub-Phase C (T016).

## Write model

- **INSERT**: exclusively via `public.submit_report(p_listing_id uuid, p_reason
  text, p_note text)` (Migration 6, SECURITY DEFINER). No direct INSERT grant --
  so `reporter_user_id` is un-forgeable and the auth + approved-listing + dedup
  gates cannot be bypassed (FR-010).
- **UPDATE**: only via `resolve_report_internal` (service-role, Migration 7) and
  `start_report_review` (authenticated + `reports.manage` self-gate, Migration
  7). No client UPDATE grant.
- **DELETE**: none from application code.
