# Contract: Home-Feed Query

**Path**: `lib/features/home/data/datasources/supabase_home_feed_datasource.dart`
**Implements**: FR-015, FR-016, FR-017, FR-018
**Verifies**: SC-002, SC-003, SC-008, SC-022, SC-023

## Query

```dart
Future<List<HomeListingCardDto>> fetchPage(Cursor? cursor) async {
  var query = _client.from('listings').select('''
    id, title, property_type, purpose, governorate_id, city_id, published_at,
    listing_prices!inner(currency_code, amount, is_primary),
    listing_media(storage_path, ordering, is_main, kind),
    governorate:governorates(name_ar, name_en),
    city:cities(name_ar, name_en)
  ''');

  // Filter on embedded selects (PostgREST does NOT take a status='approved' filter — RLS is the sole gate per FR-018).
  query = query
      .eq('listing_prices.is_primary', true)
      .eq('listing_media.is_main', true)
      .eq('listing_media.kind', 'image');

  // Cursor predicate per R-62. Two separate lt filters.
  if (cursor != null) {
    query = query
        .lt('published_at', cursor.publishedAt.toIso8601String())
        .lt('id', cursor.id);
  }

  final rows = await query
      .order('published_at', ascending: false)
      .order('id', ascending: false)
      .limit(20);

  return (rows as List).map((r) => HomeListingCardDto.fromJson(r as Map<String, dynamic>)).toList();
}
```

## RLS-only filter discipline

The query MUST NOT include `.eq('status', 'approved')` — Phase 10's public-read RLS policy is the sole gate per Constitution III + FR-018. Plan-time grep enforces:

```bash
grep -RE "\.eq\('status'" lib/features/home/data/
# Expected: 0 matches.
```

## Cursor pagination semantics

- **First page**: `cursor == null` → returns the 20 most-recently-published `approved` listings ordered by `(published_at DESC, id DESC)`.
- **Next page**: `cursor == Cursor.fromLastCard(state.listings.last)` → returns the next 20 strictly LESS than the cursor's (published_at, id) tuple.
- **End of list**: server returns < 20 rows → BLoC emits `noMoreListings` sentinel.
- **Pull-to-refresh**: BLoC discards the cursor + re-issues `fetchPage(null)` → replaces the feed.

## Concurrent-write correctness (per spec US5)

A Phase 12 approval mid-session sets the new listing's `published_at = now()`, which is GREATER than every cursor the user has loaded. The strict `<` predicate on `published_at` skips the new row from the next page; the user must pull-to-refresh to see it. The cursor itself (last loaded row's `published_at, id`) is preserved correctly — no duplicate / skip of previously-loaded rows.

## Empty-state mapping

When `fetchPage(null)` returns `[]`, the BLoC emits `HomeFeedStatus.success` with `listings: []` AND the HomePage renders the FR-019 empty-state.

## Network failure mapping

`PostgrestException` OR `SocketException` is caught in the data source, mapped to a `NetworkFailure` (Phase 1 type), and propagated up to `HomeBloc` which emits `HomeFeedStatus.error`. The HomePage renders the FR-014 "Could not load listings" error state with a Retry button.
