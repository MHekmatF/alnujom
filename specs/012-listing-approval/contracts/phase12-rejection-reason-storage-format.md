# Contract: Rejection Reason Storage Format (Q4=A)

**Implements**: FR-003, FR-014 (write side via Edge Function)
**Verifies**: SC-027

## Storage column

`public.listing_status_history.reason TEXT` (Phase 10's existing column; not amended; no schema migration).

## Canonical write shape

JSON object literal serialized to TEXT:

```json
{
  "preset": "<one of the six Q3=A preset keys>",
  "detail": "<free_text string>"
}
```

OR, when `reason_detail` is NULL or empty:

```json
{
  "preset": "<key>",
  "detail": null
}
```

## Write path

Built in TypeScript by the `reject_listing` Edge Function:

```ts
const reasonJson = JSON.stringify({
  preset: reason_preset,
  detail: reason_detail ?? null
});
await adminClient.rpc('set_app_rejection_reason_for_session', { reason_json: reasonJson });
// ... UPDATE listings ... — the amended trigger reads app.current_rejection_reason
//     and writes its value to listing_status_history.reason.
```

## Read path (Dart / SQL)

### From PostgREST (SELECT)

```sql
SELECT
  id,
  previous_status,
  new_status,
  changed_at,
  CASE
    WHEN reason IS NOT NULL AND reason LIKE '{%}'
      THEN (reason::jsonb)->>'preset'
    ELSE NULL
  END AS reason_preset,
  CASE
    WHEN reason IS NOT NULL AND reason LIKE '{%}'
      THEN (reason::jsonb)->>'detail'
    ELSE NULL
  END AS reason_detail
FROM public.listing_status_history
WHERE listing_id = $1
ORDER BY changed_at ASC;
```

### From Dart datasource

```dart
final raw = row['reason'] as String?;
String? preset, detail;
if (raw != null && raw.startsWith('{')) {
  final parsed = jsonDecode(raw) as Map<String, dynamic>;
  preset = parsed['preset'] as String?;
  detail = parsed['detail'] as String?;
}
```

## Defense-in-depth for non-rejection rows

Phase 10's `submit_listing` and Phase 12's `approve_listing` both result in `reason IS NULL` (the session variable `app.current_rejection_reason` is unset, so `nullif(current_setting(...), '')` returns NULL). The reader's NULL-guard prevents accidental JSON cast failures.

## Pre-Phase-12 rows

There are no pre-Phase-12 `listing_status_history` rows with `new_status='rejected'` in production (Phase 10 only writes `draft → pending_review` transitions; no rejection writer existed before Phase 12). If any exist in development databases (e.g., direct-SQL admin inserts during testing), the reader's `LIKE '{%}'` guard treats them as `reason_preset=NULL` AND surfaces the raw text as `reason_detail` only if a fallback render path is added (not Phase 12 scope).

## Forward-compatibility with JSONB conversion

A future spec can convert via:

```sql
ALTER TABLE public.listing_status_history
  ALTER COLUMN reason TYPE JSONB USING reason::jsonb;
```

This conversion is atomic (no row-by-row backfill); the JSON-encoded TEXT values cast cleanly. No application-side change required — Postgres's `(reason::jsonb)->>'preset'` works on both TEXT and JSONB columns when the casts are in place.
