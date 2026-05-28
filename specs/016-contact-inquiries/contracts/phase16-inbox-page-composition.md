# Contract — `InquiryInboxPage` composition + BLoC contract

**Owner**: Sub-Phase F (`lib/features/inquiries/presentation/pages/inquiry_inbox_page.dart`, `inquiry_inbox_bloc.dart`).

**Consumers**: the route registered in Sub-Phase A (`/inquiries`); the `AdminInquiryOversightPage` reuses the same composition.

## Widget tree

```text
Scaffold
├── AppBar
│   ├── leading: DeepLinkAwareBackButton (extracted Phase 15 widget)
│   ├── title: l10n.inquiry_inbox_app_bar_title
│   └── actions: [
│         StatusFilterDropdown (l10n.inquiry_inbox_filter_status_label),
│         ListingFilterDropdown (l10n.inquiry_inbox_filter_listing_label),
│       ]
└── body: RefreshIndicator
        └── BlocBuilder<InquiryInboxBloc, InquiryInboxState>
            ├── InquiryInboxLoading → CircularProgressIndicator
            ├── InquiryInboxError(failure) → ErrorView with retry
            ├── InquiryInboxLoaded(inquiries: [], ...) → empty-state UI (l10n.inquiry_inbox_empty_state)
            └── InquiryInboxLoaded(inquiries: non-empty, hasMore) → ListView.builder
                ├── InquiryRowTile (per inquiry):
                │   ├── InboxStatusBadge(inquiry.status)
                │   ├── Text(inquiry.senderName OR l10n.inquiry_inbox_anonymous_sender_label)
                │   ├── Text(inquiry.decryptedPhone ?? l10n.inquiry_detail_phone_unavailable_placeholder)
                │   ├── Text(inquiry.listingTitle)
                │   ├── InquiryMessageSnippet(inquiry.message)
                │   └── Text(formatted createdAt)
                └── footer: "Load more" trigger (auto-fires when last row in viewport)
```

## BLoC contract

**Events**:

- `InquiryInboxOpened()` — first load.
- `InquiryInboxRefreshRequested()` — pull-to-refresh.
- `InquiryInboxMoreLoaded()` — load next page via cursor.
- `InquiryInboxStatusFilterChanged(InquiryStatus?)` — null = "all".
- `InquiryInboxListingFilterChanged(String?)` — null = "all listings".

**States**:

- `InquiryInboxLoading` — initial / refresh in flight.
- `InquiryInboxLoaded({inquiries, hasMore, statusFilter, listingFilter})`.
- `InquiryInboxError(failure)` — terminal; user retries.

**Use cases injected** (constructor params):

- `LoadInquiryInbox` (Sub-Phase E).

## Pagination

Cursor-based per R-104. Page size 30. The cursor is the last-seen row's `(created_at, id)` pair, encoded by the data source.

## Navigation

Tap on an `InquiryRowTile` → `context.push(AppRoutes.inquiryDetailFor(inquiry.id))`.

## Pre-conditions

- Caller is signed-in.
- Caller has ≥ 0 inquiries on listings they own (zero is the empty-state UI).

## Post-conditions

- On `InquiryInboxLoaded`: the rendered list matches the server-side row set per the three-tier RLS rule (publisher sees only own).
- On row tap: navigation to the detail page succeeds; the detail page handles the auto `new → seen` transition per FR-021.

## Stability surface

**Frozen**: the BLoC's event + state shape, the use case dependency.

**Allowed**: adding more filter dropdowns (e.g., date-range filter), changing the visual treatment of the row tile.
