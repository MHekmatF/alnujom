I have everything I need. Here is the mapping.

---

# Tier D (Chrome & States) → Flutter code map

Spec source: `H:/alnujom-project/specs/035-redesign-ground-up/dc-handoff-v3/alnujom-real-estate-marketplace/project/AlNujom - Chrome.dc.html` (demo nav groups: `الإطار العام` = splash / onboarding / settings; `المكوّنات المشتركة` = shared states). Four deliverables: **Splash · Onboarding · Settings+About/Support · Shared States**.

Shared reality worth stating up front: the DC "Settings" screen is a **consolidation** of things that today live in three different places — theme is an AppBar action (`theme_toggle_action.dart`), language is an AppBar action (`locale_toggle_action.dart`), data-saver + currency live inside the Profile page's Account card, and About/Support is its own `/about` page. There is **no user-facing settings screen or `/settings` route** today (only the admin-gated `/admin/settings`).

---

## D-1 · شاشة البداية (Splash)

- **Existing file:** `H:/alnujom-project/lib/features/onboarding/presentation/pages/splash_page.dart`
- **Current root:** plain `Scaffold(backgroundColor: Colors.white)` centering `assets/branding/splash_full.png` (full emblem+wordmark artwork), wrapped in `StaggeredListItem`. It is a **redirect gate** — `initState` reads `AuthBloc` + `OnboardingRepository.hasSeenOnboarding()` and `context.go`s to home/pending/rejected/suspended/login/onboarding. Logic must be preserved verbatim.
- **DC target look:** full-bleed brand-blue background (`colors.brandCrown` = `#1A3FC4`/`#12235E`), a centered white 96×96 rounded-square (radius `AppRadii.xl`≈26) holding a filled star glyph tinted brand-blue, `النجوم` 34px/700 white wordmark, subtitle `سوق العقارات الأول في سوريا` in white-80%, and a bottom block: a 150×4 track (white-22%) with an indeterminate fill + `جارٍ التحميل…`. Pulse animation on the logo group.
- **Ordered edits:**
  1. Decide the **white-vs-blue** branding question first (BLOCKING): the current Dart splash is deliberately white to seamlessly hand off from the `flutter_native_splash` white splash. DC wants brand-blue. Either (a) also re-theme the native splash to brand-blue, or (b) keep this Dart splash white and treat DC's blue as art direction only. Do not ship a blue Dart splash over a white native splash (visible flash).
  2. Swap `Scaffold` bg → `colors.brandCrown`; set the system status-bar overlay to the crown color (matches every other DC crown surface).
  3. Replace the single `Image.asset` with the DC lockup: white rounded emblem tile (reuse `BrandMark` if it renders on-brand, else a star `Icon`), wordmark `Text`, subtitle `Text` — all white, tokenized (`AppSpacing`, `AppRadii`, `AppTextStyles`).
  4. Add the bottom progress track + loading label (indeterminate `LinearProgressIndicator` styled to token white, or an `AnimatedContainer`), plus the pulse on the logo group (existing `StaggeredListItem` can stay, or a subtle scale loop).
  5. Keep every navigation branch and the `BlocListener` untouched.
- **Route:** `AppRoutes.splash = '/splash'` (name `splash`), builder at `app_router.dart:316-318`; it is the router `initialLocation` (`app_router.dart:299`). No new route.
- **Effort:** **SMALL** (single screen, no logic change; the only friction is the native-splash coordination in step 1).

---

## D-2 · المقدمة (Onboarding)

- **Existing file:** `H:/alnujom-project/lib/features/onboarding/presentation/pages/onboarding_page.dart` (drives `OnboardingCubit` / `onboarding_state.dart`; slide copy already in ARB: `onboarding_step_{1,2,3}_{title,body}`, `onboarding_skip`, `onboarding_next`, `onboarding_get_started`).
- **Current root:** `Scaffold` with a **full-bleed photo hero** per slide (`assets/onboarding/slide{1,2,3}.jpg`) + a dark gradient scrim + `PageView` + white `BrandMark`/skip bar + headline/body over the scrim + dot indicators + `AppButton.filledPrimary`. Uses `colors.onPhoto` throughout.
- **DC target look:** a completely different, **photo-less** treatment — white `colors.card`/`surface` background, `تخطّي` text button top-start, a centered **150×150 tonal rounded-square** (`colors.tonalButton` bg / `colors.onTonalButton` icon, radius `AppRadii.xxl`≈44) holding a big Material Symbol per slide (`verified` → `forum` → `notifications_active`), title 24/700, body 15 muted, dot row (active dot 24px wide, `colors.primary`), full-width 52px primary pill labeled `التالي` / `ابدأ الآن`.
- **Ordered edits:**
  1. Keep `OnboardingCubit`, the `PageController`, `markSeen()`, `nextStep()`, the `OnboardingDone → context.go(AppRoutes.register)` listener, and the three ARB keys — **all behavior stays**.
  2. Delete the `_SlideBackground`/photo stack and the scrim gradient; set `Scaffold` bg → `colors.card`; drop `colors.onPhoto` (revert text to `colors.textPrimary` / `colors.textMuted`).
  3. Add a per-slide icon to `_StepData` (`verified`, `forum`, `notifications_active`) and render the DC tonal icon tile above the title.
  4. Recolor the active dot to `colors.primary` (currently it already grows the active dot — keep that; just change the inactive from `onPhoto@50%` to `colors.outline`/`textMuted`).
  5. Keep `AppButton.filledPrimary` for the CTA and the existing `stepCounter` semantics.
  6. The `assets/onboarding/slide*.jpg` assets become unused — leave in place, don't remove pubspec entries in this pass.
