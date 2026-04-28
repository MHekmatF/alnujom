# Data Model: Project Foundation

**Branch**: `001-project-foundation` | **Date**: 2026-04-28
**Plan**: [plan.md](plan.md) | **Spec**: [spec.md](spec.md)

## Scope statement

Phase 1 introduces **no application Postgres tables**. The only backend artifact is `supabase/migrations/00000000000000_init_extensions.sql`, which enables the `pgcrypto` and `uuid-ossp` extensions for later phases. RLS posture is therefore N/A at the table level for this phase; Constitution Principle III's RLS gate begins applying from Phase 4 (`004-supabase-foundation`).

The only Phase 1 data lives **on-device**: a tiny `User Preferences (local)` record holding the user's theme and locale choices. It is keyed only by the device, has no relationship to a user account, and is not synchronized to the backend.

---

## Entity 1 — User Preferences (local, device-only)

### Purpose

Persist the user's theme-mode and locale choices across cold restarts (FR-006), so the shell launches in the previously selected appearance and language (and so Phase 23's real Settings screen has something to read from when it lands).

### Storage backend

**Layer**: device-local secure storage via `flutter_secure_storage` (Android Keystore-backed).
**Backing key namespace**: `com.alnujom.preferences.*` — each preference is a separate string key inside the secure storage instance. No serialization library is involved; values are short ASCII strings.

### Fields

The "Persisted values" column lists what may appear in secure storage on disk. The "In-memory cubit state" column lists what the cubit may emit at runtime — `system` is a runtime-only value derived from the absence of a persisted preference, and is never written to disk.

| Field | Type | Storage key | Persisted values (on disk) | In-memory cubit state | First-launch default | When written |
|---|---|---|---|---|---|---|
| `themeMode` | enum-like string | `com.alnujom.preferences.theme_mode` | `light`, `dark`, or **absent** | `system` (when on-disk is absent), `light`, or `dark` | absent on disk → cubit emits `ThemeMode.system` | First explicit user toggle (FR-016) |
| `localeCode` | enum-like string | `com.alnujom.preferences.locale_code` | `ar`, `en`, or **absent** | `Locale('ar')` or `Locale('en')` | absent on disk → cubit emits `Locale('ar')` (FR-005) | First explicit user toggle |

`absent` is a real, observable state: it means "the user has never made an explicit choice". The cubit distinguishes "read returned null" from "read returned a value", because FR-016 changes behavior based on this distinction (system-following vs. locked).

### Validation rules

- Reads MUST tolerate any unrecognized stored value by treating it as `absent` and logging a `CacheFailure` warning. This protects against forward-compat issues if a future phase widens the enum and the user downgrades.
- Writes MUST NOT block the UI: the cubit emits the new state synchronously and fires the storage write asynchronously. A write failure logs a warning but does NOT revert the in-memory state (the user's session keeps the choice; the next cold start may revert if persistence stayed broken).
- Reading or writing values larger than 32 bytes MUST log a warning — these values should never grow that large.

### State transitions

#### `themeMode`

```text
[on disk: absent] ──┬─ cubit emits ThemeMode.system  (initial state on first-ever launch; nothing written)
                    ├─ user toggles → cubit emits 'light' AND writes 'light' to disk (FR-016)
                    └─ user toggles → cubit emits 'dark'  AND writes 'dark'  to disk (FR-016)

[on disk: 'light']  ── cubit emits ThemeMode.light  (subsequent launches)
[on disk: 'dark']   ── cubit emits ThemeMode.dark   (subsequent launches)

After first toggle: 'light' ↔ 'dark' on each toggle, both in memory and on disk.
'system' is NEVER written to disk; it is exclusively a runtime cubit state derived
from "no persisted preference exists yet".
```

Once the user makes an explicit choice, `themeMode` on disk is one of `light`/`dark` for the rest of the install's lifetime, and the cubit emits the matching value regardless of OS theme changes (FR-016).

#### `localeCode`

```text
absent → 'ar'  (initial state on first-ever launch; not persisted; FR-005)
absent → 'en'  (user toggles to English; persisted)
'ar' ↔ 'en'    (subsequent toggles; each persisted)
```

Unlike theme, locale has no `system` mode — Constitution V's Arabic-first principle means the in-app default is always Arabic (FR-005), independent of the device locale. The first toggle persists; subsequent toggles overwrite.

### Lifecycle

- **Created**: never explicitly created; values are written on first explicit user toggle.
- **Read**: at app start, in `main.dart` via `PreferencesStore`; passed to the `ThemeCubit` and `LocaleCubit` constructors as initial state.
- **Updated**: by `ThemeCubit` and `LocaleCubit` in response to user toggle events.
- **Deleted**: only when the user uninstalls the app or wipes app data via Android system settings. Phase 1 does not expose a "reset preferences" affordance; if Phase 23's Settings screen adds one, it will be a separate spec.

### Privacy & sensitivity

Theme and locale are **not personally identifying information** under any reasonable interpretation. They are stored in secure storage purely for convenience (Decision 6 in research.md): standardizing on `flutter_secure_storage` from Phase 1 means later auth tokens (Phase 5) plug into the same `PreferencesStore` interface without introducing a second persistence library.

ADR-0001 (Supabase Vault) does NOT apply: Vault is for backend-side secrets and admin-only PII, not for non-sensitive on-device preferences.

---

## Backend tables

**None in Phase 1.**

The migration `00000000000000_init_extensions.sql` enables two Postgres extensions:

- `pgcrypto` — generic crypto utilities; `gen_random_uuid()` for primary keys in later phases.
- `uuid-ossp` — additional UUID generators, kept enabled for compatibility with prior Postgres-on-Supabase patterns.

No tables, views, types, RLS policies, or functions are created. Phase 4 (`004-supabase-foundation`) will add `profiles`, `user_preferences` (the *backend* one — different from the local one above), and `audit_logs`, plus the Supabase Vault enablement (`pgsodium` + Vault scaffolding) per ADR-0001.

### Note on the name collision

There are two distinct "User Preferences" entities in the AlNujom data model:

| Name | Layer | Phase introduced | What it stores | Linked to a user account? |
|---|---|---|---|---|
| **User Preferences (local)** | Device (this phase) | Phase 1 | `themeMode`, `localeCode` | No |
| **User Preferences (backend)** | Postgres (`user_preferences` table, RLS-protected) | Phase 4 | TBD per Phase 4 spec — likely cross-device synced settings, notification toggles, etc. | Yes — `user_id` FK to `auth.users` |

Phase 1's entity has *no* relationship to Phase 4's table. When Phase 4's spec is written, it must explicitly clarify whether and how it shadows or replaces the local entity. The simplest path (and the recommended one) is for the backend `user_preferences` to be additive — local theme/locale stays local for fast cold-start UX, and only post-auth, multi-device-relevant settings live in the backend table.

---

## Relationships

None. The single Phase 1 entity is standalone and has no foreign keys.

---

## Consumers (interfaces that read/write this entity)

| Consumer | File | Operation |
|---|---|---|
| `main.dart` | `lib/main.dart` | reads both keys at startup; passes initial values to cubits |
| `ThemeCubit` | `lib/core/theme/theme_cubit.dart` | writes `theme_mode` on toggle; reads at construction |
| `LocaleCubit` | `lib/core/localization/locale_cubit.dart` | writes `locale_code` on toggle; reads at construction |

All three consumers go through the `PreferencesStore` interface defined in `contracts/preferences-store.md` — no consumer talks to `flutter_secure_storage` directly.
