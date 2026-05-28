# Contract — `InquiryFormSheet` modal bottom sheet

**Owner**: Sub-Phase F (`lib/features/inquiries/presentation/sheets/inquiry_form_sheet.dart`).

**Consumers**: Sub-Phase H `ContactBlock._onSendInquiryPressed`.

## Presentation shape

Material `showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => InquiryFormSheet(listingId: ...))` — per R-98.

## Widget composition

```text
DraggableScrollableSheet (initialChildSize 0.6, maxChildSize 0.9)
└── BlocProvider<InquiryFormBloc>
    └── Form
        ├── Header — l10n.inquiry_form_title
        ├── TextField — name (pre-populated from profiles.full_name if signed-in)
        ├── TextField — phone (pre-populated from profiles.phone if signed-in)
        ├── TextField — message (multiline, max 6 lines visible)
        ├── Conditional character counter — visible when typed length ≥ 1600 (R-108)
        └── ElevatedButton — submit
```

## Validation rules

| Field | Rule | ARB key on failure |
|-------|------|---------------------|
| Name | trim → 1..100 chars | `inquiry_form_validation_name_required` |
| Phone | E.164 via Phase 5 `PhoneNumber.tryParse` | `inquiry_form_validation_phone_invalid` |
| Message | trim → 1..2000 chars | `inquiry_form_validation_message_required` / `inquiry_form_validation_message_too_long` |

Submit button is disabled while any field is invalid OR while `state is InquiryFormSubmitting`.

## BLoC contract

**Events**: `InquiryFormFieldChanged({field, value})`, `InquiryFormSubmitted()`.

**States**: `InquiryFormEditing({name, phone, message, validationErrors})`, `InquiryFormSubmitting()`, `InquiryFormSubmitted(inquiryId)`, `InquiryFormFailed(failure)`.

**Side effects on `InquiryFormSubmitted`**: navigate back to the listing details page (pops the sheet) AND show a localized snackbar (`l10n.inquiry_form_success_snackbar`).

**Side effects on `InquiryFormFailed`**: keep the sheet open, surface the failure message, allow retry.

## Pre-conditions

- The listing details page has constructed the sheet with a valid `listingId` of an approved listing.

## Post-conditions

- On success: exactly one inquiry row + one lead event row inserted via `submit_inquiry` RPC (atomic). The visitor is returned to the listing details page; no in-app inquiry tracking is offered per FR-011.

## Stability surface

**Frozen**: the three-field shape (name + phone + message) — adding fields would change the RPC signature.

**Allowed**: redesigning the visual treatment (replace `DraggableScrollableSheet` with a different sheet shape) provided the fields and validation rules are preserved.
