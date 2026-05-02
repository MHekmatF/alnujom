# AlNujom Real Estate — Project Blueprint

> **What this is**: the single starting-point document for anyone (human or agent) building the AlNujom Real Estate app from zero. Read this top-to-bottom once, then use it as a navigator into the deeper specs.
> **What this is not**: an authoritative spec. The authoritative specs live at the file paths cited below. This doc tells you *what to read*, *in what order*, and *how the pieces fit*.
> **Audience**: a Flutter engineer (or coding agent) joining the project. Assumes general Flutter/Dart fluency; explains AlNujom-specific decisions inline.

---

## 0. Map of the docs

Everything in `docs/` and `specs/` exists for a reason. Here is what each one is for and when to open it.

| Path | Purpose | When to read |
|---|---|---|
| `.specify/memory/constitution.md` | The **non-negotiable rules**. Every PR is reviewed against these principles. | Before writing any code. Re-read when in doubt. |
| `docs/IMPLEMENTATION_PLAN.md` | The **24-phase roadmap** + locked tech decisions + project framing. | Before starting any new phase. |
| `docs/AI_AGENT_WORKFLOW.md` | The **git workflow contract** — branch naming, PR-per-spec rule, commit/push/merge cadence. | Before opening a PR. Memorize. |
| `docs/decisions/0001-secrets-and-pii-storage.md` | ADR — Supabase Vault is the canonical store for backend secrets and admin-only PII. | When touching anything secret-adjacent (Phase 4+). |
| `docs/design/decision.md` | The **design-direction** decision (A: Luxury vs B: Modern Marketplace). | Before building any UI widget. |
| `docs/design/screens-and-components.md` | **Every screen, every component**, every state. Arabic-first, RTL. | Before building any screen. |
| `docs/design/figma-prompts.md` | Copy-paste prompts for Figma First Draft / Make so designs and code stay in lockstep. | When iterating on visual design. |
| `specs/001-project-foundation/plan.md` | Active spec — the Phase 1 plan. | When working on anything in Phase 1. |
| `specs/001-project-foundation/spec.md` | User stories + functional requirements + clarifications for Phase 1. | Same. |
| `specs/001-project-foundation/contracts/` | Internal interface contracts (`SupabaseClientWrapper`, DI, router, `Result`/`Failure`, `AppLogger`, `PreferencesStore`). | When implementing or consuming any of those interfaces. |
| `specs/001-project-foundation/quickstart.md` | End-to-end verification recipe — does the foundation actually run? | After landing every Phase 1 PR. |
| `CLAUDE.md` | Pointer file Claude Code loads on every session. Tells the agent which spec is active and where the source-of-truth lives. | Always loaded automatically. |

**Plain-language note**: a "spec" is a per-feature folder under `specs/` containing a frozen contract for what that feature does and how it's built. We write the spec first, then the code.

---

## 1. Product overview (10-second pitch)

AlNujom Real Estate (النجوم للعقارات) is an **Arabic-first real-estate marketplace for Syria**, built as a Flutter Android app on top of Supabase. The product serves users (browsers), owners, agents, agencies, moderators, admins, and super admins, and supports listings for **sale**, **rent**, **daily_rent**, and **investment**. Property types covered in v1: apartment, villa, land, shop, office, farm, warehouse, other.

The v1 release is the **full product** — registration, account approval, listing publishing with admin approval, search, filters, map view, contact / inquiry / lead tracking, favorites, reports, agencies, dynamic role/permission management, ads/banners admin module, push notifications, realtime admin signals, and admin dashboard. Delivered in **24 sequenced phases**.

