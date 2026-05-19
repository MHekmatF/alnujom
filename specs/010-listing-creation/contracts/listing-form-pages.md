# Contract: Listing Form Pages (`lib/features/listing_form/`)

**Owner**: Phase 10.
**Consumers**: Phase 11 (will fill the media-placeholder step); Phase 12 (rejection-reason rendering in the form for the resubmit flow); Phase 19 (will add the "Publish under agency" affordance to the basics step).

## Obligations

Phase 10 ships `lib/features/listing_form/` with the full Constitution IV three-layer split. The form is a single page (`ListingFormPage`) that renders one of seven step widgets based on the BLoC's current-step state.

### Steps (in fixed order)

| Step | Widget | Fields | Q1 required-field set (per FR-010a) |
|---|---|---|---|
| 1. basics | `StepBasics` | title, purpose, property_type | title, purpose, property_type |
| 2. location | `StepLocation` | governorate, city, area (Phase 8 `LocationPicker`), address_text. lat/lng auto-filled from area centroid per FR-013a / Q2 (no UI surface) | governorate_id, city_id, area_id, address_text |
| 3. details | `StepDetails` | description, amenities, year_built, furnished, parking, area_size, rooms, bathrooms, floor | area_size; rooms+bathrooms when property_type IN (apartment, villa) |
| 4. prices | `StepPrices` | currency picker (single, per Q3) + amount field + inline `MoneyFormatter` preview | exactly one `is_primary=true` `listing_prices` row with `amount>0` |
| 5. visibility | `StepVisibility` | location_visibility, contact_name_visibility, hide_until, phone, whatsapp | phone OR whatsapp |
| 6. media | `StepMediaPlaceholder` | none (Phase 11 will fill) | n/a |
| 7. review | `StepReview` | read-only summary + Submit button | n/a |

### BLoC events

| Event | Behavior |
|---|---|
| `LoadOrCreateDraft` | On form mount; either loads an existing draft or INSERTs a new `status='draft'` row |
| `UpdateField(field, value)` | Updates the in-memory form state; does NOT persist |
| `SaveStepAndContinue` | Persists the current step's fields via per-step auto-save (R-13), then transitions to the next step |
| `SaveStepAndExit` | Persists the current step's fields, then dismisses the form back to the dashboard |
| `JumpToStep(step)` | Used only from the Review step's "edit step N" affordance; persists the current step first |
| `Submit` | Calls the `SubmitListing` use case (the `submit_listing` RPC); on success transitions to a success state; on failure renders `SubmitFailureDialog` with the `missing_fields` payload |
| `DeleteDraft` | Confirmable affordance from the dashboard; calls the `DeleteDraft` use case |

### Auto-save granularity (R-13)

Per step transition. The transition is blocked if the save fails; the publisher sees a localized retry affordance.

### Validation surfaces

Per FR-018:
- `AreaSizeValidator` on the area_size field at blur and step-transition.
- `PriceValidator` on the amount field at blur and step-transition.
- `PhoneValidator` on the phone and whatsapp fields at blur and step-transition (auto-normalizes to E.164).

Per FR-010a: the full Q1 Full required-field check runs only at Submit (Review step's Submit button). The client-side check mirrors the server's, but the server is authoritative; on server-side failure, `SubmitFailureDialog` renders the missing fields list.

### Q3 single-currency UX

The prices step has NO "Add another currency" button, NO multi-row UI, NO `is_primary` toggle. The single row's `is_primary=true` flag is auto-applied.

### Q2 centroid auto-fill

When the publisher commits the location step, the BLoC calls `DeriveAreaCentroid(area_id)` use case, reads `centroid_lat`/`centroid_lng` from `public.areas`, and writes them to the draft's `latitude`/`longitude` columns alongside the location step's other fields. The publisher never sees raw lat/lng numbers in Phase 10. If the centroid lookup returns NULL (which should never happen post-seed), the step transition is blocked with a localized "this area is missing map coordinates; please contact admin" error.

## Verification

```
On the device:
1. Sign in as an approved publisher; tap "Create listing".
2. Verify all 7 steps render in order; verify each step's field set matches the table above.
3. Verify per-step auto-save: fill step 1, advance, kill the app, reopen — the draft is preserved.
4. Verify Q1 validation at Submit: leave area_size empty, advance to Review, tap Submit. Expect the `SubmitFailureDialog` listing `area_size` among missing fields.
5. Verify Q2 auto-fill: pick a known area (e.g., Al-Maliki), advance, then check via SQL: SELECT latitude, longitude FROM public.listings WHERE id=<draft_id>. Expect values ≈ 33.5102, 36.2913.
6. Verify Q3 single-currency: the prices step renders one picker + one field; NO "Add another" button anywhere.
```

## Forbidden

- Adding an 8th step.
- Reordering steps.
- Skipping the media placeholder step (Phase 11 hooks into this position).
- Calling Supabase directly from any widget in `presentation/` (Constitution IV/IX violation).
- Validating Q1 fields at step-transition time (FR-014: drafts may have empty required fields; Q1 fires only at Submit).
- Adding multi-row entry to the prices step (Q3 / SC-024 lock).
- Exposing the raw `latitude`/`longitude` values as visible/editable form fields in Phase 10 (Q2 lock; Phase 15 introduces the pin-drop edit).
