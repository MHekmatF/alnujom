# Phase 13 — Data Model

**Scope**: Phase 13 is a read-side phase. Zero new database tables, columns, RLS policies, or schema constraints. The only backend artifact is one index migration. The data model below documents:

1. The one new migration's exact SQL body.
2. The home-feed SELECT projection shape + Dart entity / DTO shape.
3. The listing-details SELECT projection shape + Dart entity / DTO shape.
4. The two new domain entities (`HomeListingCard`, `Cursor`) + the aggregate (`ListingDetailsAggregate`).
5. The new `ListingNotFoundFailure` type.
6. The ARB key inventory (full bilingual `ar` + `en` listing).
7. The per-FR + per-SC verification map.

---

## 1. Phase 13 migration body (FULL SQL)

### `supabase/migrations/20260524120001_create_listings_indexes.sql`

```sql
-- Phase 13 — Index migration. Per FR-001 + R-61.
-- Four composite indexes on public.listings supporting the home-feed read
-- pattern + the publisher/admin read patterns + two facet-prep patterns
-- forward-stated for Phase 14.
-- Idempotent via IF NOT EXISTS.

-- (1) Home-feed read pattern (Phase 13 FR-015): ORDER BY published_at DESC, id DESC
--     under the WHERE status='approved' filter applied by RLS.
CREATE INDEX IF NOT EXISTS idx_listings_status_published_at
  ON public.listings (status, published_at DESC, id DESC);

-- (2) Publisher / admin read pattern (Phase 10's MyListingsPage, Phase 12's queue):
--     ORDER BY created_at DESC, id DESC under WHERE status IN (...). Also aligns
--     with the IMPLEMENTATION_PLAN's literal "(status, created_at DESC)" text.
CREATE INDEX IF NOT EXISTS idx_listings_status_created_at
  ON public.listings (status, created_at DESC, id DESC);

-- (3) Forward-stated Phase 14 governorate-filter pattern (Phase 13 Q1=A leaves
--     governorate-shortcut UX unwired but the index is cheap to ship now).
CREATE INDEX IF NOT EXISTS idx_listings_governorate_status
  ON public.listings (governorate_id, status);

-- (4) Property-type-shortcut filter pattern (Phase 13 Q1=A stub + Phase 14 wire).
CREATE INDEX IF NOT EXISTS idx_listings_property_type_status
  ON public.listings (property_type, status);
```

**Apply**: via Supabase MCP `apply_migration` with name `create_listings_indexes`.

**Verify** (per FR-002 + SC-009):

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM public.listings
WHERE status='approved'
ORDER BY published_at DESC, id DESC
LIMIT 20;
```

Expected output contains `Index Scan using idx_listings_status_published_at` (NOT `Seq Scan`) at any row count ≥ 100. At < 100 rows Postgres MAY choose Seq Scan for cost reasons; soft requirement below the threshold.

---

## 2. Home-feed SELECT projection + Dart shapes

### 2.1 Supabase client query (per R-63)

```dart
Future<List<HomeListingCardDto>> fetchPage(Cursor? cursor) async {
  var query = _client.from('listings').select('''
    id, title, property_type, purpose, governorate_id, city_id, published_at,
    listing_prices!inner(currency_code, amount, is_primary),
    listing_media(storage_path, ordering, is_main, kind),
    governorate:governorates(name_ar, name_en),
    city:cities(name_ar, name_en)
  ''');
  // RLS-only filter — NO application-layer status='approved' per FR-018.
  query = query
      .eq('listing_prices.is_primary', true)
      .eq('listing_media.is_main', true)
      .eq('listing_media.kind', 'image');
  if (cursor != null) {
    // Per R-62 (corrected): single .or() filter expressing the lexicographic
    // strict-less-than tuple compare on (published_at, id). Equivalent to
    //   WHERE (published_at < X) OR (published_at = X AND id < Y)
    // This is the ONLY predicate that produces no-duplicate AND no-skip
    // pagination under tied `published_at` values. Do NOT replace with two
    // chained `.lt()` filters — that broke US5 in the earlier draft.
    final pubAt = cursor.publishedAt.toIso8601String();
    query = query.or(
      'published_at.lt.$pubAt,'
      'and(published_at.eq.$pubAt,id.lt.${cursor.id})',
    );
  }
  final rows = await query
      .order('published_at', ascending: false)
      .order('id', ascending: false)
      .limit(20);
  return rows.map((r) => HomeListingCardDto.fromJson(r)).toList();
}
```

### 2.2 Dart DTO at `lib/features/home/data/dtos/home_listing_card_dto.dart`

```dart
class HomeListingCardDto {
  final String id;
  final String title;
  final String propertyType;   // enum string from §6.3
  final String purpose;        // enum string from §6.3
  final String governorateId;
  final String cityId;
  final DateTime publishedAt;
  final _PriceDto primaryPrice;
  final _MediaDto? mainImage;  // nullable per Phase 11 FR-022 zero-image guard
  final _LocationNameDto governorate;
  final _LocationNameDto city;

