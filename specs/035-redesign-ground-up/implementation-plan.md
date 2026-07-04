# Spec 035 — Al Nujom Ground-Up Redesign: Staged File-Level Implementation Plan

Grounded against the live tree (`main_bottom_nav.dart` read in full; all 7 `MainBottomNav(current:)` call sites confirmed; `AppBottomNav` confirmed legacy — referenced only by `theme_gallery_page.dart` + its own test). This plan is purely visual + IA; backend-dependent features are quarantined to Stage 3.

---

## PART 1 — TARGET IA (the 5-tab structure)

### Final tab model
| Slot | Label (ar) | Enum | Route | Icon (active/inactive) | Auth |
|---|---|---|---|---|---|
| 1 | استكشف | `home` | `AppRoutes.home` `/` | `home_rounded` / `home_outlined` | public |
| 2 | بحث وخريطة | `search` | `AppRoutes.search` `/search` | `travel_explore` (Lucide `search`/`map`) | public |
| 3 | المحفوظة | `favorites` | `AppRoutes.favorites` `/favorites` | `favorite` / `favorite_border` | gated → `/login` |
| 4 | الرسائل | `chat` | **`AppRoutes.chat` `/chat` (NEW)** | `chat_bubble` / `Icons.forum_outlined` | gated → `/login` |
| 5 | حسابي | `profile` | `/profile` or `/login` | `person` / `person_outline` | soft-gated |
| FAB | أضف عقار | — (never a tab) | `pushNamed(publisherListingsCreate)` | `add_home` | publishers only |

**Diff vs today** (`MainTab { home, reels, favorites, profile, none }`):
- **Drop `reels` as a tab** → Reels survives only as the Home `ReelsRail()` (already at `home_page.dart:256`) + the `/reels` deep route (kept, reachable from the rail "عرض الكل").
- **Add `search` as tab 2** (Search was demoted in Phase 030; this re-promotes it, now labelled بحث وخريطة).
- **Add `chat` as tab 4** — first time Chat gets a go_router route; today it is only a `MaterialPageRoute` push from `AppNavDrawer`.
- **Publish FAB decision:** keep it OUT of the tab row. 5 equal `flex:1` tabs + a floating Extended FAB above the bar (design §09 / component-lib §6), publishers-only. This avoids the crowded 6-slot problem and matches the mock. The current in-bar `_PublishFab` is removed from `slots` and reborn as a reusable `PublishFab` widget hosted via `Scaffold.floatingActionButton`.

### Exact symbol changes

**`lib/core/widgets/main_bottom_nav.dart`**
- Line 28: `enum MainTab { home, reels, favorites, profile, none }` → `enum MainTab { home, search, favorites, chat, profile, none }`.
- Lines 72–121 `slots`: remove the Reels `_NavTab` (81–88); insert Search `_NavTab` (`LucideIcons.search`, `l10n.nav_search_map`, `context.go(AppRoutes.search)`, `current == MainTab.search`); after Favorites insert Chat `_NavTab` (`Icons.forum_outlined`/`Icons.forum`, `l10n.nav_messages`, `onTap: () => context.go(isSignedIn ? AppRoutes.chat : AppRoutes.login)`, `current == MainTab.chat`) with an optional unread `Badge`.
- Lines 91–99: delete the `_PublishFab` insertion into `slots`. Extract `_PublishFab` (231–281) into a public `class PublishFab` (same file or new `lib/core/widgets/publish_fab.dart`) that pages mount via `floatingActionButton:` guarded by the same `isApprovedPublisher` `BlocBuilder`.
- Keep `_NavTab`, indicator, and token usage unchanged.

**`lib/core/routing/app_router.dart`**
- `AppRoutes` (83–176): add `static const String chat = '/chat';`.
- `AppRouteNames` (178–266): add `static const String chat = 'chat';`.
- `routes:` list: add a `GoRoute(path: AppRoutes.chat, name: AppRouteNames.chat, redirect: <auth-gate mirroring favorites 672–678>, builder: (_, __) => BlocProvider<ConversationsCubit>(create: (_) => getIt<ConversationsCubit>(), child: const ConversationsListPage()))`.
- `/reels` (602–609) and `/search` (578–593) unchanged.

