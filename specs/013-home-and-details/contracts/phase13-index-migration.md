# Contract: Index Migration

**Migration**: `supabase/migrations/20260524120001_create_listings_indexes.sql`
**Implements**: FR-001, FR-002, FR-003, FR-004, FR-005, FR-006, FR-007
**Verifies**: SC-009, SC-017, SC-018, SC-019, SC-020, SC-021

## Body

```sql
CREATE INDEX IF NOT EXISTS idx_listings_status_published_at
  ON public.listings (status, published_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_listings_status_created_at
  ON public.listings (status, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_listings_governorate_status
  ON public.listings (governorate_id, status);

CREATE INDEX IF NOT EXISTS idx_listings_property_type_status
  ON public.listings (property_type, status);
```

## Idempotency

All four statements use `IF NOT EXISTS`. Re-applying the migration via Supabase MCP `apply_migration` is safe (the SQL is no-op when the indexes already exist); the project memory `project_supabase_mcp_apply_migration.md` warns that re-applying adds a duplicate tracker row but does NOT re-create the indexes.

## Constraints

- Zero schema edits on `public.listings` or any other listings-domain table.
- Zero RLS policy edits.
- Zero new permission keys.
- Zero new SQL functions or triggers.
- Zero new `log_audit()` call sites.

## Verification

### EXPLAIN check (FR-002 + SC-009)

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM public.listings
WHERE status='approved'
ORDER BY published_at DESC, id DESC
LIMIT 20;
```

**Expected output** at any row count ≥ 100: the plan node contains `Index Scan using idx_listings_status_published_at` (NOT `Seq Scan`). At < 100 rows, Postgres may choose `Seq Scan` for cost reasons; soft requirement below the threshold.

### Grep checks (FR-003, FR-004, FR-006, FR-007)

```bash
grep -E "CREATE POLICY|ALTER POLICY|DROP POLICY" supabase/migrations/20260524120001_create_listings_indexes.sql
# Expected: 0 matches.

grep -E "ALTER TABLE|CREATE TABLE|DROP TABLE" supabase/migrations/20260524120001_create_listings_indexes.sql
# Expected: 0 matches.

grep -E "INSERT INTO public.permissions" supabase/migrations/20260524120001_create_listings_indexes.sql
# Expected: 0 matches.

grep -E "log_audit" supabase/migrations/20260524120001_create_listings_indexes.sql
# Expected: 0 matches.
```

### Edge Function count (FR-005 + SC-020)

```bash
ls supabase/functions/
# Expected: exactly 4 dirs — lookup_email_by_phone, request_password_reset (Phase 5),
#           approve_listing, reject_listing (Phase 12). NO new Phase 13 dir.
```
