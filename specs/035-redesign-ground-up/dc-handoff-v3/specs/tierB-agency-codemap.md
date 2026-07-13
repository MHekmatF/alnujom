I now have a complete picture. Here is the mapping.

---

# Tier B (Agency) — Claude-Design → Flutter code map

Scope note: the current agency feature is a **6-page** cluster (`lib/features/agency/presentation/pages/`) — a hub (`agency_home_page.dart`) linking to 5 pushed pages. The DC spec collapses these into **two tabbed screens**: Screen A (public **Profile**, 4 tabs) and Screen B (owner **Manage**, 4 tabs). All existing pages use plain `Scaffold` + `AppBar` (Material 3), **none** use the DC crown yet. Every page's bloc/usecase/repository wiring is reusable as-is — this is a pure presentation rebuild.

Shared reusable widgets confirmed present: `DcCrownScaffold` + `DcCrownIconButton` (`lib/core/widgets/dc_crown_scaffold.dart`), `CrownUnderlineTabs` (`crown_underline_tabs.dart`), `DsListingCard` (`ds/ds_listing_card.dart`), `AppButton` with `whatsapp`/`tonal`/`outlined` variants (`app_button.dart`), `TokenBarChart` (`charts/token_bar_chart.dart`), `TokenHbarList` (`charts/token_hbar_list.dart`), `RatingStars` (`rating_stars.dart`), `StatCard` (`stat_card.dart`), `StatusPill` (`status_pill.dart`), `EmptyState`/`ErrorState`/`LoadingState` (`empty_state.dart`, `error_state.dart`, `loading_state.dart`), `MapPreview` (`map_preview.dart`), `AgencyMemberTile` (`agency/.../widgets/agency_member_tile.dart`).

---

## SCREEN A — Agency Profile (public, `screen:'profile'`, 4 tabs)

**Existing file:** `H:\alnujom-project\lib\features\agency\presentation\pages\agency_profile_page.dart`
**Current root:** `Scaffold` + `AppBar(title)` + a single flat `ListView` (logo row + description + contact rows + a hand-rolled listings column via `AgencyVerificationCubit` as loader + `AgencyListingsBloc`). No tabs, no reviews, no members, no about, no ratings.

**Route:** `path: '/agency/:id'`, name `agency-profile` (`app_router.dart:780`, `AppRoutes.agencyProfile` = `/agency/:id`). Public — no auth redirect (approved-only enforced server-side). **Reached from:** `agency_badge.dart:66` (`context.push('/agency/$agencyId')`), the owner hub's "view public profile" button (`agency_home_page.dart:343`), and ad slots (`ad_slot.dart:125`).

