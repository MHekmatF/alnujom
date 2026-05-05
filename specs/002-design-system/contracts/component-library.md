# Contract: Component Library

**Status**: Phase 2 deliverable | **Spec**: [../spec.md](../spec.md) | **Plan**: [../plan.md](../plan.md) | **Source catalog**: [`../../../docs/design/screens-and-components.md`](../../../docs/design/screens-and-components.md) §5

## Purpose

Define the canonical list of reusable widgets Phase 2 ships under `lib/core/widgets/` plus three feature-shared shims under `lib/shared/presentation/widgets/`. This contract names each component, its file, its required variants and states, and links its detailed anatomy to `screens-and-components.md` §5. Feature phases consume from this catalog only — any new visual primitive a feature needs MUST land here first (FR-013).

## Component table

| # | Name | File | Variants | Required states (subset of `ComponentState`) | Anatomy ref |
|---|---|---|---|---|---|
| 1 | `AppAppBar` | `lib/core/widgets/app_app_bar.dart` | `default`, `withBack`, `withSearch`, `transparentOnImage` | `default`, `pressed` (back/icons) | §5.1 |
| 2 | `SearchField` | `lib/core/widgets/search_field.dart` | `idle`, `withFilterIcon` | `default`, `focused`, `loading`, `disabled` | §5.2 |
| 3 | `LocationSelector` | `lib/core/widgets/location_selector.dart` | one variant | `default`, `pressed`, `disabled` | §5.3 |
| 4 | `CategoryChip` | `lib/core/widgets/category_chip.dart` | one variant (idle/selected through prop) | `default` (= idle), `pressed`, `focused`, `selected`, `disabled` | §5.4 |
| 5 | `PropertyCard` | `lib/core/widgets/property_card.dart` | `vertical`, `horizontal` | `default`, `pressed`, `loading` (skeleton), `empty` (placeholder image) | §5.5 |
| 6 | `OfficeCard` | `lib/core/widgets/office_card.dart` | one variant | `default`, `pressed`, `loading` (skeleton) | §5.6 |
| 7 | `AppButton` | `lib/core/widgets/app_button.dart` | `filledPrimary`, `filledSuccess`, `outlined`, `tonal`, `text`, `destructive`, `iconButton`, `fab`; sizes `regular` (48 dp) and `dense` (36 dp) | `default`, `pressed`, `focused`, `loading`, `disabled` | §5.7 |
| 8 | `AppTextField` | `lib/core/widgets/app_text_field.dart` | base text-input | `default` (idle), `focused`, `filled`, `error`, `disabled` | §5.8 |
| 9 | `AppPhoneField` | `lib/core/widgets/app_phone_field.dart` | one variant (`+963` prefix) | as `AppTextField` | §5.8 |
| 10 | `AppPasswordField` | `lib/core/widgets/app_password_field.dart` | with eye toggle | as `AppTextField` | §5.8 |
| 11 | `AppMultiLineField` | `lib/core/widgets/app_multi_line_field.dart` | with character counter | as `AppTextField` | §5.8 |
| 12 | `AppNumberField` | `lib/core/widgets/app_number_field.dart` | with leading/trailing unit suffix | as `AppTextField` | §5.8 |
| 13 | `AppCurrencyField` | `lib/core/widgets/app_currency_field.dart` | with USD/SYP toggle | as `AppTextField` | §5.8 |
| 14 | `AppDropdown` | `lib/core/widgets/app_dropdown.dart` | one variant | `default`, `focused`, `error`, `disabled` | §5.8 |
| 15 | `AppStepperInput` | `lib/core/widgets/app_stepper_input.dart` | one variant (− value +) | `default`, `disabled` | §5.8 |
| 16 | `AppDatePicker` | `lib/core/widgets/app_date_picker.dart` | one variant | `default`, `focused`, `disabled` | §5.8 |
| 17 | `AppToggle` | `lib/core/widgets/app_toggle.dart` | switch | `default`, `disabled` | §5.8 |
| 18 | `AppCheckbox` | `lib/core/widgets/app_checkbox.dart` | one variant | `default`, `pressed`, `disabled` | §5.8 |
| 19 | `AppRadioGroup` | `lib/core/widgets/app_radio_group.dart` | radio group + segmented control | `default`, `pressed`, `disabled` | §5.9 |
| 20 | `AppTabs` | `lib/core/widgets/app_tabs.dart` | `segmented` (2 / 3 segments), `underline` (4 + items) | `default`, `selected`, `disabled` | §5.9 |
| 21 | `AppBadge` | `lib/core/widgets/app_badge.dart` | `featured`, `new`, `statusPending`, `statusApproved`, `statusRejected`, `verifiedOffice` | `default` only (badges are non-interactive) | §5.10 |
| 22 | `AppBottomSheet` | `lib/core/widgets/app_bottom_sheet.dart` | one variant (drag handle, sticky footer) | `default` | §5.11 + §4.3 |
| 23 | `AppDialog` | `lib/core/widgets/app_dialog.dart` | `confirm`, `destructive` | `default` | §4.3 |
| 24 | `EmptyState` | `lib/core/widgets/empty_state.dart` | one variant (illustration → headline → body → CTA) | `default` | §5.12 + §7.21 |
| 25 | `LoadingState` | `lib/core/widgets/loading_state.dart` | skeleton helpers for the most common layouts (card, row, avatar) | `default` | §3.3 + §4.2 |
| 26 | `ErrorState` | `lib/core/widgets/error_state.dart` | `default`, `network` | `default` (always shows retry CTA) | §4.2 |
| 27 | `StepperIndicator` | `lib/core/widgets/stepper_indicator.dart` | one variant (N segments) | `default` | §5.13 |
| 28 | `ImageGallery` | `lib/core/widgets/image_gallery.dart` | carousel + fullscreen | `default`, `loading` (skeleton), `empty` (placeholder) | §5.14 |
| 29 | `MapPreview` | `lib/core/widgets/map_preview.dart` | static placeholder only — real `flutter_map` integration arrives in Phase 15 | `default`, `loading` | §5.15 |
| 30 | `ChatBubble` | `lib/core/widgets/chat_bubble.dart` | `mine`, `theirs` | `default` | §5.16 |
| 31 | `PriceTag` | `lib/core/widgets/price_tag.dart` | one variant (bold primary number + currency suffix; optional alt-currency line) | `default` | §5.17 |
| 32 | `AppBottomNav` | `lib/core/widgets/app_bottom_nav.dart` | 5-tab spine (RTL-ordered) | `default`, `selected`, `disabled` (per tab) | §6 |
| 33 | `PaletteTester` | `lib/core/widgets/palette_tester.dart` | one variant — debug only (gated by `kDesignToolsEnabled`) | `default`, `pressed`, `aftercycle` (with snackbar) | §5.18 |