  factory HomeListingCardDto.fromJson(Map<String, dynamic> json) { /* ... */ }
}

class _PriceDto { final String currencyCode; final num amount; }
class _MediaDto { final String storagePath; final int ordering; }
class _LocationNameDto { final String nameAr; final String nameEn; }
```

### 2.3 Dart entity at `lib/features/home/domain/entities/home_listing_card.dart`

```dart
import 'package:equatable/equatable.dart';

class HomeListingCard extends Equatable {
  final String id;
  final String title;
  final PropertyType propertyType;  // Phase 10 enum
  final ListingPurpose purpose;     // Phase 10 enum
  final String governorateNameLocalized; // resolved at DTO→entity time per locale
  final String cityNameLocalized;
  final ListingPrice primaryPrice;  // Phase 10 entity
  final String? mainImageStoragePath; // null on zero-image defensive case
  final DateTime publishedAt;

  const HomeListingCard({/* ... */});

  @override
  List<Object?> get props => [id, title, propertyType, purpose,
    governorateNameLocalized, cityNameLocalized, primaryPrice,
    mainImageStoragePath, publishedAt];
}
```

### 2.4 Cursor value object at `lib/features/home/domain/entities/cursor.dart`

```dart
import 'package:equatable/equatable.dart';

class Cursor extends Equatable {
  final DateTime publishedAt;
  final String id;
  const Cursor({required this.publishedAt, required this.id});

  Cursor.fromLastCard(HomeListingCard last)
    : publishedAt = last.publishedAt, id = last.id;

  @override
  List<Object?> get props => [publishedAt, id];
}
```

---

## 3. Listing-details SELECT projection + Dart shapes

### 3.1 Supabase client query (per R-64)

```dart
Future<ListingDetailsAggregateDto?> fetchListing(String listingId) async {
  final row = await _client.from('listings').select('''
    id, title, property_type, purpose, governorate_id, city_id, area_id,
    phone, whatsapp, contact_name_visibility, location_visibility,
    area_size, rooms, bathrooms, floor, published_at,
    listing_details(description, amenities, year_built, furnished, parking),
    listing_prices(currency_code, amount, is_primary, created_at),
    listing_media(id, storage_path, ordering, is_main, kind, external_url),
    governorate:governorates(name_ar, name_en),
    city:cities(name_ar, name_en),
    area:areas(name_ar, name_en),
    publisher:profiles!listings_publisher_user_id_fkey(full_name, username)
  ''').eq('id', listingId).maybeSingle();
  // RLS-only filter — NO application-layer status='approved' per FR-018.
  // .maybeSingle() returns null when RLS hides the row OR row doesn't exist.
  if (row == null) return null;
  return ListingDetailsAggregateDto.fromJson(row);
}
```

### 3.2 Dart aggregate entity at `lib/features/listing_details/domain/entities/listing_details_aggregate.dart`

```dart
import 'package:equatable/equatable.dart';

class ListingDetailsAggregate extends Equatable {
  final Listing listing;                    // Phase 10 entity
  final ListingDetails details;             // Phase 10 entity
  final List<ListingPrice> prices;          // Phase 10 entity list
  final List<ListingMedia> media;           // Phase 11 entity list (ordered by ordering ASC, is_main first)
  final Governorate governorate;            // Phase 8 entity
  final City city;                          // Phase 8 entity
  final Area area;                          // Phase 8 entity
  final PublisherSummary publisher;         // Phase 5-compatible summary

  const ListingDetailsAggregate({/* ... */});

  @override
  List<Object?> get props => [listing, details, prices, media,
    governorate, city, area, publisher];
}

class PublisherSummary extends Equatable {
  final String fullName;
  final String? username;
  const PublisherSummary({required this.fullName, this.username});

