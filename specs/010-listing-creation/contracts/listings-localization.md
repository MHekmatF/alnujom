# Contract: Listings Localization

**Owner**: Phase 10.
**Consumers**: every new widget under `lib/features/listing_form/presentation/` and `lib/features/publisher_dashboard/presentation/`.

## Obligations

All ~40 new user-visible chrome strings ship in both `lib/l10n/app_ar.arb` and `lib/l10n/app_en.arb` in the same commit per Phase 3's localization gate. The full key inventory is in [data-model.md § ARB key inventory](../data-model.md).

### Categories

1. **Form chrome** (~14 keys): step headers, navigation buttons, progress indicator, media placeholder banner.
2. **Field labels** (~15 keys): one per form field, used by every step widget.
3. **Validator errors** (~6 keys): per [validators.md](validators.md).
4. **Status badges** (~9 keys): one per listing status.
5. **Rejection / resubmit / failures** (~6 keys): rejection-reason header, resubmit CTA, submit-failure dialog title + body + per-field labels, approved-not-editable message.
6. **`submit_listing` structured errors** (~3 keys): publisher-not-approved, listing-not-editable, unknown.

### Arabic copy guidelines

Per Constitution V (Arabic-First Localization):

- Default Arabic; English is co-equal but secondary.
- Syrian-friendly, professional, clear. Avoid Modern Standard Arabic stiffness where a natural Levantine equivalent reads better.
- Currency-symbol position follows Phase 9's locale rule (suffix in `ar` always; English uses prefix `$` for USD, suffix code `SYP` for SYP).
- Status badge labels are short (≤2 words in either locale).
- Validator error messages are imperative and helpful ("Please enter a positive area size", not "Invalid input").

### Bilingual data labels

Bilingual data labels do NOT flow through ARB:

- Governorate / city / area names come from Phase 8's `name_ar`/`name_en` columns on each table.
- Currency names + symbols come from Phase 9's `currencies.name_ar`/`name_en`/`symbol` columns.
- Status badge label text comes from ARB (because the status enum is fixed; not user data).

### `missing_fields[]` payload localization

The `submit_listing` RPC returns dot-notated paths (e.g., `listings.governorate_id`, `listings.area_size`, `listings.phone_or_whatsapp`, `listing_prices.primary`). The client maps each path to a localized field label via a `missingFieldLabel(path, l10n)` helper. New ARB keys per missing-field path follow the naming convention `missingField_<dot_notated_path_with_underscores>`.

### RTL / LTR

Form widgets MUST use `EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional` — no `EdgeInsets.only(left: ...)` or `Alignment.centerLeft`. The status-filter chip row reads naturally in both directions because chips are symmetric. The price-preview subline aligns to the start (which is right in `ar`, left in `en`).

## Verification

```
On the device:
1. Set locale=ar; open the form. Verify every label, button, validator error, status badge renders in Arabic.
2. Set locale=en; reload the form. Verify every label re-renders in English.
3. Verify Phase 3 localization lint guard passes at PR review (zero hardcoded user-facing strings under lib/features/listing_form/ and lib/features/publisher_dashboard/).
4. Submit a draft with multiple missing fields. Verify the missing-field dialog renders each path with a localized human label (e.g., "حقل المساحة" instead of "listings.area_size") in ar locale.
```

## Forbidden

- Adding hardcoded user-facing strings to widget code (Constitution V violation).
- Adding ARB keys to one locale file but not the other (Phase 3 localization gate blocks merge).
- Pulling localization data from Supabase at runtime (l10n is build-time).
- Adding governorate/city/area/currency labels to ARB (they come from the bilingual table columns).
