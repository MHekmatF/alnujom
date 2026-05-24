# Contract: Phase 14 Search Vector Migration

**File**: `supabase/migrations/20260525120001_listings_search_vector.sql`
**Sub-Phase**: A (Wave 1)
**Created**: 2026-05-24

---

## Purpose

Adds a `tsvector GENERATED ALWAYS AS STORED` column and a GIN index to `public.listings` to support fast Arabic and Latin keyword search.

---

## Schema Change Contract

### Column Added

```
Table : public.listings
Column: search_vector  tsvector  GENERATED ALWAYS AS STORED  NULLABLE
```

**Generation expression**:
```sql
to_tsvector('simple', coalesce(title, '') || ' ' || coalesce(address_text, ''))
```

**Text configuration**: `'simple'` — tokenizes on whitespace and punctuation, no language-specific stemming. Chosen to support Arabic exact-token matching (Phase 14 Q1=A decision: no morphological stemming).

**Covered fields**: `title` + `address_text` only. `description` is in `public.listing_details` (separate table) and cannot be included in a generated column on `listings` — it is handled via ILIKE in the RPC (R-73).

### Index Added

```
Index : idx_listings_search_vector
Table : public.listings
Type  : GIN
Column: search_vector
```

---

## Idempotency Requirements

Both statements must be idempotent:
- `ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS search_vector ...` — safe to re-apply; no-op if column exists.
- `CREATE INDEX IF NOT EXISTS idx_listings_search_vector ...` — safe to re-apply; no-op if index exists.

**Warning**: Do not re-apply via Supabase MCP `apply_migration` using the same name — per `project_supabase_mcp_apply_migration.md` memory, this re-runs the SQL AND adds a duplicate tracker row. Verify SQL idempotency by reading the file before applying.

---

## EXPLAIN Expected Output

After applying the migration, run this query via `execute_sql`:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title
FROM public.listings
WHERE search_vector @@ plainto_tsquery('simple', 'شقة')
  AND status = 'approved';
```

**Expected plan fragment** (partial — actual costs vary):
```
Bitmap Heap Scan on listings  (cost=...)
  Recheck Cond: (search_vector @@ plainto_tsquery('simple', 'شقة'))
  Filter: (status = 'approved')
  ->  Bitmap Index Scan on idx_listings_search_vector  (cost=...)
        Index Cond: (search_vector @@ plainto_tsquery('simple', 'شقة'))
```

**Red flag**: If the plan shows a `Seq Scan` instead of `Bitmap Index Scan on idx_listings_search_vector`, the GIN index was not created or the query planner chose a full scan (possible on very small tables during development — acceptable; re-check with production-sized data).

---

## Behavioral Contract

- A keyword query `to_tsquery('simple', 'شقة')` MUST match a listing whose `title` contains the literal token "شقة".
- The same query MUST NOT match a listing whose `title` contains only "شقق" (different token — Arabic exact-form, no stemming).
- The column is read-only (GENERATED ALWAYS) — no INSERT/UPDATE of `search_vector` is permitted.
- Existing rows are backfilled by Postgres automatically when the column is added (no separate backfill migration needed for `GENERATED ALWAYS AS STORED`).

---

## Downstream Consumers

- `public.v_listings_public` view (Migration 2) reads `v.search_vector`.
- `public.search_listings` RPC (Migration 3) filters using `v.search_vector @@ plainto_tsquery('simple', p_query)`.
- No Flutter code reads `search_vector` directly — it is consumed only server-side.
