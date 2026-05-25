# Contract — `record_lead_event` SECURITY DEFINER RPC

**Owner**: Sub-Phase D (`supabase/migrations/20260527120010_create_record_lead_event_rpc.sql`).

**Consumers**: Sub-Phase H `ContactBlock` Call + WhatsApp handlers (writes `phone_revealed` and `whatsapp_clicked` rows respectively); the only client write-path for tap events. Phase 17 will introduce a separate path (or extend this) for `favorite_added`.

## Signature

```sql
public.record_lead_event(
  p_listing_id  UUID,
  p_event_type  TEXT
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
```

GRANT EXECUTE TO `authenticated, anon`.

## Behavior

1. Validate `p_event_type IN ('phone_revealed', 'whatsapp_clicked')`. Phase 16 does NOT accept `'inquiry_sent'` (use `submit_inquiry`) or `'favorite_added'` (Phase 17 reserved).
2. Validate `p_listing_id` references an `approved` listing.
3. Per-event-type sanity check:
   - `phone_revealed` requires `listings.phone IS NOT NULL AND trim(phone) <> ''`.
   - `whatsapp_clicked` requires `listings.whatsapp IS NOT NULL AND trim(whatsapp) <> ''`.
4. Capture IP + UA from server-side trusted context (`inet_client_addr()` + `current_setting('request.headers', true)::jsonb->>'user-agent'`).
5. INSERT the lead_events row with `event_type`, `listing_id`, `user_id = auth.uid()` (or NULL), `metadata = {ip, user_agent}`.
6. RETURN the inserted row's `id`.

## Error codes

| Error | SQLSTATE | Notes |
|-------|----------|-------|
| `invalid_event_type` | 23514 | Caller passed inquiry_sent or favorite_added or unknown |
| `listing_not_found` | 23503 | `p_listing_id` doesn't exist |
| `listing_not_approved` | 23514 | Listing exists but isn't approved |
| `phone_not_set` | 23514 | `phone_revealed` event but listing.phone is empty |
| `whatsapp_not_set` | 23514 | `whatsapp_clicked` event but listing.whatsapp is empty |

## Pre-conditions

- `public.lead_events` table exists.
- `public.listings` exists.

## Post-conditions

- On success: exactly one row inserted into `lead_events`; function returns its id.
- On failure: no row inserted; the caller's Flutter code shows a localized error and does NOT proceed to launch the dialer / WhatsApp.

## Stability surface

**Frozen**: 2-parameter signature.

**Allowed**: relaxing the event-type whitelist when Phase 17 adds favorites (e.g., either Phase 17 adds `favorite_added` to this RPC's allowlist via ALTER FUNCTION, or it ships its own `record_favorite_added` RPC — both are acceptable).