**Call-site updates (all 7 confirmed):**
- `reels_tab_page.dart:34` `MainTab.reels` → `MainTab.none` (Reels no longer a tab).
- `search_page.dart:201` `MainTab.none` → `MainTab.search`.
- `favorites_page.dart:102`, `profile_page.dart:77/85/94`, `home_page.dart:219` → compile-clean after rename (no value change).
- New Chat tab host: `conversations_list_page.dart` gains `bottomNavigationBar: const MainBottomNav(current: MainTab.chat)` + drawer + `PublishFab`.

**`lib/core/widgets/app_nav_drawer.dart`:** remove the Chat entry (Activity §, 168–182) to avoid duplication; keep Viewings. Point any remaining chat affordance at `context.go(AppRoutes.chat)`.

**`lib/core/widgets/app_bottom_nav.dart`:** legacy, only `theme_gallery_page.dart` + `app_bottom_nav_test.dart` reference it. Leave untouched in Stage 0 (deleting touches a test — out of "no test changes" comfort zone); mark for removal in a later cleanup.

---

## PART 2 — TOKEN DELTA (`lib/core/theme/*`)

All edits land in **`color_palette.dart`** (`ModernPalette._lightTokens` / `_darkTokens`). No new `AppPaletteTokens` fields are required — every design token maps onto an existing role. The load-bearing brand hues (primary, onPrimary, accent, tertiary, verified, whatsapp, surface/card light) already MATCH.

### Light (`_lightTokens`) — apply these exact-value nudges
| Field | From | To | Reason |
|---|---|---|---|
| `error` | `0xFFD23F3F` | `0xFFD64545` | design error |
| `outline` | `0xFFE2E8F0` | `0xFFE4E9F0` | design border/hairline |
| `onSurface` | `0xFF0F172A` | `0xFF0B182B` | design ink/navy |
| `onSurfaceVariant` | `0xFF475569` | `0xFF5B6B80` | design readable caption/slate |
| `surfaceVariant` | `0xFFEAEFF5` | `0xFFE9EDF3` | segmented-track / chip-neutral-fill |
| `textMuted` | `0xFF64748B` | `0xFF9AA4B2` | design "steel" (placeholder/inactive) — **see AA caveat below** |

**AA caveat (must verify):** design reserves `#9AA4B2` for placeholder/inactive/meta only; `#5B6B80` is the readable caption. `textMuted` in this codebase is used for both. Audit `textMuted` call sites for readable body-secondary text; where it carries real content, keep those on `onSurfaceVariant` (`#5B6B80`) and only let decorative/placeholder usages read steel. Re-run `color_scheme_contrast` after — expect a baseline regen.

Keep as-is (no design token): `warning`, `outlineStrong`, `success` (`#2E9E6B` acceptable; optional align to whatsapp `#1DAB61`), `primaryContainer`, `verifiedContainer`.

### Dark (`_darkTokens`) — the bigger drift
| Field | From | To |
|---|---|---|
| `primary` | `0xFF5896FF` | `0xFF4D7CFF` |
| `surface` | `0xFF0B1020` | `0xFF0B182B` |
| `surfaceVariant` | `0xFF161C2D` | `0xFF13233B` |
| `card` | `0xFF161C2D` | `0xFF13233B` |
| `outline` | `0xFF252E44` | `0xFF22344E` |
| `onSurfaceVariant` | `0xFF9FABC4` | `0xFF8FA0B5` |
| `verified` | `0xFF57C48C` | `0xFF4CC08A` |
| `onSurface` | `0xFFEAF0FB` | `0xFFEAF0F8` (optional, ~identical) |
| `textMuted` | `0xFF8694AC` | `0xFF8FA0B5` (optional) |

Keep dark `accent`, `tertiary`, `error`, `whatsapp`, `verifiedContainer` (no design dark swatch).

