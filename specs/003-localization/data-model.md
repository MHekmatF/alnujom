# Phase 1 Data Model — Localization

Phase 3 has **no database changes** — no new Supabase tables, no RLS, no migrations, no Edge Functions. The "data model" below describes the in-memory and on-disk artifacts the localization layer reads, writes, and reasons about, and the validation rules each must obey. Persistence is via `flutter_secure_storage` (interim) and the version-controlled ARB files under `lib/l10n/`.

## Entities

### Locale Preference

A single value representing the user's currently active language.

| Attribute | Type | Constraints |
|-----------|------|-------------|
| `language_code` | string | One of `ar`, `en`. ISO 639-1 lowercase. No region suffix. |
| `persisted_at` | timestamp (implicit) | Set by `flutter_secure_storage` on each write; not exposed to the application layer. |

**Storage**: `flutter_secure_storage` under the key `com.alnujom.preferences.locale_code` (existing constant in `SecurePreferencesStore`). Value is the raw `language_code` string.

**Bootstrap rule**: On app start, `main.dart` reads `PreferencesStore.readLocale()`. If the read returns null (fresh install) or fails (storage exception), the value `Locale('ar')` is applied via `LocaleCubit.defaultLocale`. The OS locale is intentionally not consulted (FR-001, R-10).

