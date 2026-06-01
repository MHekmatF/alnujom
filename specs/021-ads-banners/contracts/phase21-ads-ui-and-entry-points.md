# Contract: Ads UI & Entry Points

**Phase 21** · Flutter surfaces (PA admin + PS serving). File paths verified against the live tree.

## `AdSlot` widget (`lib/features/ads/presentation/widgets/ad_slot.dart`)
`AdSlot({required AdPlacement placement})` — owns an `AdSlotCubit` that calls `LoadServingAds(placement)`.
- **0 eligible ads** → `SizedBox.shrink()` (collapse, no reflow — FR-012). Uses the Phase 19 PropertyCard optional-widget idiom (`if (x != null) ...[]`).
- **1 eligible ad** → static `ad_banner_card.dart` (no timer, no page indicator).
- **≥2 eligible ads** → `ad_carousel.dart`: `PageView` ordered `priority DESC` + `created_at`/`ad_id` tie-break, auto-advance `Timer` (~5 s) + manual swipe, looping, page indicator (FR-010, R-173).
- **Banner** (`ad_banner_card.dart`): `CachedNetworkImage` from `getPublicUrl(image_path)` + optional locale-matched caption (`Localizations.localeOf` → `captionAr`/`captionEn`); themed via Phase 2 tokens.

## Host-surface insertions (PS)
| Placement | File | Insertion point |
|-----------|------|-----------------|
| `home_top_banner` | `lib/features/home/presentation/pages/home_page.dart` | `SliverToBoxAdapter(child: AdSlot(...))` after `MapEntryTile`, before the "latest listings" header |
| `home_middle_banner` | same | single `SliverToBoxAdapter` after the first feed page/batch (not repeated — R-176) |
| `search_results_banner` | `lib/features/search/presentation/pages/search_page.dart` | item before the result cards (offset the `ListView.builder` index, as the Arabic-hint row does) |
| `listing_details_banner` | `lib/features/listing_details/presentation/pages/listing_details_page.dart` | after `ReporterStatusBanner`, before the title (in the `Column`) |
| `category_banner` | — | NOT host-wired this phase (R-175) |

## Tap-through (PS)
On banner tap: call `RecordAdClick(adId, placement)` (best-effort, non-blocking — FR-017), THEN open the target by `link_kind`:
| link_kind | open |
|-----------|------|
| external | `launchUrl(Uri.parse(link_value), mode: LaunchMode.externalApplication)` |
| listing | `context.push(AppRoutes.listingDetailsFor(link_value))` → `/listings/:id` (link_value = listing UUID) |
| agency | `context.push('/agency/${link_value}')` (link_value = agency UUID) |
| search | `context.push(AppRoutes.search, extra: <text query from link_value>)` (link_value = free-text query; v1 = text only) |
| category | `context.push(AppRoutes.search, extra: <PropertyType parsed from link_value>)` (link_value = property-type key) |

`link_value` encoding per `link_kind` is fixed by **R-179** (external→URL · listing/agency→UUID · category→property-type key ∈ apartment/villa/land/shop/office/farm/warehouse/other · search→free-text query; complex multi-facet filter serialization deferred). Unresolved target (deleted listing, bad URL, no handler) → localized message / safe fallback, no crash (FR-018).

## Admin surface (PA · `lib/features/ads/admin/presentation/`)
- `AdsListPage` — list of ads with derived `AdStatus` chips (active/scheduled/expired/inactive/archived) + an **archived** filter; tap → editor; create FAB; soft-delete + activate/deactivate actions.
- `AdEditorPage` — title; image pick+upload; optional **ar + en caption** (both-or-neither); `link_target_picker` (external URL | listing | search | category | agency) → `link_kind`+`link_value`; `schedule_picker` (start/end, enforces `start < end`); placement multi-select with per-placement priority (`category_banner` flagged "not yet live" — R-175); active toggle.
- `AdsAdminCubit` drives `CreateAd`/`UpdateAd`/`SetAdActive`/`ArchiveAd`/`LoadAds`/`UploadAdImage`.

## Route + guard (PA)
- `app_router.dart`: `AppRoutes.adminAds = '/admin/ads'`, `AppRouteNames.adminAds = 'admin-ads'`, and a `GoRoute(path:'ads', name: AppRouteNames.adminAds, redirect: requireAdsManageRedirect, builder: (_, __) => const AdsListPage())` under the `/admin` parent.
- `auth_redirect.dart`: `requireAdsManageRedirect` — `if (!getIt<PermissionChecker>().has(PermissionKeys.adsManage)) return '/admin?denied=ads';` (mirrors `requireAuditLogsViewRedirect`).

## Dashboard tile flip (PA)
`lib/features/admin/dashboard/presentation/widgets/dashboard_sections.dart` — the existing Ads entry:
```dart
DashboardSection(
  labelKey: 'dashboardTileAds',
  permissionKeys: [PermissionKeys.adsManage],
  state: DashboardSectionState.comingSoon,   // ← change to enabled
  icon: Icons.campaign_outlined,
)
```
becomes `state: DashboardSectionState.enabled, route: AppRoutes.adminAds` (drop the `comingSoon`). No other dashboard change.

## Localization (PA + PS)
~45 keys in both `app_ar.arb` + `app_en.arb`, namespaced (`adsAdmin*`, `adSlot*`, `adStatus*`, `adPlacement*`, `adLink*`): admin titles/labels/actions, placement names, link-type labels, schedule labels, status chips, list/empty/error states, the `category_banner` "not yet live" note, and AdSlot fallback messages. Ad **captions** are admin-authored content (NOT keys). l10n-parity linter MUST pass (memory `project_wave_run_full_verify_suite`).