### Other theme files
- `typography.dart`: current Tajawal/Inter split stays. Optionally align sizes to the token table (display 28/900, headline 22/800, title 17/700, body 15/500 lh1.7, caption 13/500, label 11/700) — low-risk, but touching sizes shifts many layouts, so treat as a Stage-0 audit item, not a blind edit.
- `spacing.dart` / `radii.dart`: already match the 4pt grid and radius scale (`sm8/md12/lg16/xl24/pill999`) plus need **`sheet = 24`** (reuse `xl`) — no change required; confirm `AppRadii.xl` used for sheets.
- `elevation.dart`: card `0 2px 8px rgba(11,24,43,.07)` ≈ existing `level1`; raised/FAB `.12` ≈ `level2`; sheet `-8px 32px .14` — verify a sheet ramp exists or add. Edits stay inside the whitelisted file.
- `app_theme.dart`: component themes (segmented track, chip fill, input border 1.5px, nav) re-tune to the new tokens — no raw literals.

**Baseline regen expected & intentional:** `property_card` golden + `color_scheme_contrast`. Regenerate and review the diff at the end of Stage 0/1.

---

## PART 3 — STAGED BUILD ORDER

Each stage is analyze-green, token-lint exit-0, l10n-parity clean, and independently shippable behind the same PR branch (squash-merged once at spec end per the one-PR rule — but each stage is a self-contained commit series).

---

### STAGE 0 — FOUNDATION (token delta + 5-tab shell + component library)

**Feature: theme tokens**
- Edit: `lib/core/theme/color_palette.dart` (light+dark deltas above), `app_theme.dart` (component re-tune), optionally `elevation.dart` (sheet ramp), `typography.dart` (size audit only if pursued).
- Regen goldens/contrast baselines at stage end.

**Feature: nav shell + routing**
- Edit: `main_bottom_nav.dart` (enum + slots + extract `PublishFab`), `app_router.dart` (chat route + AppRoutes/AppRouteNames), `app_nav_drawer.dart` (drop Chat dup), all 7 call sites, `conversations_list_page.dart` (mount nav+drawer+FAB as a top-level tab host).
- New shared widget: `lib/core/widgets/publish_fab.dart` (extracted, publishers-only, RTL-positioned Extended FAB).

**Feature: reusable component library** (the atomic vocabulary from §08 — build these so Stages 1–2 just compose them). Create under `lib/core/widgets/ds/` (or extend existing):
- `ds_listing_card.dart` — unified `DsListingCard` with a `mode` enum (`comfortable/balanced/compact`) + `verified/unverified/featured` variants. This supersedes the four divergent cards over Stages 1–2 (reuse geometry from existing `property_card.dart`, but this is a **rewrite** to carry verified/deed/facts slots as nullable — data absent until Stage 3, rendered as stubs).
- `ds_badge.dart` — extend `app_badge.dart`: `verified` (green), `featured` (gold), `notYetVerified` (neutral), `underReview` (amber), transaction pills (للبيع solid / إيجار tint). "One color = one meaning" enforced.
- `ds_filter_chip.dart` — default/selected/selected-removable/verified-only states.
- `ds_toggle.dart` — 48×28 switch, on / verified-on / off.
- `ds_buttons.dart` — primary52 / whatsapp52 / call-outline48 / secondary-neutral48 / disabled / text / icon-button (compose existing `PressScale`).
- `ds_input.dart` — 50px field, default/focus(ring)/error(help)/select-dropdown states.
- `ds_empty_state.dart` — medallion + title + body + CTA.
- `ds_skeleton.dart` — derived from card geometry (image block + 3 text bars, `surfaceVariant→outline` shimmer). Flag offline/error as gaps.

**Reused vs rewritten:** reuse `PressScale`, `AppNetworkImage`, `GlassPill`, `PriceTag`, `FavoriteHeartButton`, `AgencyBadge`, all theme accessors. Rewrite: card (into `DsListingCard`), badge/chip/toggle/input consolidation.

