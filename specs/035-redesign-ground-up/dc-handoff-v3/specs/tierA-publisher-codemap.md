I now have a complete picture. Here is the mapping.

---

# Tier A (Publisher) — DC v3 → Flutter code map

## Architecture preamble (read first — affects 5 of 9 screens)

**There is NO existing publisher tab shell or publisher bottom nav.** The DC spec treats dashboard / listings / crm / inquiries / viewings as 5 sibling tabs under one persistent bottom bar (`TAB_SET`), with analytics / moderation / leadDetail / inquiryDetail as pushed children that hide the bar. Today these are **disparate, separately-routed pages**:

- `MainBottomNav` (`lib/core/widgets/main_bottom_nav.dart`) is the **buyer** 5-tab bar (Home/Search/Saved/Messages/Account). It does NOT contain publisher tabs and is the wrong bar for these surfaces.
- CRM (`CrmPage`) and Viewings (`ViewingsListPage`) have **no `go_router` route at all** — they are `Navigator.push`ed from the dashboard quick actions, the "Add to CRM" action (`lib/features/crm/presentation/widgets/add_to_crm_action.dart`), and the profile nav drawer (`lib/core/widgets/app_nav_drawer.dart` lines ~109, ~181-183).
- None of the 9 screens currently use `DcCrownScaffold` — every one is a plain `Scaffold` + `AppBar`.

**Prerequisite task (NEW, LARGE):** build a `PublisherTabShell` + `DcPublisherBottomNav` (5 slots: `space_dashboard` التحكم / `apartment` إعلاناتي / `groups` العملاء / `forum` الاستفسارات badge2 / `event` المعاينات badge1). Model the bar on the existing `MainBottomNav` `_NavTab` (62×32 `secondaryContainer` indicator pill + filled/outline icon + label + red count badge) — that widget already matches the DC bottom-nav spec almost exactly; parameterize it or fork a `DcPublisherBottomNav`. Decide the shell mechanism: either a `StatefulShellRoute.indexedStack` rooted at a new `/publisher` route, or a single `PublisherTabShell` stateful page that swaps bodies (simpler; keeps CRM/viewings reachable without new deep-link routes). Recommended: **StatefulShellRoute** so each tab keeps its own nav stack and pushed children (analytics/moderation/leadDetail/inquiryDetail) hide the bar naturally. This new shell owns the `bottomNavigationBar` and each tab screen adopts `DcCrownScaffold(sheet: …)` for its own crown.

**Data-model nuance (no logic change):** `CrmStage` (`lib/features/crm/domain/entities/crm_stage.dart`) has **6** stages (`newLead/contacted/viewing/negotiation/won/lost`). DC collapses `won`+`lost` into a single «مغلق» chip in the stage-changer (5 chips) while the `crm` list still color-codes won→green / lost→red. Keep the 6-stage cubit; the restyle only changes chip presentation — flag for the implementer, do NOT alter the enum.

---

## Screen: `dashboard` — «لوحة التحكم»

