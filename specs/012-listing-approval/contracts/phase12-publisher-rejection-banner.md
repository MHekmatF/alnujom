# Contract: Publisher Rejection-Reason Banner

**Path**: `lib/features/publisher_dashboard/presentation/widgets/rejection_reason_banner.dart`
**Implements**: FR-015, FR-016 (Resubmit button), US6
**Verifies**: SC-013

## Where it appears

Above each rejected listing card in `MyListingsPage`'s Rejected filter (Phase 10's existing page extended in place).

## Data input

The banner consumes the MOST RECENT rejection from `public.listing_status_history`:

```sql
SELECT
  id,
  changed_at,
  CASE WHEN reason LIKE '{%}' THEN (reason::jsonb)->>'preset' END AS preset,
  CASE WHEN reason LIKE '{%}' THEN (reason::jsonb)->>'detail'  END AS detail
FROM public.listing_status_history
WHERE listing_id = $1 AND new_status = 'rejected'
ORDER BY changed_at DESC
LIMIT 1;
```

## Widget contract

```dart
class RejectionReasonBanner extends StatelessWidget {
  const RejectionReasonBanner({
    super.key,
    required this.listingId,
    required this.preset,
    this.detail,
    required this.rejectedAt,
  });
  final String listingId;
  final RejectionReason preset;
  final String? detail;
  final DateTime rejectedAt;
}
```

## Layout

```text
┌──────────────────────────────────────────────────────┐
│ ⓘ Reviewed by admin team • 2 days ago               │
│                                                     │
│ Photos missing or low quality                       │
│                                                     │
│ > The main photo appears to be a stock image; please│
│ > re-upload from the actual property.               │
│                                                     │
│ [ Resubmit ]      View moderation history →        │
└──────────────────────────────────────────────────────┘
```

- Background: Phase 2's `dangerContainer` token.
- Foreground: Phase 2's `onDangerContainer` token.
- "ⓘ" + attribution: `Theme.of(context).textTheme.labelSmall`.
- Preset label: `Theme.of(context).textTheme.titleSmall`.
- Detail quoted block: `bodyMedium` with `Border(left: BorderSide(color: onDangerContainer.withOpacity(0.5), width: 3))` AND `EdgeInsetsDirectional.only(start: 12, top: 4, bottom: 4)`.
- "Resubmit": `FilledButton.tonal` (FR-016 deep-link).
- "View moderation history": `TextButton` (FR-017 deep-link).

## Resubmit deep-link (FR-016)

```dart
onPressed: () => context.push('/publisher/listings/${listingId}/edit'),
```

Phase 10's edit route is reused as-is. Phase 11's Q3=A `listing_media` row-preservation semantics apply on the resubmit path.

## View moderation history deep-link (FR-017)

```dart
onPressed: () => context.push('/publisher/listings/${listingId}/moderation-history'),
```

## Localized labels

Preset label: `AppLocalizations.of(context)!.rejectPreset<Preset>` — same six ARB keys used by the dialog per R-47.

Attribution: `AppLocalizations.of(context)!.publisherRejectionAttribution` ("Reviewed by admin team").

Time-since: Phase 3's localized time-ago formatter (e.g., "منذ يومين" / "2 days ago").

## Admin identity privacy (FR-015 + Constitution VIII)

The banner displays "Admin team" — NEVER the admin's actual name or UID. The `changed_by` column in `listing_status_history` carries the UID for internal audit purposes, but the publisher-facing UI does NOT join to `profiles` to resolve the admin's name. The banner's data-source query intentionally omits the `changed_by` field from the SELECT.

## "Other" preset rendering

When `preset == RejectionReason.other`, the localized label is "Other — please provide details" (the same ARB key the dialog uses). The free-text `detail` is then rendered in the quoted block. Per Q5=A's UX gate, the `detail` will always be non-empty for "Other" rejections issued through the Phase 12 UI — but the widget is defensive: if `detail == null OR detail.isEmpty`, the quoted block is omitted and the banner renders only the preset label.
