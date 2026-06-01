# Contract: `notifications` table + read/read-state surface (Phase 22)

**Migration**: `20260602120002_create_notifications.sql` (table) + `20260602120003_create_notification_rpcs.sql` (read-state RPCs)

## Table `public.notifications`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` |
| `recipient_user_id` | uuid | FK `auth.users(id)` ON DELETE CASCADE |
| `type` | text | CHECK ∈ (`account_approved`,`account_rejected`,`listing_approved`,`listing_rejected`,`inquiry_received`,`agency_invitation`) |
| `params` | jsonb | deep-link IDs + render params — **UUIDs only, no PII/free-text** (FR-004) |
| `read_at` | timestamptz | null = unread |
| `created_at` | timestamptz | default now() |
| index | `(recipient_user_id, created_at desc)` | center list |
| index | partial `(recipient_user_id) where read_at is null` | unread count |

### `params` shape per `type`
| type | params |
|---|---|
| `account_approved` / `account_rejected` | `{}` |
| `listing_approved` / `listing_rejected` | `{ "listing_id": "<uuid>" }` |
| `inquiry_received` | `{ "listing_id": "<uuid>", "inquiry_id": "<uuid>" }` |
| `agency_invitation` | `{ "agency_id": "<uuid>" }` |

## RLS matrix

| Actor | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| recipient (`recipient_user_id = auth.uid()`) | ✅ own | ❌ | ❌ (read-state via RPC) | ❌ |
| other authenticated / anon | ❌ | ❌ | ❌ | ❌ |
| (writer) `enqueue_notification` | n/a | ✅ definer | — | — |

No admin cross-read (R-188). Audit-logged: No (R-196).

## Reads / read-state

- **List (center)** — client `select * from notifications order by created_at desc limit :limit offset :offset` (self-RLS scopes it). Bounded/paginated — FR-006/FR-013.
- **Unread count (badge)** — `unread_notification_count() returns int` (SECURITY DEFINER, self-scoped) — R-193.
- **Mark read** — `mark_notification_read(p_id uuid)` (own row only).
- **Mark all read** — `mark_all_notifications_read()`.

## Guarantees
- A client cannot read another user's notifications (self-RLS) — FR-009/SC-007.
- A client cannot insert/forge a notification (REVOKE; only `enqueue_notification` writes) — FR-020.
- History persists across logout/login + reinstall (server-side) — SC-008.