- **Route:** `AppRoutes.onboarding = '/onboarding'` (name `onboarding`), builder `app_router.dart:321-323`; reached from Splash (`splash_page.dart:54`, when `!hasSeenOnboarding`). No new route.
- **Effort:** **MEDIUM** (visual rebuild of the slide body from hero-photo to icon-card; cubit/routing untouched).

---

## D-3 · الإعدادات + حول والدعم (Settings + About/Support)

- **Existing files (fragments to consolidate):**
  - About/Support surface: `H:/alnujom-project/lib/features/settings/presentation/pages/about_support_page.dart` — plain `Scaffold(AppBar)`, `BlocBuilder<AppSettingsCubit>`, renders support phone/WhatsApp/email (`support_contact_row.dart`) + terms/privacy `_LinkTile`s; already has a good `_SettingsSection` idiom (muted header over a hairline-divided card).
  - Theme control: `H:/alnujom-project/lib/core/widgets/theme_toggle_action.dart` → `ThemeCubit.setMode(AppThemeMode {auto,light,dark})` (`lib/core/theme/theme_cubit.dart`).
  - Language control: `H:/alnujom-project/lib/core/widgets/locale_toggle_action.dart` → `LocaleCubit` (`lib/core/localization/locale_cubit.dart`).
  - Data-saver: `H:/alnujom-project/lib/core/settings/lite_mode.dart` (`LiteMode.notifier` / `set`) — currently a switch row inside `profile_page.dart:143-152`.
  - Currency: `PreferredCurrencyToggle` (hosted in `profile_page.dart:140`).
- **Current root:** none — no unified settings screen exists.
- **This is NEW FILE NEEDED.**
  - Proposed page: `H:/alnujom-project/lib/features/settings/presentation/pages/settings_page.dart`
  - Proposed route: `AppRoutes.settings = '/settings'` (name `settings`), added to `app_router.dart` as a top-level pushable route (sibling to `/about`, anonymous-accessible), and reached from `AppNavDrawer` (`lib/core/widgets/app_nav_drawer.dart` — add a `DrawerRow(الإعدادات)` in the "More" section that currently only holds Reports + About at lines ~193-213).
- **DC target look / ordered edits:**
  1. Adopt **`DcCrownScaffold(title: 'الإعدادات')`** — it already gives the exact DC deep-blue crown → white rounded sheet (`margin-top:-14px`, radius 20). Body = scroll of grouped sections.
  2. **المظهر** section: a segmented pill (`surface2` track, active = white pill with `AppElevation.level1` shadow) with `فاتح / داكن / تلقائي` → `ThemeCubit.setMode(light/dark/auto)`, driven by `context.watch<ThemeCubit>()`. **Build a new shared widget `DcSegmentedControl`** (`lib/core/widgets/dc_segmented_control.dart`) — the identical pill also powers the States showcase tabs (D-4), so extract once.
  3. **عام** section: reuse the `about_support_page.dart` `_SettingsSection` card idiom. Rows: `اللغة` (trailing current language + chevron → `LocaleCubit`), `العملة` (reuse/adapt `PreferredCurrencyToggle` as a row → currency), `توفير البيانات` (toggle → `LiteMode`, `ValueListenableBuilder` on `LiteMode.notifier`, same wiring as the profile row).
  4. **الإشعارات** section: 3 toggles — `عقارات جديدة مطابقة / الرسائل والردود / العروض والتنبيهات التسويقية`. **GAP: no persistence store exists** (grep for notification prefs returns nothing). Add a `LiteMode`-style local singleton `NotificationPrefs` (`lib/core/settings/notification_prefs.dart`) or keep local-only for now; coordinate with `lib/core/notifications` if push suppression should be honored. Flag to founder.
  5. **حول والدعم** section: fold in `about_support_page.dart` — 5 DC rows (`عن تطبيق النجوم`, `تواصل مع الدعم`, `الشروط والأحكام`, `سياسة الخصوصية`, `قيّم التطبيق`). Either (a) render the support/terms/privacy rows inline from `AppSettingsCubit` (omitting unset ones, exactly as `about_support_page` already does), or (b) keep `AboutSupportPage` as the target of an `عن/الدعم` row. Recommend (a) inline so the screen matches DC one-to-one; then `AboutSupportPage` can be retired or kept as a deep-link.
  6. Footer: `النجوم · الإصدار x.y.z` from `PackageInfo` (source already exists: `lib/features/app_update/data/datasources/package_info_version_source.dart`).
  7. New ARB keys needed: settings title, section headers (`المظهر/عام/الإشعارات/حول والدعم`), theme options, the 3 notification labels, `اللغة/العملة/توفير البيانات`, version label — each with a matching `@override` in `lib/core/localization/app_strings.dart` `_DebugAppLocalizations` (analyze fails otherwise).