**New ARB keys** (both `app_en.arb`+`app_ar.arb` + `_DebugAppLocalizations` override each):
`nav_search_map` (بحث وخريطة), `nav_messages` (الرسائل). Retire usage of `nav_reels` from the bar (keep the key for the deep page). Reuse existing `home_title`, `favorites_page_title`, `profile_title`, `chatMessagesTile`.

**Migrations:** none.

**On-AVD verification (light/dark × ar/en):**
- Bar shows 5 tabs in correct RTL order; active pill + label bold on each; Chat/Search reachable via `context.go`; Publish FAB appears only for approved publisher, floats above bar, RTL-positioned; Reels tab gone but rail + `/reels` intact.
- Token sweep: Home/Favorites/Profile/Search recolor correctly in all 4 combos; no contrast regressions on captions.
- `dart run tool/lint_design_tokens.dart` exit 0; `flutter analyze` clean; l10n parity script clean.

---

### STAGE 1 — HERO SCREENS

**Feature: home** (`features/home/…`)
- Rewrite compose: `home_page.dart` to the §02 order — top bar (logo tile + city selector + notifications bell w/ unread dot) → NL search bar → transaction segmented control → category chips → optional data-saver strip → featured "مميّز" rail → trust strip → main feed → video-tours rail (`ReelsRail` re-skinned) → FAB.
- New/edited widgets: `home_listing_card.dart` → thin wrapper over `DsListingCard`; `featured_hero_card.dart`/`featured_mini_card.dart` re-skin to gold-badge featured card; add `view_mode_switcher.dart` (the مريح/متوازن/مضغوط toggle button + popover, persisted on-device via existing prefs/cubit — reuse `FilterState.displayMode` pattern, no backend); `home_trust_strip.dart` (stub counts); `city_selector.dart`; re-skin `hero_search_bar.dart`, `property_type_shortcut_row.dart`, `notification_bell_action.dart`.
- Reused: `ReelsRail`, `RecentlyViewedCarousel`. Rewritten: card, featured cards, feed header.

**Feature: search + map** (visual only)
- Edit: `search_page.dart` (parsed-intent chip row scaffold, filter quick-row الفلاتر/الموثّقة فقط/طابو, result header + `inline_sort_control.dart`, view-mode toggle, map switch pill), `search_filter_sheet.dart` (deal-type segmented, location cascade chips, price dual-slider + currency toggle, rooms/baths segmented, **طابو + كسوة chip groups rendered but not yet wired** → live in Stage 3, gated behind a feature flag or shown disabled), toggle rows, footer live-count CTA), `search_result_card.dart` → `DsListingCard(mode: compact)`, `search_map_view.dart` (price-pill markers, draw-area tool *visual affordance only*, data-saver map pill, bottom listing sheet WhatsApp-first). `price_range_input.dart` re-skin.

**Feature: listing detail** (visual; trust block field-verified using existing data, stub rest)
- Edit: `listing_details_page.dart` order per §04 light-authoritative: hero gallery → **green trust block** → price+transaction → key-facts tiles (6; deed/finish tiles show "—"/hidden until Stage 3) → mini-map → agent card (3-stat) → description → similar → in-flow contact block. **Do NOT add sticky bottom CTA** — render `contact_block.dart`/`per_listing_action_block.dart` as the last in-scroll block (already the pattern).
- New widget: `trust_block.dart` (renders whatever verification data exists; site-visit/geotag/freshness bullets stubbed with graceful "غير متوفر" until Stage 3). Re-skin `listing_facts_block.dart`, `contact_block.dart`, `listing_details_skeleton.dart`, `similar_listing_card_tile.dart`, `buyer_safety_banner.dart`, `listing_display/*` blocks.

