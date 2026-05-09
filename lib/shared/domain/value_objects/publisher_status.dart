/// Mirror of the SQL `publisher_status_enum` from
/// supabase/migrations/20260506120001_init_enums.sql.
///
/// Phase 4 — Supabase Foundation (data-model.md).
enum PublisherStatus { pending, approved, rejected, suspended, deleted }
