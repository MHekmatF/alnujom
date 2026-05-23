# Contract: Admin Listing Preview Page

**Path**: `lib/features/admin/listing_review/presentation/pages/listing_preview_page.dart`
**Route**: `/admin/listing-review/preview/:id`
**Implements**: FR-011, FR-012, US1, US2
**Verifies**: SC-001, SC-003, SC-011, SC-012

## Page layout

```text
┌────────────────────────────────────────────────────┐
│ AppBar: "Listing preview" + back button           │
├────────────────────────────────────────────────────┤
│ ┌ ListingGallery (Q8=A shared widget) ──────────┐ │
│ │   carousel of media, ordering ASC, main first  │ │
│ │   horizontal-scrollable, 16:9 aspect           │ │
│ └────────────────────────────────────────────────┘ │
│ ┌ ListingPriceBlock (Q8=A shared widget) ───────┐ │
│ │   primary price + secondary prices             │ │
│ └────────────────────────────────────────────────┘ │
│ ┌ ListingLocationBlock (Q8=A shared widget) ────┐ │
│ │   governorate / city / area + address_text     │ │
│ └────────────────────────────────────────────────┘ │
│ ┌ ListingAmenitiesBlock (Q8=A) ─────────────────┐ │
│ │   amenity chips                                │ │
│ └────────────────────────────────────────────────┘ │
│ ┌ ListingDescriptionBlock (Q8=A) ───────────────┐ │
│ │   description body text                        │ │
│ └────────────────────────────────────────────────┘ │
│ (Scrollable body ends here; sticky bar follows)   │
├────────────────────────────────────────────────────┤
│ [ Reject ] [ Approve ]   (sticky BottomAppBar)    │
└────────────────────────────────────────────────────┘
```

## Sticky CTAs (FR-012 + R-51)

```dart
bottomNavigationBar: SafeArea(
  child: BottomAppBar(
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: state.isMutatorInFlight ? null : () => _openRejectDialog(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(AppLocalizations.of(context)!.adminPreviewCtaReject),
          ),
        ),
        const SizedBox(width: 16),  // Phase 2 Spacing.md
        Expanded(
          child: FilledButton(
            onPressed: state.isMutatorInFlight ? null : () => _openApproveDialog(context),
            child: Text(AppLocalizations.of(context)!.adminPreviewCtaApprove),
          ),
        ),
      ],
    ),
  ),
),
```

## Approve confirmation dialog

```dart
showDialog(
  context: context,
  builder: (ctx) => AlertDialog(
    title: Text(AppLocalizations.of(ctx)!.adminApproveDialogTitle),
    content: Text(AppLocalizations.of(ctx)!.adminApproveDialogBody),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(ctx),
        child: Text(AppLocalizations.of(ctx)!.adminApproveDialogCancel),
      ),
      FilledButton(
        onPressed: () {
          Navigator.pop(ctx);
          context.read<ListingPreviewBloc>().add(ListingPreviewApprovePressed());
        },
        child: Text(AppLocalizations.of(ctx)!.adminApproveDialogConfirm),
      ),
    ],
  ),
);
```

## Reject dialog launch

```dart
final result = await showDialog<RejectDialogResult>(
  context: context,
  builder: (ctx) => RejectReasonDialog(),
);
if (result != null) {
  context.read<ListingPreviewBloc>().add(
    ListingPreviewRejectPressed(result.preset, result.detail),
  );
}
```

## Post-mutator behavior

On `ListingPreviewState.lastSuccess != null`:

```dart
BlocListener<ListingPreviewBloc, ListingPreviewState>(
  listenWhen: (prev, curr) => curr.lastSuccess != null && prev.lastSuccess == null,
  listener: (ctx, state) {
    final toastKey = state.lastSuccess is ApproveSuccess
      ? AppLocalizations.of(ctx)!.adminToastApproveSuccess
      : AppLocalizations.of(ctx)!.adminToastRejectSuccess;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(toastKey)));
    ctx.pop();  // back to queue page; queue refreshes via on-pop refresh
  },
  child: ...,
)
```

On `ListingPreviewState.failure != null`:

```dart
listenWhen: (prev, curr) => curr.failure != null && prev.failure != curr.failure,
listener: (ctx, state) {
  final msg = switch (state.failure!) {
    PermissionDeniedFailure() => AppLocalizations.of(ctx)!.adminErrorPermissionDenied,
    InvalidStatusTransitionFailure() => AppLocalizations.of(ctx)!.adminErrorInvalidStatusTransition,
    AlreadyActedOnFailure() => AppLocalizations.of(ctx)!.adminErrorAlreadyActedOn,
    InvalidReasonPresetFailure() => AppLocalizations.of(ctx)!.adminErrorInvalidReasonPreset,
    ReasonDetailTooLongFailure() => AppLocalizations.of(ctx)!.adminErrorReasonDetailTooLong,
    _ => AppLocalizations.of(ctx)!.adminErrorUnknown,
  };
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
  if (state.failure is AlreadyActedOnFailure || state.failure is InvalidStatusTransitionFailure) {
    ctx.pop();  // back to queue
  }
}
```
