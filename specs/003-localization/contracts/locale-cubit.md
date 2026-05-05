# Contract: LocaleCubit

`lib/core/localization/locale_cubit.dart` — already exists from Phase 1. Phase 3 verifies and documents the contract; no behavioral change is required by this phase.

## Purpose

Single source of truth for the active `Locale` at runtime. Drives `MaterialApp.locale` via a `BlocBuilder<LocaleCubit, Locale>` in `lib/app.dart`. Owns the read-through / write-through flow against `PreferencesStore` (bound to `SecurePreferencesStore` via DI).

## Public API

```dart
@injectable
final class LocaleCubit extends Cubit<Locale> {
  LocaleCubit(this._preferencesStore, this._logger, @factoryParam Locale? initialLocale);

  static const Locale defaultLocale = Locale('ar');
  static const Locale englishLocale = Locale('en');

  Future<void> toggle();
}
```

## Behavioral guarantees

| Behavior | Guarantee |
|----------|-----------|
| Bootstrap default | If `initialLocale` is null and no value is persisted, the cubit emits `Locale('ar')`. (`main.dart` resolves the persisted value before construction; the cubit itself does not re-read storage on init.) |
| Toggle | `toggle()` emits the opposite locale of the current state (`ar` → `en`, `en` → `ar`), then writes the new value to `PreferencesStore.writeLocale(...)`. The emit happens BEFORE the await on the write so the UI rebuilds immediately. |
| Persistence failure | If `PreferencesStore.writeLocale(...)` returns `FailureResult`, the failure is logged via `AppLogger.warning` with the failure cause and stack trace. The in-session cubit state is NOT rolled back — the user's choice is honored for the current session even if persistence is unreliable. |
| Live UI rebuild | Every `emit(...)` triggers `BlocBuilder<LocaleCubit, Locale>` in `app.dart` to re-build, which propagates the new `Locale` into `MaterialApp.locale`. The Flutter framework then tears down and rebuilds every `Localizations`-dependent descendant within one frame (FR-003, R-07). |

## Invariants

- The cubit MUST NOT consult `PlatformDispatcher.instance.locale` (the OS locale). The Arabic-first default is hardcoded (FR-001, R-10).
- The cubit MUST NOT expose any other public mutator. No `setLocale(Locale)` overload is added (the toggle is the only sanctioned interaction).
- The cubit MUST NOT take direct dependencies on `flutter_secure_storage` — all persistence flows through the `PreferencesStore` abstraction (Constitution IX).

## Out-of-scope (Phase 3)

- A `setLocale(Locale)` API for picking a third locale or for OS-locale auto-following — out of scope; Phase 23 owns Settings-level locale management.
- Reading the `user_preferences.locale` row from Supabase — out of scope; Phase 5 ships authenticated profiles and owns that integration.
- Listening to OS locale changes at runtime — out of scope; the user's explicit choice (or the Arabic default) wins (FR-001, edge case in spec).

## Verification

Manual on the Infinix Note 8 reference device, per `quickstart.md` steps 1–3 (fresh install → Arabic, toggle to English, kill app, relaunch → English).