**Ordered edits to reach the DC look:**
1. Replace `Scaffold`/`AppBar` with a **new `DcAgencyProfileHeader`** (sticky rich crown) hosting a `CustomScrollView` — the whole screen is one scroller; the crown is `position:sticky` and the white sheet is `radius 20 20 0 0`, `margin-top −14`. Do **not** use `DcCrownScaffold` (that crown is fixed, not collapsing). Use a pinned `SliverPersistentHeader` (or `NestedScrollView`) carrying: avatar tile (66, `radius 18`, `storefront`), name + `verified`, rating/listings meta, "عضو منذ …" line, Call/WhatsApp/Follow CTA row, then `CrownUnderlineTabs(labels: [العقارات, نبذة, الأعضاء, التقييمات], fontSize: 14)`.
2. Crown back/share/flag buttons: add a **transparent variant of `DcCrownIconButton`** (current widget is a 42px white-*filled* circle; DC wants 40px transparent white-icon) — add a `filled: false` flag or a `transparent` bool.
3. Tab **العقارات (A1):** replace the hand-rolled `_ListingRow`/`_ListingsColumn` with `DsListingCard` (already DC-matched — verified stamp, heart, specs, price via `MoneyFormatter`). Insert a **new mapper** `Map<String,dynamic> → DsListingCardData` for `AgencyListingsBloc` rows (mirror `lib/features/home/presentation/widgets/home_card_mapper.dart`).
4. Tab **نبذة (A2):** new column — bio block, coverage chips (new `DcAddChip`-less read-only pills, `selected`/`onSelected` tokens), specialties chips (`surface2` tokens), a **new `DcContactInfoCard`** (bordered grouped rows with dividers; the current inline `_ContactRow` becomes a row inside it), and a **new `DcMapPlaceholder`** (adapt `MapPreview` — swap `primaryContainer` bg for `surface2` + grid lines + `location_on`, fixed height 130).
5. Tab **الأعضاء (A3):** new list of **`DcMemberRow` (chat variant)** — reuse the `AgencyMembersBloc` roster; this is a restyle of `agency_member_tile.dart` (46px avatar, `role · N إعلاناً` sub, trailing 34px chat button instead of the current `more_vert` popup).
6. Tab **التقييمات (A4):** new **`DcRatingSummaryCard`** + **`DcRatingBar`** (distribution) + write-review `AppButton.outlined` + a list of **`DcReviewCard`**. The `reviews` feature exists (`lib/features/reviews/`) but is **seller/publisher-scoped, not agency-scoped** (`seller_trust_cubit.dart`, `seller_reviews_section.dart`, `write_review_sheet.dart`) — reuse its widgets/patterns but new agency-review wiring/data is required.

**Data gaps (blocks pixel-parity, not the layout):** `Agency` entity (`domain/entities/agency.dart`) has **no** rating, review count, listing count, member count, "member since"/`createdAt` display, coverage areas, specialties, or business hours. These render as placeholders/hidden until backend fields land. Flag to founder.

**Effort: LARGE** (new sticky-header shell + 4 rebuilt tabs + 5–6 new shared widgets + a new agency-reviews data path).

---

## SCREEN B — Agency Management (owner, `screen:'manage'`, 4 tabs)

The DC "Manage" screen consolidates today's hub + 4 pushed pages into **one** `DcCrownScaffold` (flat body) with `CrownUnderlineTabs`. Recommended approach: **build a new tabbed host** (`agency_manage_page.dart`) at route `/agency` that owns a `TabController` and embeds the four tab bodies, each reusing its existing bloc. Keep the standalone routes as deep-link entry points but have them land on the host with the right tab preselected (or keep them; they share the same blocs).

**Route / entry:** `path: '/agency'`, name `agency` (`app_router.dart:714`), auth-required. **Reached from:** nav drawer (`app_nav_drawer.dart:138`) and notification deep-link resolver (`notification_deep_link_resolver.dart:144`).

**Host file today:** `H:\alnujom-project\lib\features\agency\presentation\pages\agency_home_page.dart` — `Scaffold`+`AppBar`, `BlocConsumer<AgencyHomeCubit>` switching None(create form) / Invited / Owner / Member (`_ManagementSurface` = list of `_ManageTile` links). 
**Edits:** turn `_ManagementSurface` (owner/member branch) into a `DcCrownScaffold(title: "إدارة الوكالة", sheet: false /* flat body, bg=surface */, crownBottom: CrownUnderlineTabs([تعديل الملف, الأعضاء والأدوار, التحليلات, التوثيق], fontSize: 14))`. Keep the None(create)/Invited branches as their own simpler crown screens. Back button uses the transparent `DcCrownIconButton`.