**New ARB keys** (names): `home_city_selector_label` (تبحث في), `home_featured_section` (إعلانات مميّزة), `home_see_all` (عرض الكل), `home_trust_strip_headline`/`_sub`/`_how` (كيف نوثّق؟), `home_latest_for_sale`, `home_verified_only_pill` (الموثّقة فقط), `home_data_saver_strip`, `home_video_tours` (جولات فيديو), `home_video_on_demand` (تُحمَّل عند الطلب فقط), `view_mode_title` (طريقة العرض), `view_mode_comfortable`/`_balanced`/`_compact` + `_comfortable_desc`/`_balanced_desc`/`_compact_desc`, `search_parsed_intent` (فهمنا طلبك), `search_result_count` (param), `search_verified_first` (الموثّقة تُعرض أولاً), `search_draw_area` (منطقتك المرسومة), `search_data_saver_map`, `map_within_your_area` (param), `map_clear_drawing` (مسح الرسم), `detail_field_verified_title` (إعلان موثّق ميدانياً), `detail_verification_report` (تقرير التوثيق), `detail_site_visit`/`_geotag`/`_identity`/`_freshness` (params), `detail_location_approx` (الموقع تقريبي…), `detail_book_viewing` (حجز معاينة), `detail_deed_label` (الطابو), `detail_finish_label` (الكسوة). Each ⇒ en+ar+override.

**Migrations:** none (Stage 1 uses only existing data; new fields stubbed).

**On-AVD verification:** Home renders all §02 sections in RTL; view-mode switcher cycles 3 modes and persists across restart; featured gold badge exclusive; trust strip present. Search results + filter sheet + map render (طابو/كسوة visible-but-inert). Listing detail order correct, NO sticky bar, trust block degrades gracefully. All in light/dark × ar/en. Lint + analyze + l10n gates green; regen `property_card`/contrast goldens.

---

### STAGE 2 — SECONDARY SCREENS

**Feature: favorites** — re-skin `favorites_page.dart`, `favorite_card.dart` (saved-listing card w/ price-drop chip stub + unavailable scrim state), `favorites_empty_state.dart` → `DsEmptyState`, `favorites_sort_bar.dart`. Add saved-searches section rows (`ds_toggle` alert switch — visual; wiring in Stage 3). ARB: `saved_listings_section` (param), `saved_searches_section` (param), `saved_offline_note`, `saved_price_dropped` (param), `saved_no_longer_available`, `saved_show_similar`, `saved_alerts_on`/`_off` (التنبيهات/صامت).

**Feature: messages** — re-skin `conversations_list_page.dart` (search field, conversation rows w/ presence dot, listing-context chip, unread badge, info banner) + `chat_thread_page.dart` (thread header, pinned listing bar, bubble styles, quick-reply chips, composer, viewing-confirmed card). ARB: `messages_title`, `messages_search_placeholder`, `messages_inapp_note`, `chat_replies_within` (param), `chat_quick_send_location`/`_more_photos`/`_deed_details`, `chat_viewing_confirmed`, `chat_add_reminder`, `chat_composer_placeholder`.

**Feature: notifications** — re-skin `notification_center_page.dart` + `notification_tile.dart` (4 types, unread-highlight border+dot, gold reminder inline actions, day dividers). ARB: `notif_title`, `notif_mark_all_read`, `notif_today`/`_yesterday`, `notif_confirm`/`_reschedule`, type templates.

