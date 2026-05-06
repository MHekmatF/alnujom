# Contract: `UserPreferences` Domain Entity

**Owner**: Phase 4 (`lib/shared/domain/entities/user_preferences.dart`).
**Consumers**: Phase 5 (locale persistence handoff), Phase 9 (display-currency drives money formatting), Phase 23 (settings UI), Phase 22 (notifications-enabled gate). Phase 3's `LocaleCubit` does NOT consume this entity in Phase 4 (it still reads/writes secure storage); the migration of locale persistence into this entity is owned by Phase 5.
**Stability**: **Field shape is stable for v1.** Future preferences (e.g., `email_notifications_enabled`, `marketing_opt_in`) are added as new fields without renaming existing ones.

---

## Purpose

A provider-agnostic domain entity that mirrors the `user_preferences` table's columns. The single source of truth in the domain layer for locale, theme, display currency, and notifications-enabled — per the Q2 clarification, `Profile` does NOT carry locale or currency.

## Class shape

A plain immutable Dart class extending `Equatable`. The full class body is in research [R-10](../research.md#r-10--domain-entity-shape-and-serialization). Fields:

| Field | Type | Notes |
|---|---|---|
| `userId` | `String` | Same as `auth.users.id`. |
| `locale` | `Locale` (from `dart:ui`) | The user's chosen locale. SQL stores `'ar'` or `'en'`; the data layer maps to `Locale('ar')` / `Locale('en')`. |
| `themeMode` | `ThemeMode` (from `package:flutter/material.dart`) | One of `system`, `light`, `dark`. |
| `displayCurrency` | `String` | Free-form in Phase 4. Phase 9 narrows to a `Currency` value object. |
| `notificationsEnabled` | `bool` | |

- **Mutable**: No — all fields `final`; mutations via hand-written `copyWith`.
- **Equality**: Value equality via `Equatable.props`.
- **JSON**: NOT in this entity. Phase 5's data-layer mapper owns row → entity conversion.

## Field semantics

| Field | Source column | Domain meaning |
|---|---|---|
| `userId` | `user_preferences.user_id` | Same as `auth.users.id`. |
| `locale` | `user_preferences.locale` | The user's chosen locale. SQL stores `'ar'` or `'en'`; the data layer maps to `Locale('ar')` / `Locale('en')`. Default `'ar'` per FR-019. |
| `themeMode` | `user_preferences.theme_mode` | One of `system`, `light`, `dark`. Default `system`. |
| `displayCurrency` | `user_preferences.display_currency` | Free-form currency code in Phase 4. Default `'SYP'`. Phase 9 narrows the type to a `Currency` value object once the currencies table lands. |
| `notificationsEnabled` | `user_preferences.notifications_enabled` | Default `TRUE`. Drives push-notification opt-in in Phase 22. |

## Forbidden imports

The file MUST NOT import:

- `package:supabase_flutter/supabase_flutter.dart`.
- Anything under `lib/data/` or `lib/features/<x>/data/`.

The file MAY import:

- `package:equatable/equatable.dart`.
- `dart:ui` (with `show Locale`).
- `package:flutter/material.dart` (with `show ThemeMode`) — this is a UI-framework type but not a backend-provider type, so importing it from a domain entity is acceptable in this codebase (Phase 2's tokens module already does the same).

## Phase 3 → Phase 5 handoff

Phase 3 persists the user's locale via `flutter_secure_storage` through `SecurePreferencesStore.writeLocale` / `readLocale`. Phase 4's `user_preferences` table is the *future* source of truth, but Phase 4 does NOT migrate the value — that handoff is owned by Phase 5's auth flow (the first time a signed-in user reaches the app, Phase 5's startup logic upserts the local secure-storage value into `user_preferences.locale` if and only if the row's value still equals the FR-019 default `'ar'`, indicating the user's local choice has not been overridden by an explicit server-side preference).

Phase 4 simply makes the row exist with the FR-019 default; the data-layer mapper that reads it lands in Phase 5.

## Verification (Phase 4 quickstart)

```text
dart analyze lib/shared/domain/entities/user_preferences.dart   # zero issues
```

```text
# Manual check — open user_preferences.dart and confirm the imports are exactly:
# 1. freezed_annotation
# 2. dart:ui (for Locale)
# 3. package:flutter/material.dart (for ThemeMode)
# No supabase_flutter import; no data-layer import.
```