### B1 · تعديل الملف (`mTabEdit`)
**Existing file:** `lib\features\agency\presentation\pages\agency_edit_profile_page.dart` — `Scaffold`+`AppBar`, `SingleChildScrollView` of `AppTextField`s + `_LogoPicker`/`_CoverPicker` + `AppButton.filledPrimary`. **Route:** `/agency/edit`, name `agency-edit` (`app_router.dart:771`).
**Edits:** lift this body into the tab. Replace `_LogoPicker` with **new `DcLogoUploader`** (82 square, `radius 20`, dashed outline, `storefront`, camera badge). Replace `AppTextField`s with **new `DcFormField`** (`surface2` input, h46) + **`DcFormTextArea`** (h96); phone field forces LTR/right-align/Roboto. Coverage areas become **`DcRemovableChip`** + trailing **`DcAddChip`**. Save → `AppButton.filledPrimary`. (Cover-image picker is not in the DC spec — keep or drop per founder.)
**Effort: MEDIUM.**

### B2 · الأعضاء والأدوار (`mTabMembers`)
**Existing file:** `lib\features\agency\presentation\pages\agency_members_page.dart` (roster via `AgencyMembersBloc`, invite `FloatingActionButton.extended`, `AgencyMemberTile` rows, pending-invites strip). **Route:** `/agency/members`, name `agency-members`, `extra: Agency` (`app_router.dart:725`).
**Edits:** invite becomes a top-of-body `AppButton.filledPrimary(icon: group_add)` (drop the FAB). Rows → **`DcMemberRow` (role variant)** = restyle of `agency_member_tile.dart` (44px avatar, tonal/neutral role badge, trailing `more_vert`). Invite sheet (`invite_member_sheet.dart`) is already `AppButton`/`AppTextField`/`AppDropdown` — minor token pass only.
**Effort: MEDIUM.**

### B3 · التحليلات (`mTabAnalytics`)
**Existing file:** `lib\features\agency\presentation\pages\agency_analytics_page.dart` — `Scaffold`+`AppBar`, `ListView` of two `_StatCard` rows + a status-count list. Very minimal today. **Route:** `/agency/analytics`, name `agency-analytics`, `extra: agencyId` (`app_router.dart:749`).
**Edits:** rebuild as: 2-col **`DcKpiCard`** grid (4 cards, icon chip + up/down delta pill + value + label) — do **not** reuse `StatCard` as-is (it applies `AppGradients.featuredTint`, and DC discipline bans gradients; also lacks the delta pill). Bar-chart card → **`DcSimpleBarChart`**: `TokenBarChart` already renders single-hue `primary` vertical bars with `radius 6 6 0 0` normalized to max — **extend it with per-bar X labels** (it currently only supports start/end captions). Top-members list → **new `DcMemberProgressRow`** (36px avatar + name + single-hue `primary` progress bar + trailing count); reuse the fraction/track mechanic from `TokenHbarList`.
**Effort: LARGE** (analytics is a near-total rebuild + needs richer analytics data than the current `memberCount`/`listingsByStatus` cubit exposes — flag the data gap).