**Feature: add-listing** — re-skin the wizard to §06 4-step chrome: `listing_form_page.dart`/`step_*.dart`/`step_progress_indicator.dart`/`detail_form_sections.dart`/`media_picker.dart`/`publish_success_dialog.dart`. Step 1 details (deal-type/property-grid/location/price+currency/**طابو chips visual**), Step 2 photos, **Step 3 verification is visual-only shell here** (camera viewfinder mock, geotag/timestamp chips) — real capture in Stage 3, Step 4 review+featured upsell. ARB: `add_step_of` (param), `add_save_draft`, `add_details`/`_photos`/`_verify`/`_review`, `add_deal_type`, `add_property_type`, `add_deed_type`, `add_verify_subtitle`, `add_skip_verification`, `add_publish_free`, `add_featured_upsell` etc.

**Feature: account** — re-skin `profile_page.dart` to §07 cards: profile header (verified-phone pill, KYC prompt), my-listings card (stat tiles + row), preferences (language pill, data-saver toggle, dark-mode picker, notifications), general (trust/help/about+version), logout. ARB: `account_phone_verified`, `account_kyc_prompt`/`_start`, `account_my_listings` (param), `account_active`/`_under_review`/`_views_week` (params), `account_language`, `account_data_saver`/`_desc`, `account_dark_mode`/`_auto`, `account_trust_center`, `account_help`, `account_about`, `account_logout`.

**Feature: auth** — re-skin `login_page.dart`/`register_page.dart` (+`reset_password_page.dart`, status shells, `auth_text_field.dart`, `auth_trust_note.dart`) to §11: brand mark, method segmented (phone/email), phone `+963` prefix, guest CTA, role selector, terms checkbox, WhatsApp-OTP hint. ARB: `auth_welcome_back`, `auth_method_phone`/`_email`, `auth_forgot`, `auth_guest_browse`, `auth_create_account`, `signup_full_name`, `signup_otp_hint`, `signup_role_seeker`/`_owner`, `signup_terms` (rich), `signup_password_hint`.

**Migrations:** none.

**On-AVD verification:** each secondary screen matches its section in light/dark × ar/en; empty/unavailable/skeleton states render; add-listing wizard navigates 4 steps (Step 3 mock); auth flows switch method/role; gates green.

---

### STAGE 3 — NEW BACKEND FEATURES (schema + wiring)

This is where deed/finish/verification become real. **All migrations via Supabase MCP `apply_migration`, one file per logical change, idempotent SQL, verified by reading the file (MCP doesn't dedupe by name).**

**Migrations (ordered):**
1. `add_listing_deed_type` — `deed_type` enum (`green/red/temporary/agricultural/court_ruling`) + column on listings.
2. `add_listing_finish_level` — `finish_level` enum (`on_bone/standard/deluxe/super_deluxe`) + column.
3. `add_listing_verification` — `verification_status` enum (`none/under_review/verified`), `verified_at`, `site_visit_at`, `site_visit_rep`, `geotag_match` bool, `identity_verified` bool, `last_availability_confirmed_at`, plus a `listing_verification_reports` table (report entity for تقرير التوثيق) with GPS-photo metadata (public vs exact coord, capture timestamp, device-camera-only flag).
4. `add_elevator_amenity` — boolean if not already in amenities JSONB.
5. `alter_v_listings_public` — extend the public projection with rooms/baths/area/floor/deed/finish/verified/freshness (currently absent per `search_result_card.dart` doc lines 15–19).
6. `alter_search_listings_rpc` — add `p_deed_type`, `p_finish_level`, `p_verified_only` params; **verified-first ordering** (`ORDER BY verification_status='verified' DESC, …`); pg_get_functiondef BEFORE replace (memory lesson). Watch invoker-view/RLS gotchas.
7. `agent_responsiveness_metric` — derived reply-time aggregate + active-listing count (view or function).
8. `saved_search_alerts` — alert-enabled flag + the query wiring for المحفوظة toggles.
9. Draw-area query — a PostGIS `ST_Contains(polygon, point)` RPC (`listings_within_area`) for the map draw tool.

**Model / filter / datasource edits:**
- `filter_state.dart`: add `deedType`, `finishLevel`, `verifiedOnly` (+ toJson/fromJson/copyWith/props/hasAnyActiveFilter).
- `supabase_search_datasource.dart`: map new `p_*` params (non-null only).
- `search_result_item.dart` + `listing.dart` + `listing_details.dart`: add deed/finish/verified/facts fields.
- `search_filter_sheet.dart`: un-stub طابو/كسوة/الموثّقة-فقط controls.
- `DsListingCard`: light up the verified/deed/finish/freshness slots (stubbed in Stage 0–1).
- `trust_block.dart` + new `verification_report_page.dart` (تقرير التوثيق): render real metadata.
- Add-listing **Step 3 real GPS live-photo capture** (camera-only, gallery-disabled, geotag+timestamp bound) — reuses `media_picker.dart` infra + a new `geotag_camera` service.
- Saved-search alert wiring in `saved_searches_cubit.dart` + notification pipeline.

**New ARB keys:** deed/finish enum labels (طابو أخضر/أحمر/مؤقت/زراعي/حكم محكمة; على العظم/عادية/ديلوكس/سوبر ديلوكس), verification report strings, alert confirmation strings — each en+ar+override.

**On-AVD + on-device verification:** طابو/كسوة/verified-only filters actually filter; verified listings rank first; deed/finish tiles populate on detail; trust block shows real report; Step-3 capture writes geotagged photo (walk on the Infinix Note 8 per memory — capture is performance/hardware-sensitive); saved-search alerts fire. Advisors + structural check post-migration.

---

## PART 4 — RISKS & SEQUENCING

**Merge-contention / high-churn files (touched by nearly every stage):**
- `lib/l10n/app_ar.arb`, `app_en.arb`, and **`lib/core/localization/app_strings.dart`** (`_DebugAppLocalizations`, 6405 lines) — the classic triple-write. Union carefully; missing an `@override` breaks `flutter analyze`. If any of Stages 1–2 are run as parallel `/wave` agents, this file is the guaranteed collision — serialize ARB edits or reconcile in a dedicated merge pass.
- `lib/core/routing/app_router.dart` — Stage 0 (chat route) + Stage 3 (verification-report route). Small, but shared.
- `lib/core/theme/color_palette.dart` / `app_theme.dart` — Stage 0 owns these; later stages must NOT re-touch (keeps the token PR clean).
- `main_bottom_nav.dart` — Stage 0 only.

**What can break the gates:**
- **Token lint (exit 0):** any re-skin that reaches for a raw `Color(0x…)`, inline `TextStyle(`, numeric `EdgeInsets`, `BorderRadius.circular(<number>)`, or inline `BoxShadow`. The new `ds_*` widgets must route everything through accessors + `appRadius`/`appPadding`/`AppElevation`. Run `dart run tool/lint_design_tokens.dart` per commit.
- **l10n parity:** new key in en but not ar (or no override) → analyze fail. Add all three atomically.
- **analyze:** the `MainTab` enum rename is a compile-wide change — all 7 call sites + any `switch (MainTab)` must be exhaustive. Confirmed sites listed; grep `MainTab.` again before commit.
- **Goldens/contrast:** `property_card` + `color_scheme_contrast` WILL change (intended). Regenerate and eyeball the diff; don't let a stale baseline fail CI.
- **Stage 3 SQL:** invoker-view/RLS row-drop, anon EXECUTE grants, RETURNS TABLE OUT-param collisions, pg_get_functiondef-before-replace, REPLICA IDENTITY for filtered Realtime — all per memory. Verify advisors after each migration.

**Keeping each stage shippable:** Stages 0–2 add zero backend dependency — deed/finish/verification render as graceful stubs ("غير متوفر"/hidden), so the app is fully functional and merge-safe at every stage boundary. Stage 3 is the only one gated on migrations; ship it last so a migration hiccup never blocks the visual redesign.

**Is Stage 0 alone a good first PR?** For the CONTRACT (one PR per spec, squash-merged), the whole spec lands as one PR. But Stage 0 as the first *commit series / first reviewable increment* is strongly recommended: it is the highest-leverage, lowest-visual-risk change (tokens + shell + component library), it de-risks every later stage by giving them the vocabulary to compose, and it independently proves the token-lint/analyze/l10n gates stay green. Land it first, then stack Stages 1→3 on the same branch.

---

## PART 5 — FIRST-PR CUT (Stage 0, ordered, executable now)

1. **Branch:** `git checkout -b 035-redesign` off `main`.
2. **Token delta — light:** edit `lib/core/theme/color_palette.dart` `_lightTokens`: `error→0xFFD64545`, `outline→0xFFE4E9F0`, `onSurface→0xFF0B182B`, `onSurfaceVariant→0xFF5B6B80`, `surfaceVariant→0xFFE9EDF3`, `textMuted→0xFF9AA4B2`.
3. **Token delta — dark:** `_darkTokens`: `primary→0xFF4D7CFF`, `surface→0xFF0B182B`, `surfaceVariant→0xFF13233B`, `card→0xFF13233B`, `outline→0xFF22344E`, `onSurfaceVariant→0xFF8FA0B5`, `verified→0xFF4CC08A`.
4. **AA audit:** grep `textMuted` usages; move any readable-content usage to `onSurfaceVariant`. Note findings inline.
5. **Component re-tune:** update `app_theme.dart` (segmented track, chip fill, 1.5px input border, nav) + confirm sheet radius/elevation in `elevation.dart`.
6. **Nav enum:** `main_bottom_nav.dart` line 28 → `enum MainTab { home, search, favorites, chat, profile, none }`.
7. **Nav slots:** swap Reels→Search tab; add Chat tab (auth-gated); remove `_PublishFab` from `slots`.
8. **Extract FAB:** create `lib/core/widgets/publish_fab.dart` (public `PublishFab`, publishers-only `BlocBuilder`, RTL-positioned); delete `_PublishFab` from `main_bottom_nav.dart`.
9. **Router:** `app_router.dart` — add `AppRoutes.chat='/chat'`, `AppRouteNames.chat='chat'`, and the auth-gated `GoRoute` building `ConversationsListPage` in a `ConversationsCubit` provider (mirror favorites 672–678).
10. **Chat tab host:** `conversations_list_page.dart` — add `bottomNavigationBar: MainBottomNav(current: MainTab.chat)`, drawer, and `floatingActionButton: const PublishFab()`.
11. **Call sites:** `reels_tab_page.dart:34`→`MainTab.none`; `search_page.dart:201`→`MainTab.search`; mount `PublishFab` on home/favorites/profile/search/reels hosts; verify favorites/profile/home compile.
12. **Drawer:** `app_nav_drawer.dart` — remove Chat entry (168–182); keep Viewings.
13. **Component library:** create `lib/core/widgets/ds/` — `ds_listing_card.dart`, `ds_badge.dart`, `ds_filter_chip.dart`, `ds_toggle.dart`, `ds_buttons.dart`, `ds_input.dart`, `ds_empty_state.dart`, `ds_skeleton.dart` (all token-clean, nullable verified/deed/facts slots).
14. **l10n:** add `nav_search_map`, `nav_messages` to `app_en.arb` + `app_ar.arb` + `@override` in `_DebugAppLocalizations`.
15. **Gates:** `flutter pub get && flutter gen-l10n`; `dart run tool/lint_design_tokens.dart` (exit 0); `flutter analyze` (clean); l10n parity script.
16. **Baselines:** regenerate `property_card` golden + `color_scheme_contrast`; review the diff (intentional).
17. **AVD walk:** Pixel 8 Pro, `--dart-define-from-file=.env.json`, all 4 combos (light/dark × ar/en) — verify 5-tab RTL order, active states, Chat/Search navigation, publishers-only FAB, Reels-rail intact, recolor everywhere.
18. **Commit** the Stage-0 series (do not push/PR until the user asks; end with a one-line summary per the git-workflow contract).

Key files for execution: `lib/core/theme/color_palette.dart`, `lib/core/theme/app_theme.dart`, `lib/core/theme/elevation.dart`, `lib/core/widgets/main_bottom_nav.dart`, `lib/core/widgets/publish_fab.dart` (new), `lib/core/routing/app_router.dart`, `lib/core/widgets/app_nav_drawer.dart`, `lib/features/chat/presentation/pages/conversations_list_page.dart`, `lib/features/reels/presentation/pages/reels_tab_page.dart`, `lib/features/search/presentation/pages/search_page.dart`, `lib/core/widgets/ds/*` (new), `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`, `lib/core/localization/app_strings.dart`.