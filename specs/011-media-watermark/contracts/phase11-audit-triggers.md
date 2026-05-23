# Contract: `log_audit()` reuse on `public.listing_media` (FR-005, R-05 EIGHTH time)

**Source FRs**: FR-005, FR-021 | **Migration**: `20260522120001_create_listing_media.sql` (bundled with table create) | **Source-of-truth**: [data-model.md §3](../data-model.md#3-audit-trigger-group-on-publiclisting_media-fr-005-r-05-eighth-time)

## R-05 invariant

Phase 4's `log_audit()` function is reused **unchanged**. Phase 11 attaches new triggers to `public.listing_media` without editing the function body. This is the **EIGHTH** consecutive phase preserving the invariant (Phases 4/5/6/7/8/9/10/11).

## Trigger attachments

```sql
CREATE TRIGGER audit_listing_media_insert
  AFTER INSERT ON public.listing_media
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('listing_media.created');

CREATE TRIGGER audit_listing_media_update
  AFTER UPDATE ON public.listing_media
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('listing_media.updated');

CREATE TRIGGER audit_listing_media_delete
  AFTER DELETE ON public.listing_media
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('listing_media.deleted');
```

## New action keys (per FR-021)

| Action key | Fires when |
|---|---|
| `listing_media.created` | Any INSERT (owner upload via picker; admin direct SQL) |
| `listing_media.updated` | Any UPDATE (set-main; reorder; metadata edit) |
| `listing_media.deleted` | Any DELETE (publisher per-thumbnail delete per R-38; admin direct SQL; cascade from `listings` delete) |

`audit_logs` row shape (Phase 4 schema):

| Column | Value |
|---|---|
| `actor_user_id` | `auth.uid()` (NULL for system context) |
| `action` | One of the three new keys above |
| `target_type` | `'listing_media'` (passed by `log_audit`) |
| `target_id` | `NEW.id` for INSERT/UPDATE; `OLD.id` for DELETE |
| `before_state` | `row_to_json(OLD)::jsonb` for UPDATE/DELETE; NULL for INSERT |
| `after_state` | `row_to_json(NEW)::jsonb` for INSERT/UPDATE; NULL for DELETE |
| `created_at` | `now()` |

## Set-as-main emits TWO audit rows

Per FR-021: when the publisher taps "Set as main", the datasource issues a transactional UPDATE flipping `is_main=true` on the target row AND `is_main=false` on the row that previously held main. The audit trigger fires twice — one row per affected row — giving the admin two `listing_media.updated` audit rows for the single logical action. This matches Phase 10's status-delta audit-emission pattern.

## Verification

After a manual session:
```sql
SELECT count(*) FROM audit_logs
WHERE action LIKE 'listing_media.%'
  AND target_id IN (SELECT id FROM listing_media WHERE listing_id = '<test listing>');
```
Expected count = number of insertions + 2 × set-main operations + number of reorder UPDATEs + number of deletions.

## Reading audit logs

Per Phase 6 + Phase 10 invariants, `audit_logs.view` is the gating permission. Phase 11 introduces no new audit-reader surface (Phase 20's admin dashboard will surface listing_media audit history when it ships).