**Mutation rule**: Only `LocaleCubit.toggle()` mutates the value. The cubit emits the new `Locale` to the bloc stream (driving the UI rebuild) and writes through to `PreferencesStore.writeLocale(...)`. A failed write is logged via `AppLogger.warning` but does not roll back the in-session emission (the user's choice survives the session even if persistence fails).

**Lifecycle**:
- `null` (never persisted) → bootstrap applies the Arabic default.
- `'ar'` ⇄ `'en'` via toggle, no other transitions.
- Cleared when the user wipes app data (returns to the `null` → Arabic default state).
- Phase 5 handoff: at first sign-in after Phase 5 ships, the user-scoped `user_preferences.locale` row becomes the source of truth; Phase 5 spec owns the migration.

---

### Translation File

A version-controlled ARB document under `lib/l10n/`. One per supported locale.

| Attribute | Type | Constraints |
|-----------|------|-------------|
| `path` | string | Exactly one of `lib/l10n/app_ar.arb` or `lib/l10n/app_en.arb`. |
| `locale` | string | ISO 639-1 — `ar` or `en`. Matches the file's `@@locale` metadata key. |
| `entries` | map<string, string> | Translation Key → translation value. See Translation Key below. |
| `metadata` | map<string, object> | ARB metadata keys (`@@locale`, per-key `@key` descriptors with placeholder declarations). Not subject to parity check. |

**Validation rules** (enforced by `tool/lint_l10n_parity.dart`, R-06):
- The set of non-metadata keys MUST be identical between `app_ar.arb` and `app_en.arb`. The script fails the build with a per-locale list of missing keys when sets differ.
- `@@locale` MUST match the file's filename suffix (e.g., `app_ar.arb` declares `"@@locale": "ar"`).
- Files MUST be valid JSON. Parse failure is a script exit code `2` (red build).

**Mutation rule**: Translation files are edited only as part of a code change. After every edit, the developer runs `flutter gen-l10n` (or equivalent) to regenerate the typed Dart bindings under `lib/l10n/app_localizations*.dart`. The generated files are checked in (`synthetic-package: false`).

**Lifecycle**:
- Phase 1 created both files with 6 scaffolding keys.
- Phase 3 expands the corpus to ~17 keys (R-11) and locks the parity contract.
- Subsequent phases ADD keys for their feature surfaces; they MUST NOT remove a Phase 3 floor key without replacement.

---

### Translation Key

A namespaced identifier referenced from widget code; resolves to a localized string via the generated `AppLocalizations` API (or, in debug builds, through the `AppStrings` wrapper from contract `app-strings.md`).

| Attribute | Type | Constraints |
|-----------|------|-------------|
| `name` | string | `lowerCamelCase`. Must be a valid Dart identifier. Must not start with an underscore. |
| `arabic_value` | string | Required entry in `app_ar.arb`. Syrian-friendly tone per FR-011 seeded terms. |
| `english_value` | string | Required entry in `app_en.arb`. Clear, professional. |
| `placeholders` | list<placeholder> | Optional. Declared in the ARB metadata block. Same set in both locales. |

**Naming convention**:
- Section prefixes group related keys: `theme*`, `locale*`, `error*`, `themeGallery*`, `app*`. Future feature phases prefix by feature (e.g., `homeListing*`, `propertyDetail*`).
- A key is referenced from at most one logical surface to keep ownership clear; if two surfaces need the same string, both reference the same key (no duplication).

**Validation rules**:
- Identical key set in both ARB files (enforced by `tool/lint_l10n_parity.dart`).
- Declared at compile time via `flutter gen-l10n` (referencing a non-existent key is a Dart compile error, not a runtime miss).
- The Phase 3 floor (R-11) is composed of three groups: app shell strings, Theme Gallery chrome, standard error messages. Plus 2 keys for the FR-008 missing-key debug marker copy.

**Lifecycle**:
- Created when added to both ARB files in the same change.
- Renamed only via simultaneous rename in both ARB files plus every Dart consumer; the parity script and the Dart compile both fence stale references.
- Removed only when no consumer references the key; the lint guards do not yet detect orphaned keys (out of Phase 3 scope; nice-to-have for a later cleanup spec).

---

### Lint Exemption List

A version-controlled allowlist of file globs that the two lint guard scripts skip when scanning.

| Attribute | Type | Constraints |
|-----------|------|-------------|
| `path` | string | Always `analysis_options.yaml` (top-level YAML block named `l10n_lint_exempt:`). |
| `patterns` | list<glob> | One pattern per line. Standard glob syntax (`**`, `*`). |

**Phase 3 floor patterns** (R-05, FR-006, Q1):

```yaml
l10n_lint_exempt:
  - lib/l10n/**.arb
  - lib/l10n/app_localizations*.dart
  - lib/debug/**
  - test/goldens/**
```

**Validation rules**:
- Adding a pattern is a code change reviewed via the standard PR process. There is no implicit exemption based on directory naming or path patterns outside this list.
- Both `tool/lint_l10n_literals.dart` and `tool/lint_l10n_parity.dart` MUST read the same block from the same file — the exemption list is a single source of truth.

**Lifecycle**:
- Created in Phase 3 with the four locked patterns.
- Future additions go through PR review; reviewers should challenge any addition that broadens the exemption beyond a structurally-debug or generated path.

---

### Layout Direction (derived)

Not a stored entity — derived in real time from `Locale Preference`.

| Source locale | Derived direction |
|---------------|-------------------|
| `ar` | `TextDirection.rtl` |
| `en` | `TextDirection.ltr` |

**Resolution**: Flutter's `Localizations` widget resolves direction from the locale's script automatically; the Phase 3 layer relies on this and does not introduce a parallel preference. Per FR-009, all directional layout primitives (`EdgeInsetsDirectional`, logical `start`/`end` alignments, `Directionality`-aware widgets) honor the resolved direction; hardcoded `left`/`right` values are forbidden in feature code.

---

## Relationships

```
Locale Preference  ──── persisted via ────►  flutter_secure_storage (key: com.alnujom.preferences.locale_code)
        │
        │ drives
        ▼
Layout Direction (derived)
        │
        │ inputs to
        ▼
MaterialApp.locale  ────►  Localizations widget  ────►  AppLocalizations (generated)  ────►  Translation Key lookups in widget code
                                                              ▲
                                                              │ generated from
                                                              │
                                                       Translation Files (app_ar.arb, app_en.arb)
                                                              ▲
                                                              │ scanned by
                                                              │
                                                       tool/lint_l10n_parity.dart  ◄────  Lint Exemption List
                                                                                          (analysis_options.yaml)
                                                                                          ▲
                                                                                          │ also consumed by
                                                                                          │
                                                                                   tool/lint_l10n_literals.dart
                                                                                                       │
                                                                                                       ▼
                                                                                                Dart sources under lib/
```

## State transitions

The only stateful entity is `Locale Preference`. Its state machine:

```
       (fresh install / app data wiped)
                   │
                   ▼
         ┌──────────────────┐
         │ null  (no value) │ ── bootstrap ──► applies Locale('ar') as default
         └──────────────────┘
                   │
                   │ first toggle persists the chosen value
                   ▼
       ┌─────────────────────┐  ◄──── toggle() ────►  ┌─────────────────────┐
       │  language_code='ar' │                        │  language_code='en' │
       └─────────────────────┘                        └─────────────────────┘
                   │
                   │ user wipes app data
                   ▼
                  null  (returns to top of diagram)
```

No other transitions exist; there is no "auto / follow OS" state in Phase 3 (Settings-level locale management is owned by Phase 23).
