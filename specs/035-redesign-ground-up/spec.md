# Spec 035 — Ground-Up Redesign (IA restructure + design-system rebuild)

**Status:** in progress (Stage 0 landed). One PR per spec, squash-merged at the end.

## Why

After the token-level restyle (PRs #89/#90/#91) the founder's verdict was that the
problem is the app's **structure / information architecture and widgets**, not the
colours. This spec is a ground-up rebuild against a Claude-Design artifact
(`New design/# Al Nujom – Syrian Real Estate2.zip`), informed by a deep-research
benchmark of the best real-estate apps (global: Zillow/Redfin/Idealista; Arab:
Bayut/Property Finder/OpenSooq; Syria: OpenSooq/AqaarGate/Byoot).

Signature differentiators baked into the design: operator-enforced **field
verification** (Bayut TruCheck-style — site visit + geotagged photo + freshness),
**WhatsApp-first** contact, **Syria-native filters** (deed type طابو، finish الكسوة),
a 3-way **view-mode switcher** (مريح/متوازن/مضغوط), and a **lightweight/data-frugal**
posture.

Full artifact spec + codebase map: [`design-and-codebase-dossier.md`](design-and-codebase-dossier.md).
Full staged plan: [`implementation-plan.md`](implementation-plan.md).

## Target IA (5 tabs + floating publish)

استكشف (Home) · بحث وخريطة (Search+Map) · المحفوظة (Saved) · الرسائل (Messages) ·
حسابي (Account), plus a floating **أضف عقار** Extended FAB (publishers only).
Reels is folded into Home as a video-tours rail (no longer a tab). This replaces
the Phase-030 tabs (home/reels/favorites/profile + in-bar publish FAB).

## Staging (each stage stays analyze-green, token-lint 0, l10n-parity clean)

- **Stage 0 — Foundation** ✅ *(landed)*: token delta + the 5-tab nav shell +
  routing + the floating `PublishFab`. (Component library — the `ds/` widgets —
  will be built alongside Stage 1 where their exact API is known.)
- **Stage 1 — Hero screens**: Home (+ 3-way view-mode switcher) · Search/filters/map
  (visual) · Listing detail (visual, incl. the field-verified trust block; new
  data stubbed). No sticky bottom CTA on detail (standing rule).
- **Stage 2 — Secondary screens**: Saved · Messages · Notifications · Add-listing ·
  Account · Login/Signup.
- **Stage 3 — New backend features**: field-verification flow (status + GPS photo),
  deed-type + finish-level columns + `search_listings` params + verified-first
  ranking, map draw-area query, saved-search alerts. Migrations via Supabase MCP.

## Stage 0 — what changed

**Tokens** (`lib/core/theme/color_palette.dart`, `ModernPalette`): exact-value
nudges to match the DS swatches — light `error/outline/onSurface/onSurfaceVariant/
surfaceVariant`; dark `primary` + navy surfaces (`surface/surfaceVariant/card/
outline/onSurfaceVariant/verified`). `textMuted` deliberately **kept readable**
(the DS reserves steel `#9AA4B2` for placeholder-only; flipping it wholesale would
regress AA — deferred to a per-call-site audit). Existing `color_palette_test`
baselines updated to match.

**Nav / IA**:
- `MainTab { home, reels, favorites, profile, none }` → `{ home, search,
  favorites, chat, profile, none }`.
- `main_bottom_nav.dart` renders five equal tabs; the in-bar `_PublishFab` is
  removed.
- New `lib/core/widgets/publish_fab.dart` — a floating Extended FAB (self-gates to
  approved publishers), mounted on each tab host's `Scaffold.floatingActionButton`.
- `app_router.dart` — new auth-gated `/chat` route (`AppRoutes.chat`).
- `conversations_list_page.dart` — now a first-class tab host (drawer + 5-tab nav +
  publish FAB). The drawer's Messages shortcut routes to `/chat` (dedup).
- New l10n: `nav_search_map` (بحث وخريطة), `nav_messages` (الرسائل).

**Verification**: `flutter analyze` clean (incl. tests); `tool/lint_design_tokens.dart`
exit 0; l10n parity holds (debug overrides present). On-device AVD walk: pending
(to be batched with Stage 1).

## Standing constraints

Arabic-first RTL + light/dark preserved; token-clean (linter exit 0); every ARB key
gets a `_DebugAppLocalizations` override; NO new automated tests (existing baselines
maintained); migrations via Supabase MCP only; do NOT re-add a sticky bottom CTA on
listing details; ONE PR per spec, squash-merge `--admin`.