**Explicit non-goals for v1** (so you don't accidentally build them): iOS, Flutter Web, desktop targets, custom (non-Supabase) backend, paid promoted-listing checkout, automatic duplicate detection, auto-translation, payment processing, advanced analytics dashboards.

For the full framing read `docs/IMPLEMENTATION_PLAN.md` §1–3.

---

## 2. Locked technical decisions

Do not relitigate these without an ADR. They are decided.

| Area | Decision | Lives in |
|---|---|---|
| Framework | Flutter (Android only for v1) | IMPLEMENTATION_PLAN §2 |
| Backend | Supabase (source-controlled — schema, migrations, policies, functions, seed all in repo) | Constitution Principle II |
| Auth | Phone + password, with synthetic email `<phone>@alnujom.local` under the hood | IMPLEMENTATION_PLAN §2 |
| Routing | `go_router` | IMPLEMENTATION_PLAN §2 |
| DI | `get_it` + `injectable` (codegen) | IMPLEMENTATION_PLAN §2 |
| Localization | `flutter_localizations` + `intl` + ARB files | IMPLEMENTATION_PLAN §2 |
| State management | BLoC / Cubit | Constitution Principle IV |
| Map provider | `flutter_map` + OpenStreetMap | IMPLEMENTATION_PLAN §2 |
| Distribution | Direct APK + Telegram (Play Store unreliable in Syria; used only for QA testing track) | IMPLEMENTATION_PLAN §2 |
| Secrets / PII | Supabase Vault | ADR-0001 |
| Design palette (default) | "Modern" — primary `#1D4ED8` | screens-and-components.md §2 + §11 |
| Design palette (alternate, swappable at runtime) | "Trust" — primary `#2457A6` | same |
| Typography | Cairo + IBM Plex Sans Arabic + Inter | screens-and-components.md §2.3 + §11 |
| Bottom navigation | 5 tabs (الرئيسية · البحث · إضافة · المفضلة · حسابي) | screens-and-components.md §6 + §11 |

---

## 3. Repository layout

```
H:\alnujom-project\
├── .specify\
│   └── memory\constitution.md         # the rules
├── android\                           # Flutter Android shell
├── ios\                               # not used (Android-only v1) — do not touch
├── assets\
│   ├── fonts\                         # Cairo, IBM Plex Sans Arabic, Inter (Phase 2)
│   ├── icons\                         # any custom SVGs not in Lucide
│   └── images\                        # brand mark, onboarding illustrations, placeholders
├── lib\
│   ├── core\
│   │   ├── theme\                     # tokens (colors, typography, spacing, radii, elevation)
│   │   ├── widgets\                   # the component library — every reusable widget
│   │   ├── routing\                   # go_router config
│   │   ├── di\                        # get_it + injectable wiring
│   │   ├── result\                    # Result<T> / Failure types (see contracts/)
│   │   ├── logger\                    # AppLogger (see contracts/)
│   │   ├── preferences\               # PreferencesStore (see contracts/)
│   │   └── supabase\                  # SupabaseClientWrapper (see contracts/)
│   ├── feature\
│   │   ├── splash\
│   │   ├── onboarding\
│   │   ├── auth\
│   │   ├── home\
│   │   ├── search\
│   │   ├── property_details\
│   │   ├── favorites\
│   │   ├── add_listing\
│   │   ├── my_listings\
│   │   ├── messages\
│   │   ├── notifications\
│   │   ├── profile\
│   │   ├── settings\
│   │   ├── map_view\
│   │   └── office_profile\
│   ├── l10n\                          # ARB files: app_ar.arb (primary), app_en.arb
│   └── main.dart
├── test\                              # mirrors lib\ structure
├── supabase\
│   ├── migrations\                    # versioned SQL — every schema change lands here
│   ├── functions\                     # Edge Functions if any
│   └── seed.sql                       # local dev seed
├── docs\                              # this doc + design + ADRs + workflow
├── specs\                             # one folder per Spec Kit feature
└── pubspec.yaml
```

Each `lib/feature/<name>/` folder follows this internal shape (declared in Phase 2):

```
feature\<name>\
├── data\               # repositories, data sources, DTOs
├── domain\             # entities, use cases, contracts
├── presentation\
│   ├── bloc\           # Cubit / BLoC for the feature
│   ├── widgets\        # widgets specific to this feature (not reusable)
│   └── screens\        # the screen(s) themselves
└── <name>_module.dart  # injectable module wiring
```

---

## 4. Bootstrap steps (zero → running)

> Already done in this repo? Skip ahead. Here for reference and for fresh clones.

### 4.1 Prerequisites

- Flutter SDK (channel: stable, version per `pubspec.yaml` constraint).
- Android SDK + emulator OR a physical Android device (the team's reference is **Infinix Note 8** — Helio G80, 6 GB RAM, Android 10/11).
- Supabase CLI (`npm install -g supabase`).
- A working `git` and access to the GitHub remote.

### 4.2 First run

```powershell
git clone <repo-url>
cd alnujom-project
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs   # generate injectable + freezed code
supabase start                                                     # local Supabase stack on docker
flutter run -d <device-id>
```

If `flutter run` lands you on the Splash → Onboarding → Login flow, the foundation works.

### 4.3 Environment

- `.env` is not used. Configuration goes through `--dart-define` flags wired into `lib/core/config/`.
- Supabase URL + anon key for local dev come from `supabase start` output. For staging/prod they live in CI secrets, never in the repo.

### 4.4 Verifying you're set up

Run the Phase 1 quickstart recipe at `specs/001-project-foundation/quickstart.md`. If every step in that file passes, the foundation is intact.

---

## 5. Design system foundation

Before building any feature widget, the design tokens must be in place. This is **Phase 2** work and gates everything visual.

### 5.1 Tokens (single source of truth)

`lib/core/theme/` will contain:

- `colors.dart` — every color token from `screens-and-components.md` §2, light + dark, both palettes (Modern + Trust). Read into `ColorScheme` for `ThemeData`.
- `typography.dart` — `TextTheme` matching the type scale in §2.3.
- `spacing.dart` — `AppSpacing.xs` … `AppSpacing.xxxl` constants.
- `radii.dart` — `AppRadii.sm` … `AppRadii.pill`.
- `elevation.dart` — shadow definitions per level.
- `app_theme.dart` — assembles `ThemeData` for `light` × `dark` × `palette` (4 combinations: Modern light, Modern dark, Trust light, Trust dark).

**Constitution rule (Principle VI)**: no hex literal may exist in feature code. Always read from the theme. Lint enforces this.

### 5.2 PaletteTester (debug-only)

`lib/core/widgets/palette_tester.dart` contains the runtime palette-cycling chip described in `screens-and-components.md` §5.18. It is gated by a single `kDesignToolsEnabled` const (the same flag that gates the Theme Gallery) which resolves to `false` in release builds — chip and gallery tree-shake together out of production.

### 5.3 Fonts

Vendor under `assets/fonts/`:

- `Cairo-Regular.ttf`, `Cairo-Medium.ttf`, `Cairo-SemiBold.ttf`, `Cairo-Bold.ttf`
- `IBMPlexSansArabic-Regular.ttf`, `IBMPlexSansArabic-Medium.ttf`
- `Inter-Regular.ttf`, `Inter-Medium.ttf`, `Inter-SemiBold.ttf`, `Inter-Bold.ttf`

Declare them all in `pubspec.yaml`. License files (OFL / Apache-2.0) go alongside the font files.

### 5.4 Component library

`lib/core/widgets/` — one component per file, mapping 1:1 to `screens-and-components.md` §5. Build them in this order so screens never block on missing primitives:

1. `app_text.dart` (typography wrapper)
2. `app_button.dart` (Filled / Outlined / Tonal / Text / Destructive variants)
3. `app_text_field.dart` + variants (phone, password, currency, multi-line)
4. `app_chip.dart` (CategoryChip + filter chip)
5. `app_badge.dart` (status badges + Featured ribbon)
6. `app_app_bar.dart` (variants: default, withBack, withSearch, transparentOnImage)
7. `search_field.dart`
8. `location_selector.dart`
9. `property_card.dart` (vertical + horizontal variants)
10. `office_card.dart`
11. `tabs.dart` (segmented control + underline tabs)
12. `stepper_indicator.dart`
13. `image_gallery.dart`
14. `map_preview.dart`
15. `chat_bubble.dart`
16. `price_tag.dart`
17. `empty_state.dart`
18. `bottom_sheet_scaffold.dart`
19. `confirm_dialog.dart`
20. `snackbar_helpers.dart`
21. `palette_tester_chip.dart` (debug-only)

Every component gets a widget test in `test/core/widgets/<component>_test.dart` — golden test for visual regression + interaction tests for state transitions.

---

## 6. Screen build order (24-phase roadmap)

Ordered to maximize "the app feels like an app" early. Each step lands behind a Spec Kit feature spec — no code without a spec.

| Phase | What lands | Reference spec |
|---|---|---|
| 1 | Project foundation: brand-bearing shell, theme switching, locale switching, DI, router, Supabase client wrapper, Result/Failure, AppLogger, PreferencesStore | `specs/001-project-foundation/` |
| 2 | Design system: tokens, fonts, component library scaffolding, PaletteTester | `specs/002-design-system/` (TBD) |
| 3 | Auth: Splash, Onboarding ×3, Login, Register, Pending Approval | `specs/003-auth/` (TBD) |
| 4 | Supabase Vault wiring + admin-only PII paths (per ADR-0001) | TBD |
| 5 | Home screen (anonymous variant) — search bar, categories, featured + latest sections | TBD |
| 6 | Search screen + recent searches | TBD |
| 7 | Search results + filter sheet | TBD |
| 8 | Property Details + image gallery + inquiry sheet | TBD |
| 9 | Favorites | TBD |
| 10 | Authenticated Home variant + sign-in prompts on guest write actions | TBD |
| 11 | Add Listing — multi-step form (Steps 1–3) | TBD |
| 12 | Add Listing — Steps 4–7 (amenities, media, contact, review) | TBD |
| 13 | My Listings + status tabs + per-card menu | TBD |
| 14 | Messages list + Chat detail | TBD |
| 15 | Map view + price-label markers + clustering | TBD |
| 16 | Notifications + push registration | TBD |
| 17 | User Profile + Settings + theme/language/currency pickers | TBD |
| 18 | Office Profile (shared shell + Office extension) | TBD |
| 19 | Lead/inquiry inbox for publishers | TBD |
| 20 | Reports system + report flows | TBD |
| 21 | Realtime admin signals (new listings, new reports) | TBD |
| 22 | Admin dashboard + approval queue + audit log | TBD |
| 23 | Roles & permissions (dynamic, super-admin UI) | TBD |
| 24 | Ads/banners admin module | TBD |

Phases run sequentially. **One PR per spec, not per phase** — see the git workflow contract.

---

## 7. Implementation rules (the "do this / don't do that" list)

These are extracted from the constitution + locked decisions. Memorize them.

### 7.1 Code rules

- **No hex literals in feature code**. Read every color from `Theme.of(context).colorScheme.<role>` or the typed `AppColors` wrapper.
- **No magic numbers for spacing/radii**. Use `AppSpacing.lg`, `AppRadii.md`, etc.
- **No raw strings in widgets**. Every visible string lives in `app_ar.arb` first, then `app_en.arb`. Reference via `AppLocalizations.of(context).<key>`.
- **All directional padding uses `EdgeInsetsDirectional`**. Never `EdgeInsets.only(left:..., right:...)` in feature code. Violates RTL.
- **All alignment uses `AlignmentDirectional`** (`centerStart`, `centerEnd`, etc.) — not `Alignment.centerLeft`.
- **State per screen = sealed class**: `Initial`, `Loading`, `Success(data)`, `Empty`, `Failure(message)`. UI maps 1:1.
- **One widget per file** in `core/widgets/`.
- **Lint must pass** before commit. Pre-commit hook runs `flutter analyze` + `dart format --set-exit-if-changed`.

### 7.2 Backend rules

- **All schema changes are SQL migrations** under `supabase/migrations/`. Never modify the live DB through Studio without a migration to match.
- **RLS policies are mandatory** on every user-writable table.
- **Secrets and admin-only PII go in Supabase Vault** — see ADR-0001. Never in env vars, never in `--dart-define`, never in code.

### 7.3 Git workflow

- One PR per Spec Kit spec (NOT per phase).
- Branch naming: `<###-feature-name>` matching the spec folder.
- Commits are squash-merged on PR merge.
- Every git turn ends with a one-line summary.
- Full contract: `docs/AI_AGENT_WORKFLOW.md`.

### 7.4 Accessibility (every screen)

- Text/icon contrast ≥ 4.5:1 body, 3:1 large text & UI.
- Touch targets ≥ 48 × 48 dp.
- No color-only state signals — color is always paired with an icon or text label.
- Form fields announce label + value + error to screen readers via `Semantics`.
- Test under system text-size 100% / 130% / 200% — nothing clips.
- RTL + LTR widget tests for every layout-bearing widget.

### 7.5 Testing pyramid

- **Unit tests** — every domain entity, every use case, every repository.
- **Widget tests** — every reusable component, golden tests for visuals.
- **Integration tests** — end-to-end flows defined in each spec's `quickstart.md`.
- **Manual smoke** — on the Infinix Note 8 reference device before declaring any feature done. The emulator does not catch font rendering quirks, real-device touch latency, or APK distribution issues.

---

## 8. Verification — how to know each piece is done

| Layer | Done = |
|---|---|
| Token | The token shows up in `Theme.of(context)` AND a widget test renders it under both palettes × both themes. |
| Component | Has its widget test (golden + interaction), is documented in `screens-and-components.md` §5, and is used by at least one screen. |
| Screen | All four states (default, loading, empty, error) render. Passes the §7.4 accessibility checklist. Manual smoke on the Infinix Note 8 hits 60 fps on scroll. |
| Spec | Every functional requirement in `spec.md` has a passing test; every clarification is encoded; `quickstart.md` runs end-to-end. |
| Phase | Every spec in the phase is merged + deployed; the phase's success criteria from `IMPLEMENTATION_PLAN.md` is hit. |

---

## 9. Common gotchas

These are the things that will bite you specifically because of AlNujom's choices.

- **Synthetic emails**: users authenticate by phone, but Supabase Auth requires an email. We synthesize `<phone>@alnujom.local`. Don't display this anywhere — it's an internal identifier, not a real address.
- **No SMS-OTP in v1**: Twilio doesn't reliably serve Syria. Phone verification is gated by **admin approval** instead. Account creation lands users on Pending Approval (§7.5 in screens-and-components.md), not on Home.
- **OpenStreetMap attribution is mandatory**: the map screen MUST display "© OpenStreetMap" — license requirement. Removing it is a license violation, not a UX choice.
- **Play Store is unreliable for Syrian users**: primary distribution is direct APK + Telegram. Don't build features that require Play Store services (e.g., Play Billing, Play Asset Delivery).
- **Cairo at small sizes**: Cairo can look thin at `bodyMedium` (14 dp) on low-density screens. Test on the Infinix Note 8 specifically — body text uses IBM Plex Sans Arabic for exactly this reason.
- **Currency display order**: SYP and USD both shown, primary on top, alternate underneath in muted type. The user's preferred currency wins primary slot.
- **Emoji in icons**: don't. We use Lucide. Emoji renders inconsistently across Android OEM skins (Infinix's XOS in particular).
- **`pumpAndSettle` in widget tests**: avoid it for any animated component — use specific `pump(Duration)` calls so animations don't silently mask bugs.

---

## 10. The single most important file to read next

If you read only one thing after this blueprint:

→ **`.specify/memory/constitution.md`**

It is a 10-minute read. Every PR is reviewed against its principles. Internalize them before writing any code.

After that, in order:

1. `docs/IMPLEMENTATION_PLAN.md` — the 24-phase roadmap.
2. `docs/design/screens-and-components.md` — every screen + every widget.
3. `docs/AI_AGENT_WORKFLOW.md` — git workflow contract.
4. `specs/001-project-foundation/plan.md` — the active phase's plan.

Once those four are in your head, you are ready to ship.

---

## 11. When in doubt

- **Doubt about a design choice** → check `screens-and-components.md`. If it's not there, raise it as an open question; don't invent.
- **Doubt about a tech choice** → check the locked-decisions table in §2 above. If it's not there, check `IMPLEMENTATION_PLAN.md` §2. If still not there, ADR.
- **Doubt about a workflow choice** → `AI_AGENT_WORKFLOW.md`.
- **Doubt about a rule** → constitution. The constitution wins ties.
- **Doubt about whether to build a feature** → check the v1 non-goals list (§1 above + IMPLEMENTATION_PLAN §1). If listed there, don't build it.

---

## 12. Glossary (fast reference)

- **Publisher**: a user (owner, agent, or agency member) approved by an admin to create listings.
- **Listing**: a real-estate offering with a purpose (sale / rent / daily_rent / investment) and a property type.
- **Governorate / City / Area**: the three-tier structured location hierarchy.
- **Role**: a named bundle of permissions (`moderator`, `admin`, `super_admin`) attached to one or more users.
- **Permission**: a fine-grained capability key (`listings.approve`).
- **Audit log**: append-only record of a sensitive action.
- **Synthetic email**: Supabase Auth identifier `<phone>@alnujom.local`.
- **Spec Kit**: our spec-driven workflow — see `.specify/` and `docs/AI_AGENT_WORKFLOW.md`.
- **ADR**: Architecture Decision Record. Lives under `docs/decisions/`.
- **PaletteTester**: a debug-only floating chip that cycles primary palettes at runtime — see `screens-and-components.md` §5.18.

---

This document is a navigator, not a contract. The contracts are the files it points to. Read it, then go read those.