- **Route:** NEW `/settings`; About stays at `AppRoutes.about = '/about'` (`app_router.dart:167`, builder `:808-810`).
- **Effort:** **LARGE** (new page + new route + drawer entry + segmented-control widget + notification-prefs store + folding About + ~12 ARB keys; individual pieces reuse existing cubits/idioms).

---

## D-4 · الحالات المشتركة (Shared States) — empty / error / loading

This DC screen is a **showcase**, not a shippable route. The real deliverable is the three reusable widgets, which **already exist** and are close to DC:

- **Empty:** `H:/alnujom-project/lib/core/widgets/empty_state.dart` (`EmptyState`) — tinted circle + icon, headline, body, `AppButton` CTA. DC wants the circle in `colors.tonalButton` with `onTonalButton` icon at 84px (current uses `primary@10%`). One token nudge; structure already matches.
- **Error:** `H:/alnujom-project/lib/core/widgets/error_state.dart` (`ErrorState`, variants `defaultState`/`network`) — red-tinted circle + `circle_alert`/`wifi_off`, title, message, retry. DC uses `cloud_off` for the network case and a **filled** primary retry pill; current retry is `AppButtonVariant.outlined`. Small: add a `cloud_off`-style network glyph + switch retry to filled to match DC.
- **Loading:** `H:/alnujom-project/lib/core/widgets/loading_state.dart` (`LoadingState.card/.row/.avatar/.line/.heading`) — token-correct RTL-aware shimmer primitives (already dark/light + reduced-motion safe). DC's loading state is a **listing-card skeleton** (16:10 image shimmer + 3 text lines). `property_card.dart:58` renders `LoadingState.card()` (a plain box) — **not** the DC image+3-lines shape.
- **Ordered edits:**
  1. Nudge `EmptyState` circle tokens to `tonalButton`/`onTonalButton`, size 84 (verify against `AppSpacing`).
  2. Add a `cloud_off` glyph option to `ErrorState.network` and flip the retry to filled-primary to match DC.
  3. Add a composed **`DsListingCardSkeleton`** (in `lib/core/widgets/ds/`, next to `ds_listing_card.dart`) = 16:10 `LoadingState`-shimmer image + three `LoadingState.line` widths (42% / 78% / 60%), so list loading states match the real card. Wire it where lists currently show `LoadingState.card()` (search/home/saved/etc.).
  4. Optionally build the **States gallery** into the existing debug harness `lib/debug/theme_gallery_page.dart` (it already imports shimmer/skeleton) rather than shipping a user route — the DC nav here is a demo tab, not a product screen.
- **Route:** none (no product route; optional debug entry via the existing `/_debug/theme-gallery` = `AppRoutes.themeGallery`, `app_router.dart:815-817`).
- **Effort:** **SMALL** (token alignment of 3 existing widgets + one new `DsListingCardSkeleton` composite).

---

### Cross-cutting notes for the Tier D wave
- Only **D-3 requires a new route** (`/settings`) and a new drawer entry; D-1/D-2 edit files in place; D-4 edits `lib/core/widgets/*` + adds one skeleton.
- **Extract `DcSegmentedControl` once** — shared by D-3 (theme picker) and D-4 (states tabs). Both use the same `surface2` pill-track / white-active-pill idiom (also matches `CrownUnderlineTabs`' sibling in spirit but is a different component).
- **Two decisions to confirm with the founder before coding:** (1) splash white-vs-brand-blue + native-splash coordination (D-1 step 1); (2) whether the 3 notification toggles get a real persistence store or ship local-only (D-3 step 4).
- All new visible strings must land in `app_strings.dart` `_DebugAppLocalizations` as `@override`s alongside the ARB keys (merge-contention file — union carefully in a wave), Western digits throughout.