### B4 · التوثيق (`mTabVerify`)
**Existing file:** `lib\features\agency\presentation\pages\agency_verification_page.dart` — `Scaffold`+`AppBar`, status banner + `AppTextField`s (ID/registration) + document-upload `AppButton` + submit. **Route:** `/agency/verify`, name `agency-verify`, `extra: agencyId` (`app_router.dart:760`).
**Edits:** add a **new `DcInfoBanner`** (tonal, `verified_user`). Replace the free-text fields with a **`DcDocRow`** list (icon tile + label + **`DcStatusBadge`** accepted/review/required + trailing upload/view). This is a **conceptual change**: DC models verification as a **4-document checklist**, whereas today it's two number fields + one optional photo. Map the existing ID/registration/evidence flow onto document rows, or extend the verification data model. Submit → `AppButton.filledPrimary`.
**Effort: MEDIUM–LARGE** (needs a per-document status model the current `AgencyVerificationRequest` doesn't carry).

---

## SHARED — Non-OK states (loading / empty / error, both screens)

**Existing files:** `lib\core\widgets\empty_state.dart` (`EmptyState`: tinted-circle icon + headline + body + optional CTA — maps cleanly, pass `icon` + `iconColor: colors.onTonal`), `lib\core\widgets\error_state.dart` (`ErrorState`: icon circle + title + message + retry — DC wants `cloud_off` on `redBg` + **filled** primary retry, current uses `wifi_off` + outlined; minor tweak), `lib\core\widgets\loading_state.dart` (verify it provides shimmer; DC wants `DcSkeletonListRow` ×4 and `DcSkeletonDashboard` shimmer layouts — build these two if `LoadingState` lacks them).
**Shell:** the DC non-OK header is the plain rounded-sheet crown → `DcCrownScaffold(title: currentTitle, sheet: true)`.
**Effort: SMALL** (reuse `EmptyState`/`ErrorState`; build the two skeleton widgets — MEDIUM if `LoadingState` has no shimmer primitive).

---

## New shared widgets to build once (with reuse notes)

| DC widget | Build vs. reuse | Notes / existing base |
|---|---|---|
| `DcAgencyProfileHeader` | **NEW** | Sticky/collapsing rich crown; no existing equivalent (all crowns today are fixed). |
| `DcMemberRow` (chat + role variants) | **Restyle** | Base on `agency_member_tile.dart`; add chat-button variant (A3) + role-badge variant (B2). |
| `DcMemberProgressRow` | **NEW** | Reuse fraction/track math from `charts/token_hbar_list.dart`. |
| `DcSimpleBarChart` | **Extend existing** | `charts/token_bar_chart.dart` already does single-hue `primary` vertical bars, `radius`, max-normalized — add per-bar X labels. |
| `DcKpiCard` | **NEW** | Do **not** reuse `stat_card.dart` (gradient wash violates DC; no delta pill). |
| `DcRatingSummaryCard` + `DcRatingBar` | **NEW** | Use gold token (`colors.tertiary`/`goldContainer`, per `ds_listing_card.dart`) not `RatingStars` (it hardcodes `colors.warning`, no color override). |
| `DcReviewCard` | **NEW / adapt** | Reuse patterns from `lib/features/reviews/presentation/widgets/seller_reviews_section.dart`. |
| `DcStatusBadge` (accepted/review/required) | **NEW** | `status_pill.dart` is a shadowed on-image pill — wrong tone; build flat badge. |
| `DcDocRow` | **NEW** | — |
| `DcInfoBanner` | **NEW** | — |
| `DcLogoUploader` | **NEW** | Replaces `_LogoPicker` in `agency_edit_profile_page.dart`. |
| `DcRemovableChip` + `DcAddChip` | **NEW** | `category_chip.dart` is a nearby reference only. |
| `DcContactInfoCard` | **NEW** | Replaces inline `_ContactRow`. |
| `DcMapPlaceholder` | **Adapt** | `map_preview.dart` — swap bg→`surface2`, add grid lines + `location_on`, height 130. |
| `DcFormField` / `DcFormTextArea` | **NEW** | `surface2` inputs (h46 / h96); phone variant LTR+Roboto. Distinct from the outlined `AppTextField`. |
| `DcSkeletonListRow` / `DcSkeletonDashboard` | **NEW** | Confirm/extend `loading_state.dart` shimmer primitive. |
| Transparent `DcCrownIconButton` | **Extend existing** | Add `filled:false` (40px transparent white-icon) to `dc_crown_scaffold.dart`. |

**Reuse directly, no change:** `CrownUnderlineTabs`, `DsListingCard`, `AppButton` (whatsapp/tonal/outlined/filled), `MoneyFormatter`, `AppColors.of`/`AppTextStyles.of`/`AppSpacing`/`AppRadii`, and `DcCrownScaffold(sheet:false)` for Screen B's flat body.

**Blocs/usecases/repos:** all reusable unchanged (`agency_*_bloc.dart`/`*_cubit.dart`, `agency_repository.dart`). The two real backend/data gaps are (1) agency profile stats + coverage/specialties/hours + **agency-scoped reviews**, and (2) a per-document verification status model — both needed for pixel-parity but out of the presentation layer.
