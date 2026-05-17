# Contract: Locations Localization (ARB keys + bilingual display_name)

**Branch**: `008-locations` | **Date**: 2026-05-16 | **Plan**: [../plan.md](../plan.md) | **Spec**: [../spec.md](../spec.md) FR-023, FR-016 | **Data model**: [../data-model.md](../data-model.md) §8

## Two localization mechanisms

Phase 8 localization splits cleanly into two mechanisms:

### Mechanism 1: ARB keys for app chrome (page titles, buttons, dialogs, errors)

Every user-visible string introduced by the Phase 8 admin pages and the LocationPicker widget flows through `AppLocalizations.of(context)` (the Phase 3 codegen path). The keys ship in both `lib/l10n/app_ar.arb` and `lib/l10n/app_en.arb` in the same commit per Phase 3's localization gate.

The inventory of ~25 keys is enumerated in `data-model.md §8`. Implementers MUST:

1. Add the key + value to both ARB files.
2. Re-run the Phase 3 codegen (`flutter pub run build_runner build` or `flutter gen-l10n`, depending on the project's pipeline).
3. Consume the generated getter via `AppLocalizations.of(context).<keyName>`.
4. Verify the Phase 3 lint guard finds zero hardcoded user-facing strings in the new code.

The Arabic copy MUST be Syrian-friendly per Constitution V; avoid Modern Standard Arabic phrasings that read stiff. Example: prefer "إضافة" (Add) over more formal alternatives.

### Mechanism 2: Bilingual `display_name` JSONB on data rows

Every catalog row (governorate / city / area) carries its own `display_name JSONB` with shape `{"ar": "...", "en": "..."}` (Phase 6 `roles.display_name` pattern). The Arabic value is required at INSERT time (CHECK constraint); the English value is optional (FR-016).

Rendering rules per `domain/entities/<entity>.dart::localizedName(Locale)` (R-18):

1. Try `display_name->>'<active locale>'`; if non-empty after trim, return it.
2. Else try `display_name->>'<other locale>'`; if non-empty, return it.
3. Else return the row's `key` slug as a last-resort label.

The chain is implemented in a single helper per entity; no widget re-implements it. Compliance is checked by `grep -R "display_name\[" lib/features/locations/presentation` returning zero matches (widgets MUST call `entity.localizedName(locale)`, not access the map directly).

## `BilingualDisplayNameField` widget contract

Per R-19, a single widget renders the bilingual input pair for every add/edit form (governorate / city / area). Contract:

```dart
class BilingualDisplayNameField extends StatefulWidget {
  const BilingualDisplayNameField({
    super.key,
    this.initialArabic,
    this.initialEnglish,
    required this.onChanged,
  });

  final String? initialArabic;
  final String? initialEnglish;
  final ValueChanged<({String? arabic, String? english})> onChanged;
}
```

The widget MUST:

- **Layout**: render the two inputs stacked vertically (one `Column` with two children) — NOT side-by-side. The Arabic input is always FIRST in the column (top); the English input is always SECOND (bottom). Stacking vertically avoids any RTL/LTR layout ambiguity on the reference Infinix Note 8's portrait viewport. Each input is a full-width `TextFormField`.
- **Direction**: the Arabic `TextFormField` is wrapped in `Directionality(textDirection: TextDirection.rtl, child: ...)` regardless of the device locale (Arabic text always renders RTL). The English `TextFormField` is wrapped in `Directionality(textDirection: TextDirection.ltr, child: ...)` regardless of device locale.
- **Labels**: the Arabic input shows the `displayNameArabicLabel` ARB key as its label; English input shows `displayNameEnglishLabel`.
- **Validation**: the Arabic `TextFormField.validator` returns `AppLocalizations.of(context).arabicNameRequired` when `value?.trim().isEmpty ?? true`; the English input has no validator (the value is optional per FR-016).
- **Emit**: every keystroke (`onChanged` on either field) invokes the parent's `onChanged` callback with a Dart record `({String? arabic, String? english})` carrying the current values of both fields. (Dart records require Dart SDK ≥ 3.0; verify `pubspec.yaml`'s `environment.sdk` constraint admits this — Phase 7 already established Dart 3.x is in use.)

## Locale toggle behavior

When the device locale changes (user manually toggles or system change), the admin pages and the LocationPicker MUST re-render with:

- ARB-driven chrome strings in the new locale (automatic via `AppLocalizations.of(context)`).
- Data-row labels in the new locale (via `entity.localizedName(locale)`).
- User selection state preserved (per US6 acceptance scenario 6).

## Constitution traceability

- Constitution V (Arabic-First Localization): both mechanisms put Arabic first — ARB files store Arabic as the default; bilingual JSONB requires Arabic.
- Phase 3 localization gate: every new user-visible string ships in both ARB files in the same commit; the Phase 3 lint guard verifies coverage.
- Phase 6 R-13 / R-18 carry-forward: the bilingual JSONB shape and fallback chain match `roles.display_name`.
