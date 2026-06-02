# Contract: `enqueue_notification` + client RPCs (Phase 22)

**Migration**: `20260602120003_create_notification_rpcs.sql`

## `enqueue_notification(p_recipient uuid, p_type text, p_params jsonb default '{}') returns uuid`
- **SECURITY DEFINER**, `search_path=''`. **EXECUTE REVOKEd from anon, authenticated** — internal only; called solely by the SECURITY DEFINER transition functions (R-183).
- Inserts **exactly one** `notifications` row and returns its id. **Always writes history** regardless of `notifications_enabled` (FR-021 / R-189).
- Defensive: returns null + writes nothing if `p_recipient` is null.
- Recipient + params are supplied by the *calling transition* (server-side resolution — FR-002); never client-supplied.

## Client RPCs (all SECURITY DEFINER, `search_path=''`, GRANT EXECUTE to `authenticated`, self-scoped on `auth.uid()`)

| RPC | Signature | Behavior | Errors |
|---|---|---|---|
| register token | `register_notification_token(p_token text, p_platform text='android') returns void` | upsert on `(auth.uid(), token)` → active + `last_seen_at=now()` | `42501 not_authenticated` |
| deregister token | `deregister_notification_token(p_token text) returns void` | delete this device's token only | — |
| mark read | `mark_notification_read(p_id uuid) returns void` | set `read_at` on own row | — (no-op if not owner) |
| mark all read | `mark_all_notifications_read() returns void` | set `read_at=now()` on own unread | — |
| unread count | `unread_notification_count() returns int` | self unread count (badge) | — |

## Exactly-once contract (FR-003 / SC-009)
Each transition function `PERFORM`s `enqueue_notification` once, on the single status-transition branch (after the status UPDATE). A retried/duplicate call to a transition that no longer transitions (already-approved re-save) does NOT reach the PERFORM, so no duplicate notification is produced. Verify: trigger an approval, then re-invoke the approve path → `select count(*) from notifications where recipient_user_id=… and type='listing_approved'` stays 1.

## Privacy (FR-004)
`params` carry UUIDs only — no rejection reason / moderator free-text. The full reason is shown in-app behind the deep link (the source table already holds it), never in a notification row or push payload.
