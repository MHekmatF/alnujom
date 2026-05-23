# Contract: Admin Pending Review Queue Page

**Path**: `lib/features/admin/listing_review/presentation/pages/pending_queue_page.dart`
**Route**: `/admin/listing-review/pending`
**Implements**: FR-009, FR-010, US5
**Verifies**: SC-001 (admin journey timing), SC-010

## Route registration

```dart
GoRoute(
  path: '/admin/listing-review/pending',
  pageBuilder: (ctx, state) => MaterialPage(
    child: const PendingQueuePage(),
  ),
  redirect: (ctx, state) async {
    final user = ctx.read<AuthCubit>().state.user;
    if (user == null) return '/login';
    final checker = ctx.read<PermissionChecker>();
    if (!checker.any(const ['listings.approve', 'listings.reject'])) {
      // Surface localized toast at the destination
      return '/admin?denied=listing_review';
    }
    return null;
  },
),
```

## Page composition

```dart
class PendingQueuePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => getIt<PendingQueueBloc>()..add(PendingQueueLoadFirstPage()),
      child: Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.adminQueueTitle)),
        body: BlocBuilder<PendingQueueBloc, PendingQueueState>(
          builder: (ctx, state) => _QueueBody(state: state),
        ),
      ),
    );
  }
}
```

## Data source contract

```dart
Future<List<PendingListingSummary>> loadPendingQueue({
  PendingQueueCursor? cursor,
  int limit = 20,
}) async {
  // Single PostgREST SELECT with joins to listing_status_history (submitted_at),
  // listing_media (main image), governorates / cities / areas (location names),
  // listing_prices (primary price), profiles (publisher display name).
  //
  // SELECT shape (PostgREST nested resource syntax):
  // listings?status=eq.pending_review
  //   &select=id,title,property_type,purpose,
  //           publisher:profiles!publisher_user_id(full_name),
  //           governorate:governorates(name_ar,name_en),
  //           city:cities(name_ar,name_en),
  //           area:areas(name_ar,name_en),
  //           prices:listing_prices(amount,currency_code,is_primary),
  //           media:listing_media(storage_path,is_main,kind,ordering),
  //           status_history:listing_status_history(changed_at,new_status)
  //   &order=created_at.asc,id.asc
  //   &limit=20
  //
  // Cursor pagination via .gt('created_at', cursor.lastSubmittedAt) + tiebreaker
  // on id. Submission timestamp derived client-side: from status_history rows,
  // take the MIN(changed_at) where new_status='pending_review'.
}
```

> **Decision locked (analysis finding C8 — 2026-05-23)**: The "submitted_at" cursor field uses `listings.created_at`, NOT `listing_status_history.changed_at`. Rationale: (a) `created_at` is indexed by default on the listings table (the existing Phase 10 primary-key + created_at index); (b) deriving from `listing_status_history` requires a per-row aggregate (`MIN(changed_at) WHERE new_status='pending_review'`) that is slower for the cursor predicate; (c) in v1, a listing transitions through `draft → pending_review` exactly once before reaching the admin queue, so `created_at` and the first `submitted_at` differ only by the publisher's draft-editing window — acceptable for oldest-first ordering. **Implementation**: the use case dartdoc + the BLoC's cursor consumer both reference `listings.created_at`. If a future spec adds resubmission ordering precision, this can be revisited.

## Card composition (FR-010)

```text
┌────────────────────────────────────────────────────┐
│ [thumbnail] Title (1-line)                         │
│             • Apartment for sale                   │
│             • Damascus / Mezzeh / Western Mezzeh   │
│             • 150,000 USD                          │
│             by John Doe • 3 hours ago              │
└────────────────────────────────────────────────────┘
```

- Thumbnail: 64×64dp; loads via `cached_network_image` against `supabase.storage.from('listing-images').getPublicUrl(main.storage_path)`. Falls back to a Phase 2 placeholder asset if `main IS NULL`.
- Title: `Theme.of(context).textTheme.titleMedium`, `maxLines: 1`, `overflow: TextOverflow.ellipsis`.
- Chips: property type + purpose using Phase 2's chip token.
- Location: governorate/city/area names joined with " / " (Phase 8 conventions).
- Price: `MoneyFormatter.format(primaryPrice, displayCurrency, locale)` (Phase 9).
- Footer: "by {publisher}" + " • " + time-since-submit (Phase 3 localized formatter).

## Pagination (R-48)

- First page: `LIMIT 20 ORDER BY created_at ASC, id ASC`.
- Subsequent pages: `WHERE (created_at, id) > ($lastCreatedAt, $lastId) LIMIT 20 ORDER BY created_at ASC, id ASC`.
- Pull-to-refresh: re-issue first-page query.
- Empty state: `AppLocalizations.of(context)!.adminQueueEmpty`.

## Tap → navigate

```dart
onTap: () => context.push('/admin/listing-review/preview/${summary.id}');
```