> Note: the 21-component count in `IMPLEMENTATION_PLAN.md` collapses several siblings (the form fields are counted as a single "form fields" entry, etc.). The table above expands those siblings into the actual one-file-per-widget structure Phase 2 ships, totaling 33 files. The naming and visual treatments are unchanged from the source catalog.

## Feature-shared shims (`lib/shared/presentation/widgets/`)

| Name | File | Behavior |
|---|---|---|
| `ListingCard` | `lib/shared/presentation/widgets/listing_card.dart` | Re-exports `PropertyCard` from the core kit (research R-09). One-line `export` plus a `typedef ListingCard = PropertyCard;` so feature phases that prefer the listing-domain name don't reach into `lib/core/widgets/` directly. |
| `PriceDisplay` | `lib/shared/presentation/widgets/price_display.dart` | Re-exports `PriceTag` under the original `IMPLEMENTATION_PLAN.md` Phase 2 name. |
| `AdminListItem` | `lib/shared/presentation/widgets/admin_list_item.dart` | Admin-list row primitive used by Phase 7+ admin screens. Single variant. Composed from `AppListTile`-style internals built on the core kit (no inline styles). |

## Invariants

1. **One canonical visual treatment per `(component, variant, state)`**. A feature that needs a different look opens a new component spec; never inlines.
2. **No raw style literals inside any of these files**. Every color, type style, spacing, radius, and shadow comes from the design-tokens contract.
3. **Touch targets ≥ 48 × 48 dp** (FR-012). Components designed at 36 dp dense size MUST extend their hit area.
4. **No color-only state signaling** (FR-012). Every state is accompanied by an icon, label, or shape change.
5. **RTL correctness** (FR-006). Use `EdgeInsetsDirectional`, `Alignment.centerStart`/`centerEnd`, `PositionedDirectional`. Back-arrow icons mirror under `Directionality.of(context)`.

## Test surface

- One widget test per component under `test/core/widgets/<component>_test.dart`. Each test exercises every applicable state and asserts: rendered colors come from `AppColors.of(context)`, rendered styles come from `AppTextStyles.of(context)`, hit-target dimensions ≥ 48 dp, RTL layout under `Directionality.rtl`.
- Per FR-011 / SC-006, `PropertyCard` adds golden tests in 4 environment combinations (light × ar, light × en, dark × ar, dark × en) under the Modern palette.
- The Palette Tester widget test asserts that with `kDesignToolsEnabled = false`, the chip widget does not render.
