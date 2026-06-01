-- Phase 20 (spec/020-admin-dashboard) — review-pass fix.
-- The read-only audit-log viewer (20260601120004 + lib/features/admin/audit_logs/)
-- paginates public.audit_logs newest-first: ORDER BY created_at DESC + a
-- `created_at < cursor` keyset filter (audit_logs_datasource.dart).
--
-- The 20260601120004 comment and contracts/phase20-audit-logs-read.md both
-- asserted this query "reuses existing idx_audit_logs_created_at" — but no
-- migration ever created that index (20260506120004_create_audit_logs.sql adds
-- only the PK on id). Without it every page does a seq-scan + sort on an
-- append-only, monotonically-growing table. This migration creates the index
-- the viewer was always meant to use, matching the order + keyset predicate.
--
-- Idempotent (IF NOT EXISTS). No table/column/policy change.

CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at
  ON public.audit_logs (created_at DESC);
