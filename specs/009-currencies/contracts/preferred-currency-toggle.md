# Contract: Preferred Currency Toggle (Profile / Settings)

**Owner**: Phase 9 (`lib/features/currencies/presentation/widgets/preferred_currency_toggle.dart` consumed by the existing Phase 5 profile/settings page).
**Consumers**: every signed-in user; downstream surfaces consuming `user_preferences.display_currency` via the FR-019a row-selection rule.

## Obligations

The toggle widget MUST:

1. Read all `is_active=true` rows from `public.currencies` ordered by `sort_order ASC, code ASC`.
2. Render each row as a selectable option labeled with the active-locale `localizedName` per R-18 (active locale → other locale → `code`).
3. Pre-select the option whose `code` matches the user's current `user_preferences.display_currency` value.
4. On selection change:
   - Dispatch an `UPDATE public.user_preferences SET display_currency = $code WHERE user_id = auth.uid()` via the data-layer repository.
   - The UPDATE is authenticated and satisfies the self-only RLS policy on `user_preferences`.
   - On success, the next paint of any visible listing-card surface re-renders per the FR-019a row-selection rule (Phase 13+ consumers; Phase 9 only has the smoke-test showcase).
5. Handle the deactivated-currency fallback (US4 acceptance scenario 4): if `user_preferences.display_currency` references a row that is currently `is_active=false`, fall back to the first `is_active=true` row by `sort_order ASC` and persist the fallback.
6. Handle the NULL fallback (FR-019 `ON DELETE SET NULL`): if `user_preferences.display_currency IS NULL`, render the same fallback (first `is_active=true` by `sort_order ASC`) and persist on first selection.

The UI label MUST be "Preferred currency" (FR-018 wording) — NOT "Display currency" — to reflect that the value is a row-selection preference (per Q1) rather than a conversion trigger.

## Forbidden

- Triggering any exchange-rate lookup or `MoneyFormatter` call as a side-effect of the toggle change. The toggle persists a preference; downstream surfaces read it on their next paint.
- Allowing deactivated currencies to appear in the selection list. The filter is strictly `is_active=true`.
- Persisting the selection to `flutter_secure_storage` instead of `user_preferences.display_currency`. The database is the source of truth.
- Calling the toggle "Display currency" in the UI label (the DB column name `display_currency` is preserved for backward compatibility with Phase 4 migrations).

## Verification

```bash
# Manual UI: open profile/settings on the device
# Confirm "Preferred currency" toggle is visible
# Confirm two options labeled "ليرة سورية" and "دولار أمريكي" (Arabic locale)
# Confirm the currently-selected option matches user_preferences.display_currency
# Tap a different option
# Verify: SELECT display_currency FROM public.user_preferences WHERE user_id = '<this user>'; reflects the new value
```