- **Existing file:** `lib/features/publisher_dashboard/presentation/pages/publisher_dashboard_page.dart`
- **Current root:** `Scaffold` + `AppBar(title)`; body is a `ListView` of a gradient `_Header` band, a `StatCard` 2-col grid (`_StatGrid`, uses `lib/core/widgets/stat_card.dart`), `PublisherChartsSection` (`../widgets/publisher_charts_section.dart`), and `AppDashboardTile` quick-actions. **Uses a BANNED gradient** in `_Header` (lines 112-121) and `_TotalHeader` styling.
- **Route(s):** `/publisher/dashboard` (name `publisher-dashboard`, `requirePublisherStatusRedirect`), builder `PublisherDashboardPage`. Also the target of `/dashboard` → `DashboardEntryPage` (`lib/features/dashboard/presentation/pages/dashboard_entry_page.dart`) which returns `PublisherDashboardPage()` for approved publishers. Reached from Profile menu / `/dashboard`.
- **Edits (ordered):**
  1. Replace `Scaffold`+`AppBar` with `DcCrownScaffold(title:'لوحة التحكم', sheet:true, bottomNavigationBar: DcPublisherBottomNav(index:0))`. But the crown here is **bespoke** (identity block, not a plain title) — pass a custom crown via the shell, or use `DcCrownScaffold` and override the crown row: leading = 42×42 radius-12 `storefront` chip on `rgba(255,255,255,.16)`; title = two-line agency name (+ `verified` FILL 16px) / subtitle «لوحة التحكم · وكيل معتمد»; action = 40×40 bell (`notifications`) with red 8×8 unread dot. `DcCrownScaffold` today only supports a plain `Text` title, so either extend it with an optional `titleWidget`/`crownIdentity` slot or build a bespoke crown Column inside `body` with `sheet:false`.
  2. Delete the gradient `_Header`.
  3. Rebuild `_StatGrid` with **`DcKpiCard`** (NEW widget #1): 2-col gap-10, icon chip 32×32 radius-9 `tonal`, optional up/down delta pill (green/red, Roboto 11/700), value 22/700 Roboto, label 12/600, sub 11 muted. Map the 4 DC KPIs (`campaign`/6/إعلانات نشطة, `visibility`/4,820/مشاهدات, `groups`/128/عملاء, `bolt`/92%/معدّل الاستجابة). Data still comes from `PublisherDashboardCounts`; add delta wiring only where counts support it (else drop the pill — `showTrends`).
  4. Replace `PublisherChartsSection` with a **`DcBarChart`** (NEW #2) card «المشاهدات» — single-hue `colors.primary`, 128px, header total. The existing `lib/core/widgets/charts/token_bar_chart.dart` is the closest base; adapt it (add header-total row + x-labels) or wrap.
  5. Add a **`DcQuickLinkTile`** 3-col grid (NEW #6) «إدارة النشاط» — 6 tiles (`apartment`→listings, `bar_chart`→push analytics, `groups`→crm, `forum` badge2→inquiries, `event` badge1→viewings, `fact_check`→push moderation). Replaces `AppDashboardTile` column.
  6. Add **`DcActivityList`** (NEW #7) «آخر النشاط» with «عرض الكل»→inquiries.
- **Effort: LARGE.**

---

## Screen: `listings` — «إعلاناتي»

- **Existing file:** `lib/features/publisher_dashboard/presentation/pages/my_listings_page.dart` (+ row widgets `../widgets/listing_card.dart`, `../widgets/status_filter_chip_row.dart`, `../widgets/rejection_reason_banner.dart`, `../widgets/status_badge.dart`).
- **Current root:** `Scaffold` + `AppBar(title)`; a `Column` of `StatusFilterChipRow` (Material `ChoiceChip`s) over a `ListView.builder` of `ListingCard` (Phase-10 card, NOT the DC manage-card). Rejected rows wrap the card with `RejectionReasonBanner`.
- **Route:** `/publisher/dashboard/my-listings` (name `publisher-my-listings`, `requirePublisherStatusRedirect`), builder `MyListingsPage`. Reached from dashboard KPI/quick-link taps and `MyListingsPage` empty-CTA. No FAB today.
- **Edits (ordered):**
  1. Adopt `DcCrownScaffold` (sticky crown) with title «إعلاناتي» 20/700, action = `DcCrownIconButton(search)`, `crownBottom` = **`CrownUnderlineTabs`** (reuse `lib/core/widgets/crown_underline_tabs.dart`) with 6 filter tabs الكل·منشور·قيد المراجعة·مرفوض·منتهٍ·مسودّة. Wire the tab index to the existing `MyListingsBloc.ChangeStatusFilter` (`../bloc/my_listings_event.dart`) — replaces `StatusFilterChipRow`.
  2. Rebuild `ListingCard` → **`DcListingManageCard`** (NEW #9): 88×66 thumb + featured `star` chip (gold) + price/status row + title + location + stats (`visibility`/`groups`) tap→push moderation; rejected banner region (reuse `RejectionReasonBanner` content, restyle to `redC`); 3-cell action row (تعديل / تمييز(4 states via `canFeature`/`featured`/`featureOff`) / أرشفة) split by dividers. Keep all existing wiring (renew token listener, `FindOpenRevision` "edit in review", location-label host).
  3. Introduce **`DcStatusPill`** (NEW #5, shared) for the status pill; replace `status_badge.dart`.
  4. Add extended **FAB** «أضف إعلان» (`add`, radius-16, primary, shadow) → `context.pushNamed(AppRouteNames.publisherListingsCreate)`. Reuse pattern from `lib/core/widgets/publish_fab.dart` if suitable.
- **Effort: LARGE.**

---

## Screen: `analytics` — «تحليلات العملاء» (pushed)

- **Existing file:** `lib/features/publisher_dashboard/presentation/pages/lead_analytics_page.dart`
- **Current root:** `Scaffold` + `AppBar(title)`; `ListView` of a **gradient** `_TotalHeader` (BANNED), a `TokenBarChart` (`lib/core/widgets/charts/token_bar_chart.dart`), and per-listing `_ListingBreakdownCard`s with 4 `_LeadCounter`s.
- **Route:** NONE — pushed via `Navigator.push` from `PublisherDashboardPage._openLeadAnalytics` (wraps `LeadAnalyticsPage` in a fresh `PublisherAnalyticsCubit`). Under the new shell it should push within tab-0's stack (bar hidden).
- **Edits (ordered):**
  1. Adopt `DcCrownScaffold(leading: back DcCrownIconButton(arrow_forward), sheet: true)`, sticky crown, `crownBottom` = `CrownUnderlineTabs` periods 7 أيام·30 يوم·3 أشهر (presentational only — no dataset swap; wire to nothing or to existing window if cubit supports it).
  2. Delete gradient `_TotalHeader`; replace the two summary stats with the **no-icon `DcKpiCard` variant** (#1) — 143 إجمالي التفاعلات +11%, 14% معدّل التحويل +2%.
  3. Replace `TokenBarChart` with **`DcStackedBarChart`** (NEW #3) «التفاعلات حسب الأسبوع» — single-hue opacity ramp (1/.72/.46/.26) + legend مكالمات·واتساب·استفسارات·معاينات. Feed from `PublisherLeadAnalytics` source counts.
  4. Replace `_ListingBreakdownCard` with **`DcMiniTable`** (NEW #4) «حسب المصدر» — call/chat/mail/event rows + total, green/red deltas.
- **Effort: LARGE.**

---

## Screen: `moderation` — «سجل المراجعة» (pushed)

- **Existing file:** `lib/features/publisher_dashboard/presentation/pages/listing_moderation_history_page.dart`
- **Current root:** `Scaffold` + `AppBar(title)`; `ListView.builder` of `_HistoryEntryCard`s (each a card with a "prev → new" status-arc row of soft `_StatusPill`s + timestamp + rejection preset/detail). Driven by `ModerationHistoryCubit` over `ModerationHistoryEntry`.
- **Route:** `/publisher/listings/:id/moderation-history` (name `publisher-listings-moderation-history`, `requirePublisherLoginRedirect`), builder `ListingModerationHistoryPage(listingId:)`. Reached from the "View moderation history" affordance on rejected rows and (per DC) the manage-card tap region.
- **Edits (ordered):**
  1. Adopt `DcCrownScaffold(leading: back, sheet: false)` — DC `moderation` uses a **flat `--surface` body, no rounded overlapping sheet**, non-sticky simple crown bar.
  2. Add the top **listing summary card** (thumb 56×48 + title/price + `DcStatusPill` green «منشور») — new; needs a listing title/price which the page doesn't currently load (it only has history entries). Either pass listing summary via route `extra`/a light fetch, or keep summary minimal from available data.
  3. Replace `_HistoryEntryCard` list with **`DcModerationTimeline`** (NEW #8): node circle (green/red/neutral) + connector line + title + time + optional body box. Map `ModerationHistoryEntry` transitions to nodes (approved→green `check_circle`, rejected→red, submit/resubmit→neutral). Preserve the "Admin team" attribution rule (never show admin identity).
- **Effort: MEDIUM.**

---

## Screen: `crm` — «العملاء المحتملون» (tab)

- **Existing file:** `lib/features/crm/presentation/pages/crm_page.dart` (+ `../widgets/crm_stage_styles.dart` for stage label/color).
- **Current root:** `Scaffold` + `AppBar(title)` + `FloatingActionButton.extended` (add lead); body `CustomScrollView` with a `_DueTodayBanner` (BANNED warning-tinted look OK but restyle), a `_StageFilterRow` (Material `ChoiceChip`s), and `_LeadCard`s (name + last-activity + soft `_StagePill`).
- **Route:** NONE — `Navigator.push`ed as `const CrmPage()` from dashboard quick action (`publisher_dashboard_page.dart:314`), `add_to_crm_action.dart:58`, and nav drawer (`app_nav_drawer.dart:109`). As a shell tab it becomes tab-2 root.
- **Edits (ordered):**
  1. Adopt `DcCrownScaffold(title:'العملاء المحتملون', sheet:true, bottomNavigationBar: DcPublisherBottomNav(index:2))`, sticky crown, `crownBottom` = `CrownUnderlineTabs` الكل·جديد·تواصل·معاينة·تفاوض·مغلق (map «مغلق» → won∪lost filter; wire to `CrmLeadsCubit.setStageFilter`). Replaces `_StageFilterRow`.
  2. Rebuild `_LeadCard` → **`DcLeadRow`** (NEW #10): 44×44 initial avatar (`tonal`) + name + **`DcSourceChip`** (`forum`/`mail`/`event`) + listing sub + **`DcStagePill`** (dot + tone) + last-contact. Source comes from `CrmLead` source; stage tone from `crmStageColor`.
  3. Keep the FAB (add manual lead) and the due-today banner (restyle to a quieter `DcReminderCard`-like tonal block, or keep). Tap → push `leadDetail`.
- **Effort: MEDIUM.**

---

## Screen: `leadDetail` — «تفاصيل العميل» (pushed)

- **Existing file:** `lib/features/crm/presentation/pages/lead_detail_page.dart`
- **Current root:** `Scaffold` + `AppBar(title)`; a `ListView` with name headline, `_StageChips` (Material `ChoiceChip`s, 6 stages), `_QuickActions` (`AppButton` chat/call/whatsapp), a `_NoteComposer` (inline `AppTextField` + icon button — NOT a sticky bottom bar), `_RemindersSection`, and an activity timeline of `_ActivityTile`s.
- **Route:** NONE — `Navigator.push`ed from `crm_page.dart:_openDetail` with a fresh `LeadDetailCubit`. Under the shell it pushes in tab-2's stack.
- **Edits (ordered):**
  1. Adopt `DcCrownScaffold(leading: back, sheet: false, body bg: colors.bg)` with a **custom crown title** (40×40 avatar initial + two-line name / `leadSrcLabel`). Body bg is `--bg` not surface.
  2. Move the note composer OUT of the scroll body into a **sticky bottom `DcComposerBar`** (NEW #14) — the DcCrownScaffold has no built-in bottom-composer slot, so either add a `bottomBar`/`sheet` param to it or wrap the scaffold `body` in a `Column(children:[Expanded(scroll), DcComposerBar()])`. Placeholder «أضف ملاحظة…», circular `add` send. Wire to existing `LeadDetailCubit.addNote`.
  3. Add a **contact card** with 3 **`DcLabelValueRow`** (NEW #13) هاتف/العقار/الميزانية + call(`tonal`)/واتساب(`greenC`) buttons — reuse `_QuickActions` launch logic.
  4. Rebuild `_StageChips` → **`DcStageChips`** (NEW #11): 5 pills (collapse won+lost → «مغلق»); on=primary, off=outlined. Keep optimistic `changeStage`.
  5. Add **`DcReminderCard`** (NEW #12) tonal banner for the next reminder (from `state.reminders`), «تعديل» → existing add/edit sheet.
  6. Rebuild notes list → **`DcNoteCard`** (NEW #13) list (text + time). Keep delete-note dialog.
- **Effort: LARGE.**

---

## Screen: `inquiries` — «الاستفسارات» (tab, badge 2)

- **Existing file:** `lib/features/inquiries/presentation/pages/inquiry_inbox_page.dart` (+ `../widgets/inbox_status_badge.dart`, `../widgets/inquiry_message_snippet.dart`, `../widgets/inbox_skeleton.dart`).
- **Current root:** `Scaffold` + `AppBar(leading: DeepLinkAwareBackButton, title, actions:[status filter PopupMenu, listing filter PopupMenu])`; body `ListView.builder` of `_InquiryRowTile` (AppSurface card: unread dot + name + `InboxStatusBadge` + phone + listing + `InquiryMessageSnippet` + date). Driven by `InquiryInboxBloc`.
- **Route:** `/inquiries` (name `inquiries`), builder `InquiryInboxPage`. Reached from dashboard KPIs/quick-link, home entry points. Becomes tab-3 root under the shell.
- **Edits (ordered):**
  1. Adopt `DcCrownScaffold(title:'الاستفسارات', sheet:true, bottomNavigationBar: DcPublisherBottomNav(index:3))`. Crown action = custom **unread pill** («2 غير مقروء», `rgba(.16)` bg, 7×7 red dot) instead of the two `PopupMenuButton`s (relocate the status/listing filters into a sheet or drop the listing filter which is a non-functional stub today — lines 115-140).
  2. Rebuild `_InquiryRowTile` → **`DcInquiryRow`** (NEW #15): 44×44 initial avatar + unread red dot / name + time / listing chip / 2-line clamped message / trailing unread count badge. Reuse `InquiryMessageSnippet` for the clamp; map `InquiryStatus.new_` → unread. Tap → `context.push(AppRoutes.inquiryDetailFor(id))` (unchanged).
  3. Keep `InboxSkeleton` or swap to `DcSkeleton.skList` (Tier D #19).
- **Effort: MEDIUM.**

---

## Screen: `inquiryDetail` — «الاستفسار» (pushed)

- **Existing file:** `lib/features/inquiries/presentation/pages/inquiry_detail_page.dart`
- **Current root:** `Scaffold` + `AppBar(leading: back, title)`; a `SingleChildScrollView` of a header AppSurface (status badge + sender + callback phone + call button), a message card, a tappable listing-reference row, an "Add to CRM" button, and `_StatusMutationButtons`. **This is a form/detail view, NOT a chat thread** — the DC design reframes it as a messaging thread with a composer.
- **Route:** `/inquiries/:id` (name `inquiry-detail`), builder `InquiryDetailPage(id:)`. Reached via `context.push(inquiryDetailFor(id))` from the inbox.
- **Edits (ordered):**
  1. Adopt `DcCrownScaffold(leading: back, sheet:false, body bg: colors.bg)`, custom crown (38×38 avatar + name + `call` `DcCrownIconButton`).
  2. Add **`DcListingContextBar`** (NEW #16) below the crown (thumb + listing title/price + chevron, tap→listing details). Reuses the existing listing-reference-row data.
  3. Add a **thread** area (`DcChatBubble`) — **NOTE:** the current model has a single inbound message, not a conversation. If inquiry replies aren't a real data feature, render the one message as a `theirs` bubble + day divider and keep the status-mutation actions; do NOT fabricate a fake thread. The existing `lib/core/widgets/chat_bubble.dart` is a simple symmetric `AppSurface` bubble — **enhance it** to the DC theirs/mine asymmetric-radius (`4 16 16 16` / `16 4 16 16`) + inline time, or add a `DcChatBubble` variant.
  4. Add a bottom composer: **`DcComposerBar`** (NEW #14) with a **leading attach button** (the shared param `leading`) + **`DcQuickReplyChips`** (NEW #17) row above it (4 canned replies). Whether "send" actually posts depends on backend support — if inquiries are one-shot, the composer may map to "mark responded" / a note; confirm with product before wiring. Keep `_StatusMutationButtons` logic reachable.
- **Effort: LARGE.** (Flag: possible data-model gap — inquiry is currently single-message, not a thread.)

---

## Screen: `viewings` — «طلبات المعاينة» (tab, badge 1)

- **Existing file:** `lib/features/viewings/presentation/pages/viewings_list_page.dart`
- **Current root:** `Scaffold` + `AppBar(title)`; `ListView.separated` of `_ViewingCard` (title + `_SoftStatusPill` + date/time + note + Confirm/Decline or Cancel `AppButton`s + Add-to-CRM). Driven by `ViewingsCubit` (**must be provided above the page** — it is not self-providing).
- **Route:** NONE — pushed from the nav drawer wrapping it in `BlocProvider<ViewingsCubit>` (`app_nav_drawer.dart:181-183`) and from `request_viewing_sheet.dart`. Becomes tab-4 root; the shell must provide `ViewingsCubit`.
- **Edits (ordered):**
  1. Adopt `DcCrownScaffold(title:'طلبات المعاينة', sheet:true, bottomNavigationBar: DcPublisherBottomNav(index:4))`, sticky crown, `crownBottom` = `CrownUnderlineTabs` الكل·معلّق·مؤكّد·منتهٍ (منتهٍ = past∪declined). Add client-side filtering over `state.viewings` (cubit has no filter today — add a local filter or a cubit filter field; visual/UI-only preferred = local).
  2. Rebuild `_ViewingCard` → **`DcViewingCard`** (NEW #18): avatar+name row + `DcStatusPill` (confirmed→green `event_available`, declined→red `event_busy`, pending→neutral, past→neutral `history`); listing row on `surface2`; datetime row (`event`/`schedule` primary icons); action pair (pending: تأكيد/رفض; confirmed: تواصل/إعادة جدولة). Reuse existing `_transition` + `ViewingsCubit.updateStatus`. Replace `_SoftStatusPill` with `DcStatusPill`.
- **Effort: MEDIUM.**

---

## Shared data-states (loading / empty / error) — Tier D overlap

- **Existing files:** `lib/core/widgets/empty_state.dart`, `lib/core/widgets/error_state.dart`, `lib/core/widgets/loading_state.dart` (+ per-feature skeletons: `inbox_skeleton.dart`, the inline `_MyListingsSkeleton`, `_AnalyticsSkeleton`, `_StatGridSkeleton`).
- **Edits:** Build **`DcSkeleton`** (NEW #19, Dash/List/Detail variants, shimmer), **`DcEmptyState`** / **`DcErrorState`** (NEW #20, crown-header + 88×88 tonal/redC circle + title/body/CTA). These are **Tier D shared chrome** — build once there, then swap the state branches in each screen above (`EmptyState`→`DcEmptyState`, `ErrorState`→`DcErrorState`, skeletons→`DcSkeleton`). Per-screen icon/title/body/CTA from the spec's `emptyMap` (only dashboard/listings carry a CTA).
- **Effort: MEDIUM** (mostly Tier D; per-screen swaps are TRIVIAL each).

---

## NEW shared widgets (Task #23) → proposed paths

Build under `lib/core/widgets/dc/` (sibling to existing `ds/`), reconciled against what already exists:

| # | New widget | Proposed path | Reuse / replaces |
|---|---|---|---|
| 1 | `DcKpiCard` (+no-icon variant) | `lib/core/widgets/dc/dc_kpi_card.dart` | supersedes `stat_card.dart` usage on dashboard/analytics (adds delta pill) |
| 2 | `DcBarChart` | `lib/core/widgets/charts/dc_bar_chart.dart` | adapt `charts/token_bar_chart.dart` |
| 3 | `DcStackedBarChart` | `lib/core/widgets/charts/dc_stacked_bar_chart.dart` | NEW (no existing stacked chart) |
| 4 | `DcMiniTable` | `lib/core/widgets/dc/dc_mini_table.dart` | loosely `charts/token_hbar_list.dart` |
| 5 | `DcStatusPill` | `lib/core/widgets/dc/dc_status_pill.dart` | replaces `status_pill.dart` + inline `_SoftStatusPill`/`_StagePill` copies |
| 6 | `DcQuickLinkTile` | `lib/core/widgets/dc/dc_quick_link_tile.dart` | supersedes `dashboard_tile.dart` on dashboard |
| 7 | `DcActivityList` | `lib/core/widgets/dc/dc_activity_list.dart` | NEW |
| 8 | `DcModerationTimeline` | `lib/features/publisher_dashboard/presentation/widgets/dc_moderation_timeline.dart` | replaces `_HistoryEntryCard` |
| 9 | `DcListingManageCard` | `lib/features/publisher_dashboard/presentation/widgets/dc_listing_manage_card.dart` | replaces `widgets/listing_card.dart` |
| 10 | `DcLeadRow`/`DcStagePill`/`DcSourceChip` | `lib/features/crm/presentation/widgets/dc_lead_row.dart` | replaces `_LeadCard`/`_StagePill` |
| 11 | `DcStageChips` | `lib/features/crm/presentation/widgets/dc_stage_chips.dart` | replaces `_StageChips` |
| 12 | `DcReminderCard` | `lib/features/crm/presentation/widgets/dc_reminder_card.dart` | NEW |
| 13 | `DcNoteCard`/`DcLabelValueRow` | `lib/features/crm/presentation/widgets/dc_lead_detail_bits.dart` | NEW |
| 14 | `DcComposerBar` | `lib/core/widgets/dc/dc_composer_bar.dart` | shared leadDetail+inquiryDetail |
| 15 | `DcInquiryRow` | `lib/features/inquiries/presentation/widgets/dc_inquiry_row.dart` | replaces `_InquiryRowTile` |
| 16 | `DcListingContextBar` | `lib/features/inquiries/presentation/widgets/dc_listing_context_bar.dart` | NEW |
| 17 | `DcQuickReplyChips` | `lib/core/widgets/dc/dc_quick_reply_chips.dart` | NEW |
| 18 | `DcViewingCard` | `lib/features/viewings/presentation/widgets/dc_viewing_card.dart` | replaces `_ViewingCard` |
| 19 | `DcSkeleton` | `lib/core/widgets/dc/dc_skeleton.dart` | Tier D; replaces ad-hoc skeletons |
| 20 | `DcEmptyState`/`DcErrorState` | `lib/core/widgets/dc/dc_empty_state.dart`, `dc_error_state.dart` | Tier D; wrap/replace `empty_state.dart`/`error_state.dart` |
| 21 | `DcChatBubble` | enhance `lib/core/widgets/chat_bubble.dart` (add asymmetric radius + time) | existing bubble is symmetric-only |
| — | `DcPublisherBottomNav` + `PublisherTabShell` | `lib/core/widgets/dc/dc_publisher_bottom_nav.dart` + a shell page/route | model on `main_bottom_nav.dart` `_NavTab` |

**Cross-cutting requirements** for every widget above: token-only (`AppColors.of`/`AppTextStyles.of`/`AppSpacing`/`AppRadii`/`AppElevation.of` — no raw `Color()`/`EdgeInsets` numbers/`BorderRadius.circular(n)`, and no "18px"-style comments — the linter text-scans comments); Western digits via `MoneyFormatter`/`formatLocalizedNumber`; every visible string an ARB key with a matching `_DebugAppLocalizations` `@override`; RTL-safe directional insets/alignment. `AppColors` already exposes `brandHeader`/`onBrandHeader`/`surface`/`surface2`/`primary`/`textMuted`/`outline`/`success`/`warning`/`error`/`secondaryContainer`/`onSecondaryContainer` — confirm gold(featured)/greenC/redC tonal tokens exist before use; if the DC container tints (`--greenC`/`--redC`/`--goldC`/`--tonal`) aren't yet in the palette, add them in the Task #23 foundation pass.

## Effort roll-up

| Screen | Effort |
|---|---|
| Publisher tab shell + bottom nav (prerequisite) | LARGE |
| dashboard | LARGE |
| listings | LARGE |
| analytics | LARGE |
| leadDetail | LARGE |
| inquiryDetail | LARGE (+ data-model flag) |
| moderation | MEDIUM |
| crm | MEDIUM |
| inquiries | MEDIUM |
| viewings | MEDIUM |
| shared states (Tier D swaps) | MEDIUM |