  @override
  List<Object?> get props => [fullName, username];
}
```

---

## 4. `ListingNotFoundFailure` + extended `failure.dart`

### 4.1 Phase 13 addition to `lib/core/errors/failure.dart`

```dart
// (existing Phase 1 + Phase 12 Failure subtypes preserved)

// Phase 13 — emitted when ListingDetailsBloc's data source returns null from
// .maybeSingle() (either RLS hides the row OR row doesn't exist; the two
// cases are indistinguishable per Constitution III + FR-024).
class ListingNotFoundFailure extends Failure {
  const ListingNotFoundFailure();
}
```

Per R-68 — if a generic `NotFoundFailure` already exists from Phase 5+ inspection at implementation time, reuse it instead and skip the new subtype.

---

## 5. ARB key inventory (FULL bilingual ar + en)

Per FR-028. The Phase 13 ARB delta adds ~25 keys. Format below: `key | ar | en | usage`.

### 5.1 HomePage chrome (6 keys)

| Key | Arabic | English | Used in |
|---|---|---|---|
| `home_app_bar_title` | النجوم العقارية | AlNujom Real Estate | HomePage AppBar title (may reuse existing Phase 1 / 3 key — plan-time inspection) |
| `home_sign_in_icon_tooltip` | تسجيل الدخول | Sign in | HomePage AppBar sign-in icon tooltip |
| `home_search_bar_placeholder` | ابحث عن عقار... | Search for property... | _HeroSearchBar placeholder text |
| `home_latest_listings_header` | أحدث الإعلانات | Latest listings | HomePage section header |
| `home_no_listings_yet` | لا توجد إعلانات بعد — كن أول من ينشر! | No listings yet — be the first to publish! | Empty-state message |
| `home_no_more_listings` | لا توجد إعلانات أخرى | No more listings | Infinite-scroll sentinel |

### 5.2 Q1=A snackbar keys (2 keys, per Sub-Phase C)

| Key | Arabic | English | Used in |
|---|---|---|---|
| `home_search_coming_soon` | البحث قريباً — تصفح أحدث الإعلانات أدناه | Search is coming soon — for now, browse the latest listings below | _HeroSearchBar tap snackbar |
| `home_property_shortcut_coming_soon` | فلتر إعلانات {type} قريباً — تصفح كامل الإعلانات أدناه | {type} listings filter is coming soon — browse the full feed below | _PropertyTypeShortcutRow chip tap snackbar (parameterized over the tapped type's localized label) |

### 5.3 Q2=A snackbar keys (6 keys)

| Key | Arabic | English | Used in |
|---|---|---|---|
| `contact_call_coming_soon` | الاتصال المباشر قريباً — تابعنا للحصول على هذه الميزة | Calling is coming soon — stay tuned for this feature | _ContactBlock Call CTA tap |
| `contact_whatsapp_coming_soon` | واتساب قريباً — تابعنا للحصول على هذه الميزة | WhatsApp is coming soon — stay tuned | _ContactBlock WhatsApp CTA tap |
| `contact_inquiry_coming_soon` | إرسال استفسار قريباً — تابعنا للحصول على هذه الميزة | Sending inquiries is coming soon — stay tuned | _ContactBlock Send-inquiry CTA tap |
| `action_favorite_coming_soon` | المفضلة قريباً — تابعنا للحصول على هذه الميزة | Favorites is coming soon — stay tuned | _PerListingActionBlock Favorite CTA tap |
| `action_share_coming_soon` | المشاركة قريباً — تابعنا للحصول على هذه الميزة | Sharing is coming soon — stay tuned | _PerListingActionBlock Share CTA tap |
| `action_report_coming_soon` | الإبلاغ قريباً — تابعنا للحصول على هذه الميزة | Reporting is coming soon — stay tuned | _PerListingActionBlock Report CTA tap |

### 5.4 Q3=A reserved forward-state keys (2 keys, per spec FR-028)

| Key | Arabic | English | Used in |
|---|---|---|---|
| `auth_required_please_sign_in` | يرجى تسجيل الدخول لاستخدام هذه الميزة | Please sign in to use this feature | Reserved for future-phase auth-required CTA wiring; Phase 13 does not surface this key but adds it now per FR-028 forward-state convention |
| `auth_required_sign_in_action` | تسجيل الدخول | Sign in | Reserved snackbar action button label paired with the above |

### 5.5 ListingDetailsPage chrome (3 keys)

| Key | Arabic | English | Used in |
|---|---|---|---|
| `listing_details_not_found_title` | الإعلان غير موجود | Listing not found | FR-024 not-found state |
| `listing_details_not_found_return_home` | العودة إلى الصفحة الرئيسية | Return to home | FR-024 CTA |
| `listing_details_publisher_label` | بواسطة {name} | by {name} | Publisher attribution (parameterized over `publisher.fullName`) |

### 5.6 CTA labels (6 keys — the snackbars are FR-021's tap behavior; the visible labels on the buttons themselves are localized chrome)

| Key | Arabic | English | Used in |
|---|---|---|---|
| `cta_call` | اتصال | Call | _ContactBlock Call button label |
| `cta_whatsapp` | واتساب | WhatsApp | _ContactBlock WhatsApp button label |
| `cta_send_inquiry` | إرسال استفسار | Send inquiry | _ContactBlock Send-inquiry button label |
| `cta_favorite` | إضافة للمفضلة | Favorite | _PerListingActionBlock Favorite button label |
| `cta_share` | مشاركة | Share | _PerListingActionBlock Share button label |
| `cta_report` | إبلاغ | Report | _PerListingActionBlock Report button label |

### 5.7 Error states (4 keys)

| Key | Arabic | English | Used in |
|---|---|---|---|
| `error_could_not_load_listings` | تعذّر تحميل الإعلانات | Could not load listings | HomePage error state |
| `error_could_not_load_listing` | تعذّر تحميل الإعلان | Could not load listing | ListingDetailsPage error state |
| `action_retry` | إعادة المحاولة | Retry | Both error states' Retry button (may reuse existing Phase 7 / earlier key — plan-time inspection) |
| `image_unavailable` | الصورة غير متاحة | Image unavailable | Gallery image-error fallback (may reuse Phase 12 Q8=A widget key — plan-time inspection) |

### 5.8 Empty-state CTAs (2 keys — auth-state-branched)

| Key | Arabic | English | Used in |
|---|---|---|---|
| `home_empty_publish_first_listing` | انشر إعلانك الأول | Publish your first listing | Empty-state CTA for authenticated publisher |
| `home_empty_sign_in_to_publish` | سجّل الدخول للنشر | Sign in to publish | Empty-state CTA for anonymous visitor |

**Total new ARB keys**: ~28 actually-new keys (the §5.1–§5.8 tables inventory 31 entries, of which ~3 are flagged "may reuse existing" via Phase 1/3/7/12 — `home_app_bar_title`, `action_retry`, `image_unavailable`). Grep `lib/l10n/app_en.arb` at implementation time to confirm which are reused vs newly-added. The Phase 11 DEFERRED.md note on `app_strings.dart` requires the hand-maintained `_DebugAppLocalizations` subclass to gain a concrete getter implementation for every NEW key (i.e., for every key not reused from an earlier phase) matching the auto-generated abstract members from `flutter gen-l10n`.

---

## 6. Per-FR + per-SC verification map

The following table cross-references every Functional Requirement AND every Success Criterion to the artifact (migration / file / quickstart step) that satisfies it.

| FR / SC | Artifact | Verification |
|---|---|---|
| FR-001 | `supabase/migrations/20260524120001_create_listings_indexes.sql` | Migration applies via Supabase MCP `apply_migration`. |
| FR-002 | EXPLAIN check in quickstart | `EXPLAIN ... LIMIT 20` shows `Index Scan using idx_listings_status_published_at`. |
| FR-003 | grep on migration | `grep -E "CREATE POLICY\|ALTER POLICY\|DROP POLICY" supabase/migrations/20260524120001_*` returns 0 matches. |
| FR-004 | grep on migration | `grep -E "ALTER TABLE\|CREATE TABLE\|DROP TABLE" supabase/migrations/20260524120001_*` returns 0 matches. |
| FR-005 | `ls supabase/functions/` | Returns exactly the 4 existing functions (Phase 5's 2 + Phase 12's 2); no new Phase 13 function. |
| FR-006 | grep on migration | `grep -E "INSERT INTO public.permissions" supabase/migrations/20260524120001_*` returns 0 matches. |
| FR-007 | grep on Phase 13 code | `grep -R "log_audit" supabase/migrations/20260524120001_* supabase/functions/` returns 0 matches. |
| FR-008 | `lib/core/routing/app_router.dart` | `/` builder is `const HomePage()`. |
| FR-009 | `ls lib/shell/` | Returns "no such directory". |
| FR-010 | `lib/core/routing/app_router.dart` | `/listings/:id` route is defined. |
| FR-011 | `lib/features/listing_details/presentation/pages/listing_details_page.dart` | Page renders "Listing not found" when BLoC `LoadListing` returns Failure. |
| FR-012 | `ls lib/features/home/{data,domain,presentation}/` | 3 subdirs exist. |
| FR-013 | `lib/features/home/presentation/pages/home_page.dart` | Composes AppBar + hero search + property-type row + section header + paginated feed. Q1=A snackbar wiring verified at quickstart UI walk. |
| FR-014 | `lib/features/home/presentation/bloc/home_bloc.dart` | Exposes the 3 events + the state. |
| FR-015 | `lib/features/home/data/datasources/supabase_home_feed_datasource.dart` | `fetchPage` issues the SELECT per R-63. |
| FR-016 | `lib/features/home/presentation/pages/home_page.dart` | `RefreshIndicator` wraps the feed; `ScrollController` listener fires the next-page event. Q5=A latency verified at quickstart UI walk. |
| FR-017 | `lib/features/home/presentation/widgets/home_listing_card.dart` | Card composes main image + title + badges + location + price + time-since-publish. Tap routes to `/listings/:id`. |
| FR-018 | grep on `lib/features/home/data/` | `grep -RE "\.eq\('status'" lib/features/home/data/` returns 0 matches. |
| FR-019 | HomePage empty-state | Renders the localized "No listings yet" + CTA per auth state. |
| FR-020 | `ls lib/features/listing_details/{data,domain,presentation}/` | 3 subdirs exist. |
| FR-021 | `lib/features/listing_details/presentation/pages/listing_details_page.dart` | Composes Q8=A widgets in prescribed order + Contact block + per-listing-action block. Q4=D back-arrow conditional wiring verified at quickstart UI walk. Q2=A snackbar wiring verified at quickstart UI walk. |
| FR-022 | `lib/features/listing_details/presentation/bloc/listing_details_bloc.dart` | Exposes the 3 events + the state; independent of Phase 12's ListingPreviewBloc per SC-016 |
| FR-023 | `lib/features/listing_details/data/datasources/supabase_listing_details_datasource.dart` | `fetchListing` issues the SELECT per R-64. |
| FR-024 | UI page render | Renders localized "Listing not found" on RLS-hidden OR non-existent UUID. |
| FR-025 | UI page render | Renders localized "Could not load listing" + Retry on network failure. |
| FR-026 | `git diff` against `lib/shared/presentation/widgets/listing_display/` | 0 changes (per SC-016). |
| FR-027 | `lib/features/listing_details/presentation/pages/listing_details_page.dart` | Video-tap callback calls `url_launcher.launchUrl(...)`. Verified at quickstart UI walk on Infinix Note 8 with VLC. |
| FR-028 | `lib/l10n/app_ar.arb` + `lib/l10n/app_en.arb` | ~25 new keys present per inventory above. |
| FR-029 | grep on Phase 13 widget files | `grep -RE "Color\(0xFF\|EdgeInsets\.only\(left" lib/features/home/presentation/ lib/features/listing_details/presentation/` returns 0 matches. |
| FR-030 | grep on Phase 13 presentation+domain | `grep -R "package:supabase_flutter" lib/features/home/presentation/ lib/features/home/domain/ lib/features/listing_details/presentation/ lib/features/listing_details/domain/` returns 0 matches. |
| FR-031 | Inspection | `cached_network_image` actively consumed by the Q8=A `ListingGallery` widget at public-surface (first time). |
| FR-032 | `pubspec.yaml` | `url_launcher: ^6.x` present. |
| FR-033 | grep on `pubspec.yaml` | `grep "share_plus" pubspec.yaml` returns 0 matches. |
| FR-034 | Inspection | No shimmer plugin added; either Phase 2's existing surface is sufficient OR the per-image `cached_network_image` placeholder is used. |
| FR-035 | grep on Phase 13 widget files | `grep -RE "Text\('[^\$]" lib/features/home/presentation/ lib/features/listing_details/presentation/` returns 0 matches outside legitimate placeholders. |
| **SC** | | |
| SC-001 | Quickstart cold-launch stopwatch | ≤ 3 sec on Infinix Note 8. |
| SC-002 | Quickstart infinite-scroll | 50 seeded listings; no duplicates / skips. |
| SC-003 | Quickstart two-device pull-to-refresh | Newly-approved listing appears at position 0. |
| SC-004 | Quickstart card-tap stopwatch | ≤ 1 sec on Infinix Note 8. |
| SC-005 | Quickstart gallery swipe + video tap | Gallery advances; OS external player launches. |
| SC-006 | Quickstart deep-link to non-approved UUID | Page shows "Listing not found". |
| SC-007 | Quickstart deep-link to random UUID | Page shows "Listing not found" (indistinguishable). |
| SC-008 | grep | `grep -RE "\.eq\('status'" lib/features/home/data/ lib/features/listing_details/data/` returns 0. |
| SC-009 | EXPLAIN | Output contains `Index Scan using idx_listings_status_published_at`. |
| SC-010 | `git diff --stat` + `ls lib/shell/` | File deletion present; directory absent. |
| SC-011 | Inspection of `app_router.dart` | `/` builder is `const HomePage()`. |
| SC-012 | Inspection of `app_router.dart` | `/listings/:id` route is defined. |
| SC-013 | grep | `grep -R "package:supabase_flutter" lib/features/home/presentation/ lib/features/home/domain/ lib/features/listing_details/presentation/ lib/features/listing_details/domain/` returns 0. |
| SC-014 | Phase 3 lint guard at PR review | 0 hardcoded user-facing strings flagged. |
| SC-015 | grep | `grep -RE "Color\(0xFF\|EdgeInsets\.only\(left\|SizedBox\(width:[1-9]" lib/features/home/presentation/ lib/features/listing_details/presentation/` returns 0. |
| SC-016 | `git diff` against `lib/shared/presentation/widgets/listing_display/` | 0 changes. Also: inspection of `ListingDetailsBloc` shows no shared BLoC import with Phase 12. |
| SC-017 | grep | `grep -R "INSERT INTO public.permissions" supabase/migrations/20260524*` returns 0. |
| SC-018 | grep | `grep -RE "CREATE POLICY\|ALTER POLICY\|DROP POLICY" supabase/migrations/20260524*` returns 0. |
| SC-019 | grep | `grep -RE "ALTER TABLE\|CREATE TABLE\|DROP TABLE" supabase/migrations/20260524*` returns 0 matches that target listings-domain tables. |
| SC-020 | `ls supabase/functions/` | Returns 4 functions (Phase 5's 2 + Phase 12's 2). |
| SC-021 | grep | `grep -R "log_audit" supabase/migrations/20260524* supabase/functions/` returns 0 NEW matches. |
| SC-022 | Quickstart infinite-scroll | Same as SC-002. |
| SC-023 | Quickstart two-device concurrent approve | Newly-approved listing absent from mid-session pagination; present after pull-to-refresh. |
| SC-024 | Quickstart 4-combination visual check | Light/dark × ar/en on both devices renders without defects. |
| SC-025 | Quickstart anonymous walk | No "please sign in" wall encountered while browsing. |
| SC-026 | Quickstart signed-in walk | Publisher's own draft/pending/rejected listings absent from home feed. |
| SC-027 | Quickstart video-tap | OS external player launches on Infinix Note 8 (VLC) + Pixel 8 Pro emulator (Chrome). |
| SC-028 | Inspection | `cached_network_image` actively consumed at public surface. |
| SC-029 | Quickstart Q1=A snackbar test | Search bar + each property-type chip taps surface the localized Coming-soon snackbar; no navigation. |
| SC-030 | Quickstart Q2=A snackbar test | All 6 CTAs tap to their localized snackbars; no functional behavior. Also: grep for `tel:` / `wa.me` / `share_plus` returns 0. |
| SC-031 | Inspection | Phase 13 has no auth-required CTA wired; Q3=A keys are present in ARB delta for future-phase consumers. |
| SC-032 | Combined SC-010 + SC-011 | Both pass. |
| SC-033 | Quickstart deep-link back-button test | `adb shell am start` deep-link → page renders → back arrow routes to HomePage (not exits app). |
| SC-034 | Quickstart stopwatch | ≤ 2 sec p95 over 10 infinite-scroll + 10 pull-to-refresh on Infinix Note 8. |
| SC-035 | Quickstart background-resume test | 1-minute + 30-minute backgrounds preserve scroll position + cards; no auto-refresh; pull-to-refresh works. |
