# Contract: `MyListingsPage` (`lib/features/publisher_dashboard/`)

**Owner**: Phase 10.
**Consumers**: Phase 12 (will render the admin's rejection reason via the resubmit CTA path); Phase 22 (may add Realtime to refresh the page on status changes).

## Obligations

`MyListingsPage` renders every `public.listings` row where `publisher_user_id=auth.uid()` AND `status<>'deleted'`, sorted `created_at DESC`, paginated 20 rows per page.

### Page structure

- **Header**: localized "My listings" title + a status-filter chip row (one chip per status: All, Draft, Pending review, Approved, Rejected, Paused, Sold, Rented, Expired). The default chip is "All".
- **Body**: a vertically-scrolling list of `listing_card` widgets, one per listing.
- **Empty state**: localized "No listings yet" + "Create your first listing" CTA (only shown if the publisher is approved; otherwise the page is unreachable per the route guard).
- **Pull-to-refresh**: re-fetches the page.

### Listing card

Each card shows:
- Title (publisher-entered).
- Primary price rendered via Phase 9 `MoneyFormatter` against the listing's single `is_primary=true` `listing_prices` row.
- Location label: governorate name + area name from Phase 8 `governorates` / `areas` bilingual columns, active-locale.
- Creation date in the active locale's date format.
- Status badge: color-coded per Phase 2 design tokens (`draft`=neutral, `pending_review`=warning, `approved`=success, `rejected`=danger, `paused`=neutral, `sold`/`rented`/`expired`=muted).

For `status='rejected'` cards: an additional `rejection_reason_block` widget renders the `reason` from the most recent `listing_status_history` entry plus a "Resubmit" CTA. Tapping the CTA opens the multi-step form pre-populated.

### Tap behavior

- `status IN ('draft', 'rejected')` → opens the multi-step form pre-populated (`ListingFormPage`).
- Any other status → opens `read_only_listing_preview` (a read-only summary; no edit affordance; localized "approved listings can not be edited in v1; contact support" banner when status='approved').

### Filter chip behavior

Tapping a chip filters the visible list to listings whose `status` matches the chip's value. The filter is applied server-side via the `ListMyListings` use case (re-querying with the status filter). Tapping "All" clears the filter.

### Data shape

The BLoC owns the page state. The repository returns `List<PublisherListing>` where `PublisherListing` carries the listing + the most-recent `listing_status_history` entry + the primary `listing_prices` row + computed flags (`isEditable`, `hasRejectionReason`).

## Verification

```
On the device:
1. Sign in as an approved publisher with at least one listing in each status: draft, pending_review, rejected.
2. Open My Listings.
3. Verify the page renders all listings; verify the status-filter chip row is present.
4. Verify tapping each chip narrows the list correctly.
5. Verify each card shows title, formatted primary price (via MoneyFormatter), governorate + area label, creation date, status badge.
6. Verify the rejected card shows the rejection reason text + "Resubmit" CTA.
7. Tap the rejected card's "Resubmit" CTA → ListingFormPage opens with all fields pre-populated.
8. Tap a draft card → ListingFormPage opens with all fields pre-populated.
9. Tap a pending_review card → read-only preview opens; verify no edit affordance.
```

## Forbidden

- Querying directly via Supabase from inside a widget (Constitution IX violation).
- Caching the page beyond the BLoC's in-memory state (R-20).
- Rendering listings with `status='deleted'`.
- Allowing tap-to-edit on `approved` listings (Phase 12+ owns the post-approval edit flow).
- Showing the rejection reason on non-rejected cards.
