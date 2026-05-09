# Contract: `Profile` Domain Entity

**Owner**: Phase 4 (`lib/shared/domain/entities/profile.dart`).
**Consumers**: Phase 5 (auth flow + profile view/edit pages), Phase 6 (super-admin pages displaying user roles), Phase 7 (super-admin role assignment), Phase 12 (publisher-side rejection-reason display), every later phase that surfaces a publisher's identity (Phases 10, 13, 16, 19, etc.).
**Stability**: **Field shape is stable for v1.** Field additions are allowed (Phase 5 adds Vault-decrypted convenience accessors via a `data/` adapter, not by extending this entity). Field removals are NOT allowed without a major version bump on the domain layer.

---

## Purpose

A provider-agnostic domain entity that mirrors the `profiles` table's plaintext columns. Every `presentation/` and `domain/use_case/` consumer in the v1 product reads a `Profile`, never a `Map<String, dynamic>` from Supabase and never a `package:supabase_flutter` type. Constitution IX is enforced at this boundary.

## Class shape

A plain immutable Dart class extending `Equatable`. The full class body is in research [R-10](../research.md#r-10--domain-entity-shape-and-serialization). Fields:

| Field | Type | Nullable | Notes |
|---|---|---|---|
| `userId` | `String` | NO | Same as `auth.users.id`. |
| `fullName` | `String` | YES | NULL until Phase 5. |
| `username` | `String` | YES | NULL until Phase 5. |
| `phone` | `String` | YES | E.164 normalized; NULL until Phase 5. |
| `email` | `String` | YES | Optional real email. |
| `avatarUrl` | `String` | YES | NULL when none set. |
| `accountStatus` | `AccountStatus` | NO | Dart enum mirror of `account_status_enum`. |
| `publisherStatus` | `PublisherStatus` | NO | Dart enum mirror of `publisher_status_enum`. |
| `createdAt` | `DateTime` | NO | UTC. |
| `updatedAt` | `DateTime` | NO | UTC; bumped by the `set_updated_at()` trigger. |

- **Mutable**: No — all fields `final`; mutations produce new instances via the hand-written `copyWith`.
- **Equality**: Value equality via `Equatable.props`.
- **JSON**: NOT in this entity. The `data/` layer (Phase 5) owns row → entity mapping; the entity does not know about JSON or Supabase row shapes.

## Field semantics

| Field | Source column | Domain meaning |
|---|---|---|
| `userId` | `profiles.user_id` | Stable identifier (same as `auth.users.id`). |
| `fullName` | `profiles.full_name` | Public-facing display name. NULL until Phase 5's auth flow fills it. |
| `username` | `profiles.username` | Unique handle. NULL until Phase 5. |
| `phone` | `profiles.phone` | Public-display phone in E.164 form (e.g., `+963991234567`). NULL until Phase 5. (The user's *private* contact methods are Vault-backed Phase-5 columns and are NOT on this entity.) |
| `email` | `profiles.email` | Optional real email (used for password reset). NULL when the user signed up phone-only. |
| `avatarUrl` | `profiles.avatar_url` | URL of the public avatar image; NULL when none set. |
| `accountStatus` | `profiles.account_status` | One of `pending`, `approved`, `rejected`, `suspended`, `deleted`. Drives the `pending_approval`/`rejected`/`suspended` screens in Phase 5. |
| `publisherStatus` | `profiles.publisher_status` | One of `pending`, `approved`, `rejected`, `suspended`, `deleted`. Gates listing publication in Phase 10/12. |
| `createdAt` | `profiles.created_at` | UTC timestamp. |
| `updatedAt` | `profiles.updated_at` | UTC timestamp; bumped by the `set_updated_at()` trigger on every UPDATE. |

## Forbidden imports

The file MUST NOT import:

- `package:supabase_flutter/supabase_flutter.dart` (or any sub-import). The domain layer is provider-neutral.
- Anything under `lib/data/`. The data layer depends on the domain, not vice versa.
- Anything under `lib/features/<x>/data/`.

The file MAY import:

- `package:equatable/equatable.dart` (the value-equality library; already in `pubspec.yaml`).
- `../value_objects/account_status.dart`.
- `../value_objects/publisher_status.dart`.

## Phase 5 boundary (forward note)

When Phase 5 ships the Vault-backed columns (`legal_name`, `national_id`, `private_contact_methods`), it does NOT extend `Profile`. Instead, Phase 5 introduces a separate `ProfilePrivateIdentity` domain entity (or similar) that the data-layer's admin-decrypt mapper produces; admin pages compose the two entities. Keeping `Profile` plaintext-only means every Phase-4 consumer continues to compile unchanged, and the Vault-decrypted fields' admin-only semantics are visible at the type level.

## Verification (Phase 4 quickstart)

```text
# Static check — the import graph from lib/shared/domain/entities/profile.dart
# does NOT include package:supabase_flutter
dart analyze lib/shared/domain/entities/profile.dart   # zero issues
```

```text
# Manual check — open profile.dart and confirm the only imports are:
# 1. package:equatable/equatable.dart
# 2. account_status.dart
# 3. publisher_status.dart
# No supabase_flutter import; no freezed_annotation import; no data-layer import.
```
