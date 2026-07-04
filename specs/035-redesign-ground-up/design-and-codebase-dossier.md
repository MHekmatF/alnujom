## TOKENS

Sources: section "00 · DESIGN TOKENS" (lines 46–133) and the Home light screen (lines 216–335) of `H:\alnujom-project\New design\extracted2\Al Nujom UI.dc.html`. The applied Home-screen values (surface `#F5F7FA`, card `#FFFFFF`, primary `#1F4FE6`, gold `#C2A14D`, verified `#1F7A4D`, favourite `#F4795B`, ink `#0B182B`, steel `#9AA4B2`, border `#E4E9F0`, secondary-text `#5B6B80`) confirm the token table 1:1.

### Colors — Light

| Design token | Hex | Semantic role (from artifact) |
|---|---|---|
| primary | `#1F4FE6` | Royal blue — buttons, active tab, price, links, icons |
| primaryPressed | `#1636A8` | Primary pressed state |
| ink / navy | `#0B182B` | Primary text + dark-mode background |
| steel | `#9AA4B2` | Secondary text, inactive icons, placeholder |
| (slate text) | `#5B6B80` | Caption / secondary label text (used throughout cards) |
| surface | `#F5F7FA` | Screen background |
| card | `#FFFFFF` | Cards + bottom sheets |
| verified | `#1F7A4D` | "موثّق" Verified badge (exclusive) |
| whatsapp | `#1DAB61` | WhatsApp button (exclusive) |
| featuredGold | `#C2A14D` | "مميّز" Featured badge (exclusive, nothing else) |
| favourite | `#F4795B` | Favourite heart / notification dot |
| error | `#D64545` | Errors + delete |
| border | `#E4E9F0` | Borders + dividers |
| segmented track | `#E9EDF3` | Inactive segmented-control track (Home) |

### Colors — Dark

| Design token | Hex | Role |
|---|---|---|
| dark.bg | `#0B182B` | Dark background |
| dark.card | `#13233B` | Dark card / elevated surface |
| dark.border | `#22344E` | Dark border |
| dark.primary | `#4D7CFF` | Dark primary accent |
| dark.muted | `#8FA0B5` | Dark secondary text |
| dark.verified | `#4CC08A` | Dark verified badge |
| dark.on-surface (implied) | `#EAF0F8` | Dark primary text (from frame body) |

### Type (Tajawal — `GoogleFonts.tajawal()`)

| Style | Size / Weight / Line-height |
|---|---|
| display | 28 / 900 / 1.3 |
| headline | 22 / 800 |
| title | 17 / 700 |
| body | 15 / 500 / 1.7 |
| caption | 13 / 500 (`#5B6B80`) |
| label (badge / bottom-nav) | 11 / 700 |

Notes: Eastern-Arabic numerals (٠١٢٣٤٥٦٧٨٩) app-wide; min text 11px; min touch target 44×44.

### Spacing (4pt grid)

| Token | px | Use |
|---|---|---|
| xs | 4 | icon↔text |
| sm | 8 | chip gap |
| md | 12 | in-card / card gap |
| lg | 16 | screen margin |
| xl | 24 | section gap |
| 2xl | 32 | hero gap |

Fixed: screen margin 16, card gap 12, primary button height 52, secondary button height 44.

### Radii

| Token | px |
|---|---|
| input | 8 |
| tile | 12 |
| card | 16 |
| sheet | 24 |
| chip / pill | 999 |

### Shadows / Elevation

| Token | Value |
|---|---|
| card | `0 2px 8px rgba(11,24,43,.07)` (ink @ 7%) |
| raised / FAB | `0 8px 24px rgba(11,24,43,.12)` (ink @ 12%) |
| bottom sheet | `0 -8px 32px rgba(11,24,43,.14)` (ink @ 14%) |
| input (Home search) | `0 2px 8px rgba(11,24,43,.05)` |
| primary-button glow (Home) | `0 2px 8px rgba(31,79,230,.35)` |

### Gradients

No gradients in the operational UI (only logo + splash). Photo placeholders in the mock use `linear-gradient(140deg,#D9E2EE,#BECCDE)` — decorative image stand-ins, not tokens.

---

## Token mapping → `lib/core/theme/color_palette.dart` (`ModernPalette`)

Legend: MATCH = current value equals the design (or is an intentional AA-tuned equivalent); CHANGE = differs and should become the design value.

### Light (`_lightTokens`)

| AppPaletteTokens field | Design token | Current value | Status / Action |
|---|---|---|---|
| primary | primary `#1F4FE6` | `#1F4FE6` | MATCH |
| onPrimary | (white on primary) | `#FFFFFF` | MATCH |
| primaryContainer | (blue tint) | `#DCE6FB` | MATCH — no explicit design token; current tint is fine (design has no container swatch) |
| accent | favourite `#F4795B` | `#F4795B` | MATCH |
| tertiary | featuredGold `#C2A14D` | `#C2A14D` | MATCH |
| success | (green trust) | `#2E9E6B` | ~MATCH — design has no separate "success"; nearest is verified `#1F7A4D`/whatsapp `#1DAB61`. Current AA green is acceptable; optionally align to `#1DAB61`. No change required. |
| warning | (none in design) | `#C98318` | KEEP — no design token; leave as-is |
| error | error `#D64545` | `#D23F3F` | CHANGE → `#D64545` (design error). Very close; align for exactness. |
| surface | surface `#F5F7FA` | `#F5F7FA` | MATCH |
| surfaceVariant | (subtle fill / segmented track `#E9EDF3`) | `#EAEFF5` | ~MATCH — near design `#E9EDF3`/`#EAEFF5`; optionally set to `#E9EDF3` to match the segmented track exactly. Low priority. |
| card | card `#FFFFFF` | `#FFFFFF` | MATCH |
| outline | border `#E4E9F0` | `#E2E8F0` | CHANGE → `#E4E9F0` (design border). Nearly identical; align for exactness. |
| outlineStrong | (stronger divider) | `#CBD5E1` | KEEP — no explicit design token; current slate-300 is a reasonable stronger border |
| onSurface | ink/navy `#0B182B` | `#0F172A` | CHANGE → `#0B182B` (design ink). Current is slate-900; design ink is a hair deeper/bluer. Align for exactness. |
| onSurfaceVariant | slate text `#5B6B80` | `#475569` | CHANGE → `#5B6B80` (design secondary/caption text). Current is darker slate-600; design uses `#5B6B80`. |
| textMuted | steel `#9AA4B2` | `#64748B` | CHANGE → `#9AA4B2` (design steel — inactive icons/placeholder). Current slate-500 is notably darker; design's steel is lighter. (Verify AA: `#9AA4B2` on `#F5F7FA` ≈ 2.4:1 — fine for large/decorative/placeholder, but if `textMuted` is used for readable body-secondary text keep the darker value or use `#5B6B80`. Design itself uses `#9AA4B2` only for placeholder/inactive.) |
| verified | verified `#1F7A4D` | `#1F7A4D` | MATCH |
| verifiedContainer | (verified tint — design uses `rgba(31,122,77,.08)`) | `#DCF0E5` | MATCH — current opaque tint is a valid equivalent of the design's 8% green wash |
| whatsapp (not in listed set but present) | whatsapp `#1DAB61` | `#1DAB61` | MATCH |

### Dark (`_darkTokens`)

| AppPaletteTokens field | Design token | Current value | Status / Action |
|---|---|---|---|
| primary | dark.primary `#4D7CFF` | `#5896FF` | CHANGE → `#4D7CFF` to match design (current azure is brighter/more saturated). Optional — current is an intentional AA glow accent; both read as bright blue. |
| accent | favourite (dark) | `#FF8E72` | KEEP — design gives no dark favourite; current warm coral is a reasonable dark-mode lift of `#F4795B` |
| tertiary | featuredGold (dark) | `#D9B86A` | KEEP — design has no dark gold swatch; current is a valid dark lift of `#C2A14D` |
| surface | dark.bg `#0B182B` | `#0B1020` | CHANGE → `#0B182B` (design dark background). Current is a cooler/darker midnight; design's is a navy `#0B182B`. |
| surfaceVariant | dark.card `#13233B` | `#161C2D` | CHANGE → `#13233B` (design dark card). |
| card | dark.card `#13233B` | `#161C2D` | CHANGE → `#13233B` (design dark card). |
| outline | dark.border `#22344E` | `#252E44` | CHANGE → `#22344E` (design dark border). Close; align. |
| outlineStrong | (none) | `#38446A` | KEEP |
| onSurface | dark text `#EAF0F8` | `#EAF0FB` | ~MATCH — `#EAF0FB` vs design `#EAF0F8`; effectively identical, optional align. |
| onSurfaceVariant | dark.muted `#8FA0B5` | `#9FABC4` | CHANGE → `#8FA0B5` (design dark muted) for exactness; current is slightly lighter/bluer. |
| textMuted | dark.muted `#8FA0B5` | `#8694AC` | ~MATCH → optionally `#8FA0B5`; current is very close. |
| verified | dark.verified `#4CC08A` | `#57C48C` | CHANGE → `#4CC08A` (design dark verified). Close; align. |
| verifiedContainer | (dark verified wash) | `#163A2A` | KEEP — no design token; reasonable dark green tint |
| error | (dark error) | `#F0706E` | KEEP — design gives only light error `#D64545`; current dark lift is fine |
| whatsapp | (dark) | `#25D366` | KEEP — brand green, no design dark token |

### Net summary
- Already correct (no change): primary, onPrimary, accent, tertiary, surface(light), card(light), verified(light), whatsapp — the load-bearing brand hues are exact.
- Exactness nudges (tiny deltas, align if pursuing 1:1): `error` `#D23F3F→#D64545`, `outline` `#E2E8F0→#E4E9F0`, `onSurface` `#0F172A→#0B182B`, `onSurfaceVariant` `#475569→#5B6B80`.
- Meaningful light change: `textMuted` `#64748B→#9AA4B2` (design "steel") — but confirm each `textMuted` usage still passes AA for readable text; the design reserves `#9AA4B2` for placeholder/inactive only and uses `#5B6B80` for readable captions.
- Dark surfaces drift most: `surface #0B1020→#0B182B`, `card/surfaceVariant #161C2D→#13233B`, `outline #252E44→#22344E`, plus minor `primary`, `onSurfaceVariant`, `verified` nudges to match the dark swatch row (lines 77–82).
- Not in design (keep as-is): `warning`, `outlineStrong`, all dark `accent`/`tertiary`/`error` lifts, `verifiedContainer`.

Palette file: `H:\alnujom-project\lib\core\theme\color_palette.dart` (`ModernPalette._lightTokens` lines 95–130, `_darkTokens` lines 138–169).

---

## HOME + VIEW-SWITCHER

Precise component-level spec, extracted verbatim from section 02 (Home, lines 216–566) and section 10 (View-mode switcher, lines 2143–2428). Frame width is 392px outer / ~368px inner content. Standard horizontal content padding is 16px (`padding:… 16px …`). Colors are given as light / dark pairs.

---

### GLOBAL FRAME
- Phone bezel: `background:#05080D; border-radius:56px; padding:12px` with `box-shadow:0 40px 80px rgba(0,0,0,.5)`.
- Inner screen: `border-radius:46px; overflow:hidden`, `dir="rtl"`, vertical flex column. Surface = `#F5F7FA` (light) / `#0B182B` (dark).
- Status bar: 48px tall, `padding:0 28px`, time `٩:٤١` at 15px/700 right; signal+wifi+battery(rotated 90°) icons left. Text color `#0B182B` / `#EAF0F8`.

---

### 1 · TOP BAR (logo + city selector + notifications bell)
Row: `padding:8px 16px 4px`, `gap:10px`, vertically centered.
- **Logo tile:** 38×38, `border-radius:12px`, bg `#1F4FE6` / `#4D7CFF`; centered filled `star_rate` icon 22px white.
- **City selector** (column, gap:0):
  - Line 1 label `تبحث في` — 11px/500, `#9AA4B2` / `#8FA0B5`.
  - Line 2 row (gap:4px): city `دمشق وريفها` 16px/800 `#0B182B`/`#EAF0F8` + `keyboard_arrow_down` 18px accent (`#1F4FE6`/`#4D7CFF`).
- **Spacer:** `flex:1`.
- **Notifications bell:** 44×44, `border-radius:14px`, bg `#FFFFFF`/`#13233B`, `border:1px solid #E4E9F0`/`#22344E`; `notifications` icon 22px `#0B182B`/`#EAF0F8`. Unread dot: absolute `top:9px; left:10px`, 8×8, `border-radius:99px`, bg `#F4795B`, `border:1.5px solid` matching bg (white/`#13233B`).

---

### 2 · NL SEARCH BAR
Wrapper `padding:8px 16px 0`. Field: height 52px, bg `#FFFFFF`/`#13233B`, `border:1.5px solid #E4E9F0`/`#22344E`, `border-radius:16px`, `padding:0 14px`, `gap:10px`, light-only shadow `0 2px 8px rgba(11,24,43,.05)`.
- Leading `search` icon 22px accent (`#1F4FE6`/`#4D7CFF`).
- Placeholder (flex:1) `جرّب: «شقة بدمشق تحت ١٠٠ ألف دولار»` 14px/500 `#9AA4B2`/`#8FA0B5`.
- Trailing `mic` icon 22px `#9AA4B2`/`#8FA0B5`.

---

### 3 · TRANSACTION-MODE SEGMENTED CONTROL
Wrapper `padding:12px 16px 0`. Track: height 44px, `border-radius:999px`, `padding:4px`, `gap:4px`, `white-space:nowrap`. Track bg `#E9EDF3` (light) / `#13233B` with `border:1px solid #22344E` (dark).
- Three pill segments:
  - **للبيع** (active) — `flex:1`, bg `#1F4FE6`/`#4D7CFF`, text white 14px/**800**, light shadow `0 2px 8px rgba(31,79,230,.35)`.
  - **إيجار سنوي** — `flex:1`, no bg, text `#5B6B80`/`#8FA0B5` 14px/700.
  - **إيجار شهري/يومي** — `flex:1.2` (wider to fit), text `#5B6B80`/`#8FA0B5` 14px/700.

---

### 4 · CATEGORY CHIPS
Row `padding:12px 16px 0`, `gap:8px`, horizontal scroll (`overflow:hidden`). Each chip `flex:none`, `padding:9px 16px`, `border-radius:999px`, 13px/700, `white-space:nowrap`.
- **الكل** (active): bg `#0B182B` (light) / `#EAF0F8` (dark), inverted text (white / `#0B182B`).
- Others (**شقق، منازل عربية، فيلات، أراضٍ، محلات**): bg `#FFFFFF`/`#13233B`, `border:1px solid #E4E9F0`/`#22344E`, text `#5B6B80`/`#8FA0B5`. (Dark mock shows one fewer chip — محلات omitted, non-load-bearing.)

Note — a **data-saver strip** sits between chips and the featured rail (`margin:12px 16px 0`): tinted accent panel `rgba(31,79,230,.07)` / `rgba(77,124,255,.1)`, `border-radius:12px`, `padding:9px 12px`; `data_saver_on` icon 18px, text `وضع توفير البيانات مفعّل — صورة واحدة لكل إعلان` 12.5px/700 accent, trailing underlined `إدارة` action.

---

### 5 · FEATURED "مميّز" ROW (gold)
Section header `padding:20px 16px 10px`, space-between:
- Left group (gap:8px): filled `workspace_premium` icon 20px **gold `#C2A14D`** + title `إعلانات مميّزة` 17px/800.
- Right: `عرض الكل` 13px/700 accent.
Rail: `padding:0 16px`, `gap:12px`, horizontal (`overflow:hidden`).
- **Featured card:** `flex:none`, **width 250px**, bg `#FFFFFF`/`#13233B` (+dark border `#22344E`), `border-radius:16px`, light shadow `0 2px 8px rgba(11,24,43,.07)`.
  - Image: **height 130px**, gradient placeholder.
  - **Gold "مميّز" badge:** absolute `top:10px; right:10px`, bg `#C2A14D`, white, `border-radius:999px`, `padding:4px 10px`, 11px/800, filled `workspace_premium` 13px + text.
  - **"موثّق" badge** (when verified): absolute `bottom:10px; right:10px`, bg green `#1F7A4D`, white, same pill metrics, filled `verified` 13px + text.
  - Body `padding:12px 14px`, gap:4px: price 17px/900; title 13.5px/700; meta (`ريف دمشق · ٤٠٠ م² · ٥ غرف`) 12px/500 `#9AA4B2`/`#8FA0B5`.

---

### 6 · TRUST STRIP
`margin:16px 16px 0`, green-tinted panel `rgba(31,122,77,.08)` / `rgba(76,192,138,.08)`, `border:1px solid rgba(31,122,77,.2)`/`rgba(76,192,138,.25)`, `border-radius:14px`, `padding:12px 14px`, `gap:10px`.
- Filled `shield` icon 24px green `#1F7A4D`/`#4CC08A`.
- Two-line block (flex:1): headline `١٬٢٤٠ إعلاناً وُثّق ميدانياً هذا الشهر` 13.5px/800 green; sub `زيارة موقع + صورة حيّة بالإحداثيات + ختم حداثة` 12px/500 `#5B6B80`/`#8FA0B5`.
- Trailing underlined `كيف نوثّق؟` 12.5px/700 green.

---

### 7 · MAIN LISTING FEED
Feed header `padding:20px 16px 10px`, space-between:
- Title `أحدث العقارات للبيع` 17px/800.
- **"الموثّقة فقط" filter pill:** bg `#FFFFFF`/`rgba(76,192,138,.1)`, `border:1px solid #1F7A4D`/`#4CC08A`, `border-radius:999px`, `padding:6px 12px`; filled `verified` 16px + text 12.5px/800 green.

**Verified listing card** (`margin:0 16px`, bg card, `border-radius:16px`, shadow `0 2px 8px rgba(11,24,43,.07)`):
- **Image height 190px**. Overlays:
  - Top-right badge cluster (`gap:6px`): green **موثّق** pill (`padding:5px 11px`, 11.5px/800, filled `verified` 14px) + blue **للبيع** transaction pill (bg `#1F4FE6`/`#4D7CFF`).
  - Top-left favorite: 36×36 circle, bg `rgba(255,255,255,.94)`/`rgba(11,24,43,.78)`, filled `favorite` 20px coral `#F4795B` (saved).
  - Bottom-right freshness pill: `rgba(11,24,43,.72)`, white 11px/700, `schedule` icon + `تم التأكد من توفّرها قبل ٣ أيام`, `backdrop-filter:blur(4px)`.
  - Bottom-left photo-count pill (light only): `photo_library` icon + `٨`.
- Body `padding:14px`, gap:8px:
  - Price row (baseline, gap:8px): `١٢٥٬٠٠٠ $` 21px/900 + secondary `≈ ١٫٦ مليار ل.س` 12px/500.
  - Title 15.5px/700, line-height 1.5.
  - Location row: `location_on` 16px + `المزة فيلات غربية، دمشق` 13px/500 `#9AA4B2`.
  - **Specs strip:** `padding:9px 0`, top+bottom `1px solid #EEF1F6`/`#22344E`, gap:14px, color `#5B6B80`/`#8FA0B5`; four items each icon 18px + 12.5px/700: `bed`→٣ غرف, `bathtub`→حمامان, `straighten`→١٤٥ م², `stairs`→ط ٤.
  - **Agent row** (gap:10px): 34×34 circle avatar (`person` icon); name column — `مكتب الشام العقاري` 13px/800 + filled green `verified` 15px, sub `يرد عادة خلال ساعة` 11.5px/700 green; then two action buttons:
    - **WhatsApp/chat:** 44×44, `border-radius:14px`, bg `#1DAB61`, filled `chat` icon 22px white, shadow `0 4px 12px rgba(29,171,97,.3)`.
    - **Call:** 44×44, `border-radius:14px`, bg white/transparent, `border:1.5px solid #1F4FE6`/`#4D7CFF`, filled `call` icon 21px accent.

**Unverified listing card** (light mock, `margin:16px 16px 0`):
- **Image height 150px**. Top-right badge = neutral `غير موثّق بعد` (bg `#E9EDF3`, text `#5B6B80`, `border:1px solid #D4DBE4`, `help` icon). Favorite icon unfilled/grey `#9AA4B2`.
- Body: price 21px/900 (no LS secondary); title 15.5px/700; location+age `جرمانا، ريف دمشق · أُضيف قبل ٥ ساعات`.
- **Caution note:** `background:#F5F7FA`, `border:1px dashed #D4DBE4`, `border-radius:10px`, `padding:8px 12px`; `info` icon 17px + `لم تتم زيارته بعد — يظهر بعد الإعلانات الموثّقة. عايِن قبل دفع أي عربون.` 11.5px/700 line-height 1.6. (Establishes ranking rule: unverified sinks below verified.)

---

### 8 · "جولات فيديو" VIDEO-TOURS RAIL (Reels folded into Home)
Sits **between** the verified and unverified cards. Header `padding:20px 16px 10px`, space-between:
- Left (gap:8px): filled `play_circle` icon 20px accent `#1F4FE6`/`#4D7CFF` + title `جولات فيديو` 17px/800.
- Right badge: `تُحمَّل عند الطلب فقط` 11.5px/700 `#9AA4B2`, bg `#E9EDF3`, `border-radius:999px`, `padding:4px 10px`. (Bandwidth-conscious: videos load on demand only.)
Rail `padding:0 16px`, `gap:12px`, horizontal.
- **Video thumb:** `flex:none`, **200×118**, `border-radius:14px`, dark gradient bg.
  - Center play button: 42×42 circle `rgba(255,255,255,.92)`, filled `play_arrow` 24px `#0B182B`.
  - Bottom-right caption (`منزل عربي — باب توما`) 11.5px/700 white with text-shadow.
  - Top-left meta chip `dir="ltr"`: `rgba(11,24,43,.7)`, white 10.5px/700, `border-radius:6px`, `padding:2px 7px`, format `١:٢٤ · ٦ MB` (duration + file size).

---

### 9 · أضف عقار PUBLISH FAB
Absolute `bottom:110px; left:16px` (sits above the bottom nav on the RTL-left side). Height 52px, `border-radius:16px`, bg `#1F4FE6`/`#4D7CFF`, `padding:0 18px`, `gap:8px`, shadow `0 12px 28px rgba(31,79,230,.42)`/`(…,.5)`. `add_home` icon 22px + label `أضف عقار` 15px/800 white. This is the publish action (distinct from the 5 nav tabs).

---

### 10 · BOTTOM NAV (5 tabs)
Bar `flex:none`, bg `#FFFFFF`/`#0E1D33`, `border-top:1px solid #E4E9F0`/`#22344E`, `padding:10px 8px 26px` (26px bottom = safe-area). Five equal `flex:1` items, each a column (gap:3px): a 56×30 icon pill + 11px label.
- **استكشف** (active): pill bg `rgba(31,79,230,.12)`/`rgba(77,124,255,.18)`, filled `home` icon 22px accent (`#1F4FE6`/`#7C9BFF`), label 800 accent.
- **بحث وخريطة:** `travel_explore` icon, grey `#9AA4B2`/`#8FA0B5`, label 700.
- **المحفوظة:** `favorite` icon, grey.
- **الرسائل:** `chat_bubble` icon, grey; **badge** absolute `top:2px; left:10px`, min-width 16px / height 16px, `border-radius:99px`, bg `#F4795B`, white 10px/800, value `٢`.
- **حسابي:** `person` icon, grey.

Inactive icons use no pill (plain 56×30 flex box); only the active tab has the tinted pill.

---
---

## 10 · VIEW-MODE SWITCHER (مبدّل طريقة العرض)

**Concept (from intro copy, line 2150):** a small toggle button sits **above the listings feed** on both Home and Search results. It opens a choice of 3 modes for the *same* list — **مريح** (comfortable), **متوازن** (balanced, current default), **مضغوط** (compact + WhatsApp per row). Selection is **persisted on-device**.

### The toggle control (in feed header)
Feed header row: `padding:12px 16px 10px`, `gap:8px`. Contains three items — title (flex:1) + "الموثّقة فقط" pill + the **mode toggle button** (right end):
- Button: **40×40**, `border-radius:12px`, `flex:none`.
- **Active/open state** (Balanced mock): bg `#1F4FE6` filled, white icon, shadow `0 4px 12px rgba(31,79,230,.35)`.
- **Idle state** (Comfortable & Compact mocks): bg `#FFFFFF`, `border:1.5px solid #1F4FE6`, accent icon.
- **Icon reflects current mode:** `view_agenda` (comfortable) / `view_day` (balanced) / `view_list` (compact), 20px.

### The switcher popover (menu open — shown in Balanced mock)
Absolute `top:112px; left:16px; z-index:5`, **width 230px**, bg `#FFFFFF`, `border:1px solid #E4E9F0`, `border-radius:16px`, shadow `0 20px 48px rgba(11,24,43,.25)`, `overflow:hidden`.
- Header label `طريقة العرض` `padding:11px 14px 7px`, 11.5px/800 `#9AA4B2`.
- Three rows, each `padding:11px 14px`, `gap:10px`: leading icon 20px + two-line label block (title 13.5px/800 + description 11px/500 `#9AA4B2`).
  - **مريح** — `view_agenda` icon `#5B6B80`, desc `صور كبيرة ومساحات واسعة`.
  - **متوازن** (selected) — row bg `rgba(31,79,230,.07)`, `view_day` icon + title in accent `#1F4FE6`, desc `الوضع الافتراضي`, trailing `check` icon 19px accent.
  - **مضغوط** — `view_list` icon `#5B6B80`, desc `صفوف كثيفة + واتساب`.

---

### MODE 1 — مريح (Comfortable): photo-first, airy
"صورة كاملة العرض، معلومة واحدة في السطر." Cards are **full content-width** (not the 250px rail card), stacked with generous spacing.
- Card wrapper: `padding:4px 18px 0` (first) then `20px 18px 0`, column, `gap:10px`. Note **18px** side padding (wider than the standard 16px).
- **Image: height 216px** (largest of all modes), `border-radius:20px`, full-bleed, `overflow:hidden`.
  - **موثّق badge:** absolute `top:14px; right:14px`, green `#1F7A4D`, `padding:6px 12px`, 11.5px/800, filled `verified` 14px + text (`موثّق قبل ٣ أيام` on verified card).
  - **Featured card badge cluster** (top-right, gap:6px): **gold مميّز** pill (`#C2A14D`, `workspace_premium` 14px) **then** green **موثّق** pill — both `padding:6px 12px`.
  - **Favorite:** absolute `top:14px; left:14px`, 38×38 circle `rgba(255,255,255,.95)`, filled `favorite` 20px — coral `#F4795B` (saved) / grey `#9AA4B2` (unsaved).
  - **Photo-dots indicator** (verified card): absolute `bottom:14px`, centered (`right:50%; translateX(50%)`), 3 dots — active 16×5 white bar + two 5×5 `rgba(255,255,255,.6)` dots.
- Text block `padding:0 2px`, gap:3px:
  - Row (baseline, **space-between**): title 16px/800 on the **right**, price 17px/900 on the **left**.
  - Meta line 13px/500 `#9AA4B2` (`دمشق · ١٤٥ م² · طابو أخضر`).
- No specs strip, no agent row, no contact buttons — deliberately minimal (one info line).

### MODE 2 — متوازن (Balanced): the current default
This is the exact Home card from section 02, at slightly reduced image heights.
- Card `margin:4px 16px 0` (first) / `14px 16px 0`, bg `#FFFFFF`, `border-radius:16px`, shadow `0 2px 8px rgba(11,24,43,.07)`. Standard **16px** side margin.
- **Verified card image: height 180px** (vs Home's 190px). Overlay set identical to Home verified card:
  - Top-right cluster: green **موثّق** pill + blue **للبيع** pill (`padding:5px 11px`, 11.5px/800).
  - Top-left favorite 36×36 coral filled.
  - Bottom-right freshness pill `تم التأكد من توفّرها قبل ٣ أيام`.
- Body `padding:14px`, gap:8px: price 21px/900 + `≈ ١٫٦ مليار ل.س`; title 15.5px/700; location row; **full specs strip** (bed/bathtub/straighten/stairs, `1px solid #EEF1F6` top+bottom); **full agent row** with 34×34 avatar + name+verified + `يرد عادة خلال ساعة` + 44×44 WhatsApp (`#1DAB61`) + 44×44 call (accent outline).
- **Featured card image: height 150px** (shorter). Badge cluster top-right = **gold مميّز** + green **موثّق** (`padding:5px 11px`). Body `padding:14px`, gap:6px: price 21px/900 + `٨٠٩ $/م²`; title 15.5px/700; location. (Abbreviated — no specs strip/agent row on the featured card.)

### MODE 3 — مضغوط (Compact): dense rows + WhatsApp per row
"معلومات أكثر في الصف الواحد وزر واتساب دائم… أوفر للبيانات." Horizontal rows, image on the RTL-right, text center, action column on the RTL-left.
- Row wrapper: `margin:4px 12px 0` (first) / `10px 12px 0`, bg `#FFFFFF`, `border-radius:14px`, shadow `0 2px 8px rgba(11,24,43,.07)`, **`display:flex`** (horizontal). Note tighter **12px** side margin.
- **Thumbnail:** **width 110px**, `align-self:stretch` (full row height), `flex:none`, gradient bg.
  - **Single badge** top-right `top:8px; right:8px`, small pill `padding:2px 8px`, 9.5px/800, `border-radius:999px`:
    - Verified → green `#1F7A4D` `موثّق` (filled `verified` 11px).
    - Featured → **gold `#C2A14D` `مميّز`** (filled `workspace_premium` 11px). *(In compact, مميّز and موثّق do not stack — only the primary badge shows; the موثّق state for a featured row is instead noted inline in the status line, e.g. `… · موثّق ✓`.)*
    - Unverified → neutral `#E9EDF3` / text `#5B6B80` `غير موثّق`.
  - No favorite/photo-count overlay on the thumbnail (favorite moves to the action column).
- **Content column** (flex:1, `padding:10px 12px`, gap:3px, `min-width:0` for truncation):
  - Price row (baseline, gap:6px): price 16px/900 + secondary 10.5px/700 `#9AA4B2` (`$/م²` for sale, or `شهرياً` for rentals).
  - Title 12.5px/800 (single line).
  - Meta line 11px/500 `#9AA4B2`, packs more fields inline: `المزة، دمشق · ٣ غرف · ١٤٥ م² · ط ٤`.
  - **Status micro-line** (gap:4px): icon 12px + text 10px/700 — verified→green `schedule` + `تم التأكد قبل ٣ أيام`; unverified→grey `help` + `لم يُوثّق — عايِن قبل أي عربون`; rental→`تم التأكد قبل يومين`.
- **Action column** (`flex-direction:column`, centered, gap:6px, `padding:0 10px 0 12px`, `border-right:1px solid #EEF1F6` as a divider from content):
  - **WhatsApp button (per row):** 40×40, `border-radius:12px`, bg `#1DAB61`, filled `chat` icon 20px white.
  - **Favorite** icon 18px below it — coral `#F4795B` filled (saved) / grey `#9AA4B2` (unsaved).
- Compact fits ~4 rows in the same viewport (mock shows verified sale, featured sale, unverified sale, verified rental `٤٥٠ $ / شهرياً`).

---

### Cross-mode summary — card anatomy by mode
| Field | مريح (Comfortable) | متوازن (Balanced) | مضغوط (Compact) |
|---|---|---|---|
| Layout | vertical, full-width | vertical card, 16px margin | horizontal row, 12px margin |
| Image | 216px tall, radius 20px, full-bleed | 180px (verified) / 150px (featured) | 110px wide, full-height thumb |
| Fields shown | title, price, 1 meta line | price(+LS/$·m²), title, location, specs strip, agent row | price(+$/m²·شهرياً), title, packed meta, status line |
| موثّق badge | pill top-right (green, may read "موثّق قبل ٣ أيام") | green pill top-right (+blue للبيع) | small green pill top-right of thumb |
| مميّز badge | gold pill top-right, stacked before موثّق | gold pill top-right, stacked with موثّق | gold pill top-right (does NOT stack; موثّق shown inline in status) |
| Favorite | 38px circle, image top-left | 36px circle, image top-left | 18px icon in action column |
| Contact | none | WhatsApp 44px + Call 44px in agent row | WhatsApp 40px per row (no call) |
| Toggle icon | `view_agenda` | `view_day` | `view_list` |

**Key measurement deltas:** side padding shrinks 18px → 16px → 12px as density increases; image goes 216 → 180/150 → 110px(w); price type 17 → 21 → 16px; WhatsApp button 44px (balanced) vs 40px (compact); comfortable & compact toggle buttons are outlined-idle, balanced is filled-active. Bottom nav is identical across all three modes (same 5-tab bar as Home).

Source file: `H:\alnujom-project\New design\extracted2\Al Nujom UI.dc.html` (Home = lines 216–566; View-mode switcher = lines 2143–2428).

---

## SEARCH + FILTERS + MAP

Precise spec extracted from section 03 (lines 567–896) of `H:\alnujom-project\New design\extracted2\Al Nujom UI.dc.html`. Three phone artboards: (A) smart search results, (B) the Syria-native filter sheet, (C) draw-your-area map. All RTL, Tajawal, blue accent `#1F4FE6`, verified-green `#1F7A4D`, ink `#0B182B`.

---

### (a) SEARCH RESULTS SCREEN — "نتائج البحث الذكي"

**Search bar (natural-language)**
- Leading square back button (44×44, `arrow_forward` — RTL back), rounded 14px.
- Input field: white, 1.5px blue border, `search` icon (blue), the raw NL query text `شقة بدمشق تحت ١٠٠ ألف دولار` (bold), trailing `close` (clear) icon.

**Parsed-intent chip row — "فهمنا طلبك:"** (NEW / signature capability)
The typed sentence is parsed into removable filter chips, each blue-tinted pill with an icon:
- `apartment` شقة (property type)
- `location_on` دمشق (location)
- `payments` أقل من ١٠٠٬٠٠٠ $ (price ceiling)
This is the "NL query → parsed filter chips" pattern — not a normal keyword search.

**Filter quick-row** (horizontal pills below chips)
- **الفلاتر** — dark solid pill with `tune` icon + a blue count badge (`٢` active filters); opens the filter sheet.
- **الموثّقة فقط** — green outline/tinted toggle pill with filled `verified` icon (verified-only).
- **طابو أخضر** — plain white outline pill (an applied deed quick-filter).

**Result header row**
- Left/start: count + trust note — `٣٤ نتيجة · الموثّقة تُعرض أولاً` (verified shown first, the green phrase).
- End: **sort control** — `swap_vert` icon + label `الأحدث` (Newest). Sort is a tappable label, not a full dropdown shown here.

**Result card anatomy** (compact horizontal row card; white, radius 16, soft shadow, ~10px pad)
- **Thumbnail** 118×118, radius 12, gradient placeholder with diagonal hatch. Top-right badge: either green filled `verified` **موثّق**, or grey **غير موثّق** pill.
- **Body column:**
  - Row 1: **price** (17px, weight 900, e.g. `٨٩٬٠٠٠ $`) + favorite heart (`favorite` — filled coral `#F4795B` when saved, grey `#9AA4B2` when not).
  - Row 2: **title** (bold, e.g. `شقة ٢ غرفة كسوة ديلوكس`, `شقة ٣ غرف — طابو أخضر`).
  - Row 3: **location** muted (`كفرسوسة، دمشق`, `جرمانا، ريف دمشق`).
  - Row 4: **fact strip** pipe-separated — rooms `٢ غرف` | area `١١٠ م²` | floor `ط ٢`.
  - Row 5: **verification recency** — `schedule` icon + green `تم التأكد قبل يوم واحد` / `تم التأكد قبل ٤ أيام`; for unverified: grey `help` icon + `لم يُوثّق بعد`.
- Three sample cards: two verified (recency shown), one unverified (grey state).

**View-mode toggle** — a floating dark pill centered near the bottom: `map` icon + **الخريطة** (switch results ↔ map view).

**Bottom nav** (5 tabs, active = "بحث وخريطة" with `travel_explore` filled blue): استكشف / **بحث وخريطة** / المحفوظة / الرسائل / حسابي.

---

### (b) FILTER SHEET — "تصفية النتائج" (bottom sheet over dimmed scrim, drag handle, header + red **إعادة تعيين** reset)

Enumerated top-to-bottom, every control and its exact options:

1. **نوع العملية (deal type)** — 3-segment pill toggle, active = **للبيع**. Options: `للبيع` · `إيجار سنوي` · `شهري/يومي`.

2. **الموقع (location tree)** — the المحافظة→المدينة→المنطقة cascade:
   - Two dropdown fields side by side with floating micro-labels: **المحافظة** (governorate) = `دمشق`, **المدينة** (city) = `دمشق`, each with `keyboard_arrow_down`.
   - Below: **المنطقة (district) multi-select chips** — selected districts as removable blue pills each with `close`: `المزة`, `كفرسوسة`; plus a dashed **+ منطقة** add-chip to append more. So the tree is 3 levels: governorate → city → many districts.

3. **السعر (price range)** — with **currency toggle** (small segmented pill, active `$`, alt `ل.س`). Dual-thumb range **slider** (two handles, blue active track). Two readout boxes: **من** `٢٠٬٠٠٠ $` and **إلى** `١٠٠٬٠٠٠ $`.

4. **الغرف (rooms)** — 6 segmented buttons, active = `٣` (blue). Options: `ستوديو` · `١` · `٢` · `٣` · `٤` · `٥+`.

5. **الحمامات (bathrooms)** — 3 segmented buttons, active = `٢`. Options: `١` · `٢` · `٣+`.

6. **نوع الملكية / الطابو (deed type)** — label carries an `info` glyph (explainer). Wrapping selectable chips, active = **طابو أخضر** (blue). Full option set exactly: `طابو أخضر` · `طابو أحمر` · `طابو مؤقت` · `طابو زراعي` · `حكم محكمة`. (**NEW — Syria-native; no equivalent in a normal real-estate filter.**)

7. **الكسوة (finish level)** — wrapping chips, active = **ديلوكس** (blue). Full ordered set (rough → premium): `على العظم` · `كسوة عادية` · `ديلوكس` · `سوبر ديلوكس`. (**NEW — Syria-native finish grade.**)

8. **Toggle rows** (divider-separated, with icon + iOS-style switch):
   - **مفروش فقط** (`chair` icon) — furnished-only, switch **OFF** (grey).
   - **الإعلانات الموثّقة فقط** (green filled `verified`) — verified-only, switch **ON** (green).

**Footer CTA** — full-width blue button **عرض ٣٤ نتيجة** (live result count baked into the apply button).

---

### (c) MAP VIEW — "الخريطة + ارسم منطقتك"

**Map canvas** (560px) — deliberately abstract, "data-light" simplified tiles: grey building blocks, a green park blob, a blue river, white road lines. Explicit affordance: a bottom center pill `data_saver_on` **خريطة مبسّطة لتوفير البيانات — ~٠٫٣ MB** (data-saver / low-bandwidth map). (**NEW / Syria-context capability.**)

**Draw-your-own-area tool** (**NEW — the headline map capability**)
- A **hand-drawn irregular closed region**: 2.5px dashed blue outline, blue 7%-alpha fill, organic blob shape.
- Attached label pill `gesture` **منطقتك المرسومة** ("your drawn area").
- Left rail action buttons: **blue `gesture`** (active draw tool) on top, then white `my_location` (recenter) and `layers` (map layer switch). 48×48 rounded-16 FABs.

**Price markers** (per-listing map pins as price pills)
- Verified listing markers: white pill + green filled `verified` + price, e.g. `٨٩ ألف $`, `٧٥ ألف $`.
- **Selected/active marker**: blue-fill white-text with white border, e.g. `١٢٥ ألف $` (matches the card open in the bottom sheet).
- Unverified marker: white pill, muted grey text, no verified icon, e.g. `٦٢ ألف $`.
- **Cluster marker**: dark circular badge `+١٢` (12 more listings collapsed).

**Search / "search this area" overlay** (top of map)
- Search field: `arrow_forward` back, current-area text `المزة وكفرسوسة، دمشق`, trailing `tune` (opens filter sheet).
- Applied-filter chip row over the map: green **الموثّقة فقط**, `للبيع`, `٣+ غرف`.
- (Note: there is no separate "ابحث في هذه المنطقة" button; re-search is expressed through the draw-area region + the area label in the search field. The redraw/clear affordance lives in the bottom sheet — see below.)

**Bottom listing sheet** (drawn over the map, rounded top, drag handle)
- Header: count within drawn region — **٢٣ عقاراً ضمن منطقتك** ("23 properties within your area"), and a red **مسح الرسم** action with `ink_eraser` icon (clear the drawing → re-search).
- Single featured listing card (grey `#F5F7FA` inset, 96×88 verified thumb): price `١٢٥٬٠٠٠ $`, title `شقة ٣ غرف مع تراس — طابو أخضر`, meta `المزة فيلات غربية · ١٤٥ م² · ط ٤`, and a **contact action pair**: green **واتساب** (`chat`) + blue-outline **اتصال** (`call`). WhatsApp-first contact.

**Bottom nav** — same 5-tab bar, active "بحث وخريطة".

---

### NEW capabilities vs a normal filter (call-outs)
- **NL parsed-intent chips** (typed sentence → structured, removable filter chips).
- **نوع الملكية / الطابو** deed-type filter: أخضر / أحمر / مؤقت / زراعي / حكم محكمة — Syria-specific land-title legality, no Western analog.
- **الكسوة** finish-grade filter: على العظم → كسوة عادية → ديلوكس → سوبر ديلوكس — Syria-native construction/finish ladder.
- **Verified-first ordering + per-listing verification recency** woven through results, chips, sheet toggle, and map markers.
- **Draw-your-own-area** map tool (freehand region → count "within your area" → listings scoped to it, with erase/redraw).
- **Data-light / data-saver map** (~0.3 MB simplified tiles) as an explicit, surfaced affordance.
- **WhatsApp-first contact** on the map bottom sheet (واتساب primary, اتصال secondary).

---

## LISTING DETAIL

Source: `H:\alnujom-project\New design\extracted2\Al Nujom UI.dc.html`, section "04 · صفحة العقار" (lines 898–1111). Two phone mockups: **Light** (lines 907–1029, screen fill `#F5F7FA`) and **Dark** (lines 1031–1108, screen fill `#0B182B`). Section byline: "Verification report · key facts · WhatsApp-first contact bar". Screen is a vertical flex column with a scrollable body (`padding:16px; gap:14px`) and a pinned bottom contact bar.

Important divergence between the two mockups: the **Light** variant is the full, complete spec (verification block → price → key-facts → mini-map → agent card → description → similar → contact bar). The **Dark** variant is an abbreviated redraw — it drops the mini-map, description, and similar-listings sections and collapses the agent card to a single row. Treat **Light as the authoritative content order**; Dark only re-tints the shared elements. Colors below are given as Light `/` Dark.

Top-to-bottom:

### 1. Photo gallery / hero
- Fixed-height hero, `height:290px`, non-scrolling (`flex:none`). Placeholder gradient `#CBD7E6→#AFC0D6` / `#2B3B55→#1B2A44` with a 45° hatch overlay; caption mono text "photo 1/8: living room, natural light".
- Status bar overlaid on the image (time ٩:٤١ + signal/wifi/battery), text `#0B182B` / `#EAF0F8`.
- **Top-right:** a single back chevron button `arrow_forward` (RTL back), 42×42 rounded-14 chip, white `.94` / dark `.8`.
- **Top-left:** two 42×42 chips — `share`, and `favorite` (filled, coral `#F4795B`).
- **Bottom-right badge cluster:** green "موثّق" pill with filled `verified` icon (`#1F7A4D` bg) + a transaction pill "للبيع" (blue `#1F4FE6` / `#4D7CFF`). These duplicate the price-block info as image overlays.
- **Bottom-left:** photo-count chip on translucent dark, `photo_library` + "١ / ٨ · حمّل الباقي" ("1/8 · load the rest" — implies lazy/on-demand image loading).

### 2. Green trust block — "إعلان موثّق ميدانياً" (field-verified)
Tinted card: bg `rgba(31,122,77,.07)` / `rgba(76,192,138,.07)`, 1px green border, radius 16, padding 14. Accent green `#1F7A4D` (light) / `#4CC08A` (dark).
- **Header row:** filled `verified` icon (24px) + bold title "إعلان موثّق ميدانياً" + a right-aligned underlined link "تقرير التوثيق" ("verification report" — links to a full report screen/sheet).
- **Three check bullets** (`check_circle` icon each, green; label text `#0B182B` / `#EAF0F8`):
  1. **Site visit:** "زيارة ميدانية من مندوب النجوم — ١٢ حزيران ٢٠٢٦" (field visit by an AlNujom rep, dated 12 June 2026).
  2. **GPS / geotagged photo:** "صورة حيّة بإحداثيات الموقع مطابقة للعنوان" (live photo whose coordinates match the address).
  3. **Identity:** "هوية المعلن مطابقة — مكتب مرخّص" (advertiser identity verified — licensed office).
- **Freshness timestamp strip** (inset white `#FFFFFF` / dark `#13233B` pill, radius 10): `schedule` icon + "تم التأكد من توفّرها قبل ٣ أيام" (availability re-confirmed 3 days ago).

### 3. Price + transaction label
- Row: bold 28px price "١٢٥٬٠٠٠ $" (`#0B182B` / `#EAF0F8`) + muted SYP approximation "≈ ١٫٦ مليار ل.س" (dual-currency display).
- Title `h3` 18px: "شقة ٣ غرف مع تراس واسع — طابو أخضر".
- Location row: `location_on` + "المزة فيلات غربية، دمشق", right-pushed relative-time "نُشر قبل أسبوع". Transaction label ("للبيع") itself appears only as the hero pill (#1), not repeated here.

### 4. Key-facts tiles
3-column grid, `gap:8px`. Each tile: white `#FFFFFF` border `#E4E9F0` / dark `#13233B` border `#22344E`, radius 12, centered icon + bold value + muted sublabel. Icon blue `#1F4FE6` / `#7C9BFF`. Six tiles:
1. `bed` — "٣ غرف" / "النوم" (bedrooms)
2. `bathtub` — "حمامان" / "+ ضيوف" (baths + guest WC)
3. `straighten` — "١٤٥ م²" / "المساحة" (area)
4. `stairs` — "ط ٤ من ٦" / "مع مصعد" (floor 4 of 6, with elevator)
5. `description` — "طابو أخضر" / "الملكية" (deed type — **Syria-specific**)
6. `imagesearch_roller` — "سوبر ديلوكس" / "الكسوة" (finish/fit-out level — **Syria-specific**)

### 5. Mini-map (Light only)
`height:120px`, radius 16, muted map placeholder (`#E8EBEE`) with fake building blocks + road strips and a blue location pin (`rgba(31,79,230,.15)` halo + `#1F4FE6` dot, white ring). Overlay chip bottom-right: "الموقع تقريبي — يُشارك الدقيق بعد التواصل" (approximate location; exact shared after contact — deliberate location fuzzing). *Absent from Dark mockup — carry it over from Light.*

### 6. Agent card
White/`#13233B` card, radius 16, padding 14.
- **Light (full):** avatar 52px circle with a green check overlay badge (verified); name "محمد الخطيب" + green "وسيط موثّق" pill (verified broker); sub "مكتب الشام العقاري — المزة، دمشق"; trailing `chevron_left` (navigates to agent profile). Below, a 3-up stat row: **responsiveness** "خلال ساعة / يرد عادة" (usually replies within an hour, value in green), "٢٤ إعلاناً / نشط" (active listings), "منذ ٢٠٢٣ / عضو" (member since).
- **Dark (collapsed):** single row, same avatar + verified badge + name + "وسيط موثّق" pill, sub folds responsiveness inline "مكتب الشام العقاري · يرد عادة خلال ساعة", trailing chevron. No stat row. *Use the Light 3-stat layout as the target.*

### 7. Description (Light only)
Label "الوصف" + paragraph (13.5px, `#5B6B80`, line-height 1.9) describing floor/elevator/finish/rooms/terrace, heating, water tank, parking, and "الطابو أخضر جاهز للفراغ الفوري". Trailing blue "المزيد" (more — expand/truncate control). *Absent from Dark.*

### 8. Similar listings (Light only)
Label "عقارات مشابهة" + horizontal scroll row of mini property cards (width 200px): image with a green "موثّق" corner pill, price + short title (e.g. "١١٨٬٠٠٠ $ — شقة ٣ غرف — المزة ٨٦", "٩٨٬٠٠٠ $ — شقة ٢ غرفة — كفرسوسة"). *Absent from Dark.*

### 9. Contact bar (bottom, in-flow — NOT a sticky overlay)
Present in both mockups as the **last child of the scroll column** (`flex:none`, `border-top`, `padding:12px 16px 30px`, top shadow), bg white / `#0E1D33`. Three actions, RTL order:
- **اتصال (call):** 52×52 outline-blue square, filled `call` icon (`#1F4FE6` / `#4D7CFF`).
- **حجز معاينة (book viewing):** flex:1 neutral outlined button, `calendar_month` icon + label.
- **واتساب (WhatsApp):** flex:1.2 solid green `#1DAB61` button with shadow, filled `chat` icon + label — the primary/widest CTA (WhatsApp-first).

> **Founder rule / build note:** The HTML markup places this bar inside the phone frame at the bottom with a "sticky contact bar" comment, but per the standing rule **do NOT implement a sticky/pinned bottom CTA bar on the Flutter listing-detail screen.** Render these three actions as the final in-scroll content block (they already sit last in the flow), or relocate per the app's existing pattern — but not as a fixed floating bar.

---

### Flags — requires NEW backend data / metadata
1. **Verification status & report metadata (biggest):** the whole green block needs new fields — `verification_status` (boolean/enum), site-visit date + rep, geotag-match flag, identity/license-verified flag, and a `last_availability_confirmed_at` timestamp powering "تم التأكد… قبل ٣ أيام". Plus a linked **"تقرير التوثيق" report** entity/screen. The hero "موثّق" pill, similar-card "موثّق" pills, and the agent "وسيط موثّق" badge all read from verification flags too.
2. **Deed type (طابو أخضر):** new structured field (enum of Syrian ownership/deed types) — tile 5 and title/description.
3. **Finish level (الكسوة — سوبر ديلوكس):** new enum field for fit-out grade — tile 6.
4. **Elevator flag** (tile 4 sublabel "مع مصعد") — a boolean amenity if not already modeled.
5. **Agent responsiveness ("يرد عادة خلال ساعة"):** a derived/computed reply-time metric per agent — new aggregate, plus active-listing count and member-since (likely derivable) and agent `verified` status.
6. **Location fuzzing:** requires distinguishing an approximate/public coordinate from the exact one that is "shared after contact" — a privacy/precision policy on the coordinates, possibly a separate obfuscated point.
7. **Dual-currency (≈ ل.س):** the SYP approximation implies an FX-conversion source; new only if not already computed client-side.
8. **Lazy photo loading ("حمّل الباقي")** and **photo count** — needs total image count/manifest exposed; likely already available via the images relation.

Deed type, finish level, and full verification metadata are the three genuinely new schema additions to call out for backend work.

---

## SAVED + MESSAGES + NOTIFICATIONS

Source: `H:\alnujom-project\New design\extracted2\Al Nujom UI.dc.html` — section 05 (lines 1113–1357) and the Notifications screen in section 11 (lines 2551–2625). All screens are RTL, Tajawal, Material 3, light-mode phone frames. Design tokens observed across all three surfaces:

**Shared tokens**
- Screen bg `#F5F7FA` (chat thread uses `#EEF1F5`); card surface `#FFFFFF`; hairline/border `#E4E9F0`.
- Text: primary `#0B182B`, secondary `#5B6B80`, muted/meta `#9AA4B2`.
- Brand blue `#1F4FE6` (primary accent / active state / links) and `#3D6BFF` (section index); success green `#1F7A4D`; WhatsApp/chat green `#1DAB61`; gold `#C2A14D`; coral `#F4795B` (favorite fill + badge).
- Card radius 14–16px; card shadow `0 2px 8px rgba(11,24,43,.07)`; pill radius `999px`.
- Bottom nav: 5 tabs — استكشف (home), بحث وخريطة (travel_explore), المحفوظة (favorite), الرسائل (chat_bubble), حسابي (person). Active tab = blue `font-variation-settings:'FILL' 1` icon on a `rgba(31,79,230,.12)` pill + blue bold label; inactive = `#9AA4B2` icon+label. Bottom padding 26px (gesture bar). Messages tab can carry a coral `#F4795B` count badge (top:2px left:10px, min-width 16px).
- Status bar row 48px: `٩:٤١` bold + signal/wifi/battery (battery rotated 90deg).

---

### (a) SAVED — المحفوظة

Header: title `المحفوظة` (24px/900) with right-aligned subtitle `تُحفظ للتصفح دون اتصال` (12.5px/700 muted). Active bottom-nav tab = المحفوظة (favorite, filled blue).

**Section A — Saved listings** (`عقارات محفوظة (٤)`, 15px/800, count in muted; right-side action `تحرير` in blue 12.5px/700).

Saved-listing card (white, radius 16, padding 10, `display:flex; gap:12`):
- Thumbnail 110×104, radius 12, gradient placeholder `linear-gradient(140deg,#D6DFEC,#B9C8DC)` with a 45° hatch overlay.
- Top-right badge on thumb: green `موثّق` pill (`#1F7A4D` bg, white text, filled `verified` icon 11px) when verified.
- Body: row 1 = price (16px/900 `١٢٢٬٠٠٠ $`) + filled coral `favorite` icon (20px, `#F4795B`, the "saved" heart). Optional price-drop chip: `rgba(31,122,77,.1)` bg, green text, `trending_down` icon → `انخفض ٣٬٠٠٠ $ منذ حفظتها`. Then title (13px/700) `شقة ٣ غرف مع تراس — المزة`, then meta (11.5px muted) `دمشق · ١٤٥ م² · ط ٤`.

**Unavailable-listing state** (second card): thumbnail carries a full `rgba(11,24,43,.45)` scrim with a centered dark pill `لم يعد متوفراً` (white 11px/800 on `rgba(11,24,43,.6)`). The body wrapper drops to `opacity:.6`; price shows `text-decoration:line-through`; meta reads `حلب · بيعت قبل يومين`; a blue CTA `اعرض المشابهة ←` (11.5px/700, margin-top 4px) replaces the normal actions. Heart stays filled coral (still saved).

**Section B — Saved searches** (`عمليات بحث محفوظة (٢)`, 15px/800).

Saved-search row (white, radius 14, padding 12×14, `align-items:center; gap:12`):
- Leading 40×40 tile radius 12, `rgba(31,79,230,.08)` bg, blue `saved_search` icon 21px.
- Body: title 13.5px/800 (`شقق للبيع — المزة وكفرسوسة`); criteria line 11.5px muted (`أقل من ١٠٠٬٠٠٠ $ · ٣+ غرف · موثّقة فقط`); optional green "new results" line 11px/700 `#1F7A4D` (`٣ إعلانات جديدة هذا الأسبوع`).
- Trailing = alert toggle stacked over a caption:
  - **ON**: 44×26 track radius 99, bg `#1F4FE6`; 20×20 white knob at `top:3px; left:3px` (RTL → knob on the "on"/leading side); caption `التنبيهات` (9.5px/700, `#5B6B80`).
  - **OFF**: track bg `#E4E9F0`; knob at `top:3px; right:3px` with `0 1px 3px rgba(11,24,43,.2)` shadow; caption `صامت` (9.5px/700, `#9AA4B2`).

---

### (b) MESSAGES

#### Conversation list — الرسائل
Header `الرسائل` (24px/900) + search field: 44px, white, `1.5px #E4E9F0` border, radius 12, `search` icon (19px muted) + placeholder `ابحث في المحادثات` (13px muted). Active bottom-nav tab = الرسائل (chat_bubble filled blue).

Conversation row (white, radius 14, padding 12, `gap:12`, 10px bottom gap):
- Avatar 48×48 circle `#DCE4F0` with `person` icon (26px `#7D8B9E`). Online users get a presence dot: 16×16 green `#1F7A4D`, `2px #FFFFFF` border, at `bottom:-1px; left:-1px`.
- Body: name row = name + optional filled green `verified` (14px) badge on one side, timestamp on the other (`٩:٢٢ ص` unread = blue/700; read = muted/700 like `أمس`, `الأحد`).
- Last-message preview (12.5px): **unread** = `#0B182B`/700 bold; **read** = `#5B6B80`/500. Outgoing/read replies may be prefixed with `✓`.
- Listing-context chip (self-start, `#F5F7FA` bg, radius 6, 11px muted) tying the chat to its listing, e.g. `شقة ٣ غرف — المزة · ١٢٥٬٠٠٠ $`.
- Unread count badge (self-center): blue `#1F4FE6` pill, white 11px/800, min-width 20px (`٢`).

Info banner below list: `rgba(31,79,230,.06)` bg, `1px dashed rgba(31,79,230,.3)`, radius 12, `lock` icon (blue) + `المراسلة داخل التطبيق تحفظ سجلّ اتفاقك — ويمكنك المتابعة عبر واتساب متى شئت.` (11.5px/700 muted).

#### Chat thread (WhatsApp-style)
Thread bg `#EEF1F5`. **Thread header** (white, bottom border): back `arrow_forward` (RTL back), 42px avatar + presence dot, name + filled green verified, presence line `متصل الآن · يرد عادة خلال ساعة` (11.5px/700 green). Two action tiles 40×40 radius 12: WhatsApp `chat` (green `#1DAB61` on `rgba(29,171,97,.1)`) and `call` (blue on `rgba(31,79,230,.08)`).

**Pinned listing bar** (white, `1px #E4E9F0`, radius 12): 44×44 gradient thumb + title (12px/800) + `١٢٥٬٠٠٠ $ · موثّق` (11px muted) + trailing blue `عرض` (11.5px/800).

**Message area** (`gap:10`):
- Day divider: self-center pill `#E2E7EE` bg, `#5B6B80`, 10.5px/700 (`اليوم`).
- **Outgoing bubble** (buyer, self-start in RTL): blue `#1F4FE6` bg, white text, radius `16px 4px 16px 16px` (notched top-inner corner), shadow `0 2px 8px rgba(31,79,230,.2)`, max-width 78%. Meta row self-end: time `rgba(255,255,255,.75)` + `done_all` read receipt (`rgba(255,255,255,.9)`).
- **Incoming bubble** (owner, self-end): white bg, `#0B182B` text, radius `4px 16px 16px 16px`, shadow `0 2px 8px rgba(11,24,43,.08)`, time muted self-end (no receipt).
- Body text 13.5px/500, line-height 1.7; emoji inline.
- **Viewing-confirmed card** (self-center, 88% width): `rgba(31,122,77,.08)` bg, `1px rgba(31,122,77,.3)`, radius 14; 40×40 green `#1F7A4D` tile with white `event_available`; title `معاينة مؤكّدة` (13px/900 green) + `الخميس ٣ تموز · ٥:٠٠ مساءً` (12px/700); trailing underlined green `أضف تذكيراً`.

**Quick-reply chips** (`flex-wrap; gap:6`): outlined pills `1.5px #1F4FE6`, blue text, white bg, 12px/800, radius 999, padding 7×13 — `أرسل لي الموقع`, `صور إضافية؟`, `تفاصيل الطابو`.

**Composer** (white, top border, bottom pad 28): leading 44×44 circle `#F0F3F7` with `add`; flex input pill 44px `#F0F3F7` radius 999 with placeholder `اكتب رسالة…` + trailing `mic` icon; send button 44×44 blue circle, white filled `send` (`transform:scaleX(-1)` for RTL), shadow `0 4px 12px rgba(31,79,230,.35)`.

---

### (c) NOTIFICATIONS — الإشعارات

Header: back tile 40×40 (white, `1px #E4E9F0`, `arrow_forward`), title `الإشعارات` (17px/800, flex:1), trailing action `تحديد الكل كمقروء` (12.5px/700 blue). Grouped by day dividers `اليوم` / `أمس` (12px/800 muted). Active bottom-nav tab = استكشف (home). Messages tab shows coral `٢` badge.

Notification card base: white, radius 16, padding 13×14, `gap:12`, `align-items:flex-start`. 42×42 leading icon tile radius 13 (tinted per type, filled icon 22px).

**Unread-highlight treatment**: border `1.5px rgba(31,79,230,.35)` (vs. read `1px #E4E9F0`) **plus** card shadow `0 2px 8px rgba(11,24,43,.07)` **plus** a trailing 9×9 blue `#1F4FE6` unread dot (`margin-top:5px`). Read cards have the plain hairline border, no shadow, no dot.

The 4 types:
1. **New listing matching a saved search** (unread) — tile `rgba(31,79,230,.1)`, blue filled `saved_search`. Title `عقار جديد يطابق بحثك «شقة ٣ غرف — المزة»`; body `شقة ١٤٥ م² بسعر ١٢٥٬٠٠٠ $ — موثّقة قبل ٣ أيام`; time `قبل ١٠ دقائق`.
2. **Message reply** (unread) — tile `rgba(29,171,97,.12)`, green `#1DAB61` filled `chat`. Title `مكتب الشام العقاري ردّ على رسالتك`; body = quoted reply snippet `«أهلاً أستاذ أحمد، المعاينة متاحة غداً بعد العصر…»`; time `قبل ساعة`.
3. **Verification-status update** (read) — tile `rgba(31,122,77,.1)`, green `#1F7A4D` filled `verified`. Title `تم توثيق إعلانك «شقة ٢ غرفة — كفرسوسة» ✓`; body `اكتملت الزيارة الميدانية والصورة الحيّة — إعلانك يظهر الآن أولاً في النتائج`; time `أمس · ٤:٣٠ م`.
4. **Viewing-appointment reminder** (read) — tile `rgba(194,161,77,.14)`, gold `#C2A14D` filled `calendar_month`. Title `تذكير: معاينة غداً الساعة ٥:٠٠ م`; body `شقة ٣ غرف — المزة فيلات غربية · مع مكتب الشام العقاري`. Includes an inline action row (this type only): primary `تأكيد` button (34px, `rgba(31,79,230,.08)` bg, `1px rgba(31,79,230,.3)`, blue text/800, `event_available` icon) + secondary `إعادة جدولة` (`#F5F7FA` bg, `1px #E4E9F0`, `#5B6B80`/700). Time `أمس · ١٠:٠٠ ص` below the actions.

Rows are separated by 10px top margins; card metric lines: title 13.5px/800 `#0B182B` (line-height 1.5), body 12px/500 `#5B6B80` (line-height 1.6), time 11px/700 `#9AA4B2`.

Text lines longer than the frame truncate via `min-width:0` on the flex body column.

---

## ADD + ACCOUNT + AUTH

Specs derived verbatim from sections 06, 07, and 11 of `H:\alnujom-project\New design\extracted2\Al Nujom UI.dc.html`. All screens are RTL (`dir="rtl"`), Tajawal font, royal-blue accent `#1F4FE6`, ink `#0B182B`, muted `#9AA4B2`, verified-green `#1F7A4D`/`#4CC08A`, featured-gold `#C2A14D`, pending-amber `#E9A23B`. Numerals render as Arabic-Indic (٩:٤١). Prices/phone/version are `dir="ltr"`.

---

### (a) ADD LISTING — guided multi-step flow (`أضف عقار — تدفّق موجّه`)

**4-step wizard. One question-group per screen. Verification (geotagged live photo) is step 3.** Every step shares a chrome: status bar → header row → 4-segment stepper bar.

**Header row pattern:** leading 42×42 rounded-square icon button (`close` on step 1 to abandon; `arrow_forward` = back on later steps) · center title + subtitle `الخطوة N من ٤ — <label>` · step 1 also shows trailing `حفظ كمسودة` (save-as-draft, blue text).

**Stepper bar:** 4 equal pills, height 5px, radius 99px. Completed/current segments fill; on the dark verification step completed = green `#4CC08A`, current = blue `#4D7CFF`, upcoming = `#22344E`; on light review step completed = green `#1F7A4D`, current = blue.

**Step 1 — التفاصيل (Details), light surface `#F5F7FA`:**
- **نوع الإعلان؟** — 3-way pill segmented control: `للبيع` (selected, blue fill white text) / `إيجار سنوي` / `شهري/يومي`.
- **نوع العقار** — 3-col grid of icon tiles (74px, icon + label): `شقة` (selected, 2px blue border + blue icon FILL) / `منزل عربي` / `فيلا` / `أرض` / `محل` / `مكتب`. Icons: apartment, home, villa, landscape, storefront, business.
- **الموقع** — two dropdown fields side by side, each showing a small floating label + value + `keyboard_arrow_down`: `المحافظة` (دمشق) / `المنطقة` (المزة).
- **السعر** + **المساحة** row — price field (focused, blue border, value ١٢٥٬٠٠٠) with an inline currency toggle pill `$`(selected, ink fill) / `ل.س`; area field (value ١٤٥) with suffix `م²`.
- **نوع الطابو** — wrap of choice chips: `طابو أخضر` (selected, tinted-blue) / `طابو أحمر` / `مؤقت` / `زراعي`.
- Sticky footer primary CTA: **`التالي — الصور`** (Next — Photos), blue, 52px, radius 14, blue glow shadow.

**Step 2 — الصور (Photos):** referenced by step-1 CTA and by the stepper (2nd segment) but not rendered as its own mock in this section; the photo grid, reorder, and "رئيسية / main" tagging, plus auto-compression, surface in the Step-4 preview.

**Step 3 — التوثيق الميداني / وثّق عقارك (Field verification), dark surface `#0B182B` — "the trust moment":**
- Subtitle: `الخطوة ٣ من ٤ — صورة حيّة من الموقع` (a live on-site photo).
- **Camera viewfinder** (400px, live camera of the building entrance) with 4 white L-shaped corner framing guides.
- **Geotag chip** (top-center, green-outlined, `my_location` FILL): `الموقع مطابق: المزة، دمشق ✓` — location auto-matched against the entered listing location.
- **Timestamp chip** below it (`schedule`): `الختم الزمني: الأربعاء ٢ تموز · ٩:٤١ ص` — server/live capture time stamped onto the photo.
- **Shutter controls row:** `flash_off` toggle · 64px white shutter ring · `flip_camera_ios`.
- **What it captures (rule box, `tips_and_updates`):** "Take the photo from in front of the property entrance. It is captured **directly from the camera — cannot be uploaded from the gallery/studio** — and coordinates are attached automatically." So the step captures: a live camera frame + GPS coordinates (verified to match the listing area) + a trusted timestamp, all bound together and gallery-upload-disabled to prevent fakes.
- **Payoff line (`verified` FILL):** after review (within 24–48h / `٢٤–٤٨ ساعة`) the listing earns a «موثّق» (Verified) badge and ranks higher.
- **Skip affordance (underlined, muted):** `تخطَّ التوثيق — سينشر إعلانك «غير موثّق» بترتيب أدنى` — skipping publishes the listing as "unverified" with lower ranking. Verification is optional but incentivized.

**Step 4 — المراجعة والنشر / مراجعة أخيرة (Review & Publish), light surface — "preview exactly as buyers will see it":**
- **Preview card** (dashed border, header strip `معاينة إعلانك` with `visibility`): hero photo placeholder labeled `your photo 1/6`, an amber `التوثيق قيد المراجعة` (verification under review, `hourglass_top`) badge, then price `١٢٥٬٠٠٠ $`, title `شقة ٣ غرف مع تراس — طابو أخضر`, meta `المزة، دمشق · ١٤٥ م² · ط ٤`.
- **Photos row** — `الصور (٦ — اسحب لإعادة الترتيب)` (6 photos, drag to reorder); first thumb tagged `رئيسية` (main, blue border); a `+٣` overflow tile. Note (`data_saver_on`): `تُضغط الصور تلقائياً (~١٥٠ كيلوبايت) دون فقدان الوضوح` — photos auto-compressed to ~150 KB without quality loss.
- **Verification summary** (green tint, `verified` FILL): `صورة التوثيق الحيّة مرفقة ✓` + `المزة، دمشق · ٩:٤١ ص — بانتظار مراجعة فريق النجوم` (live verification photo attached, awaiting AlNujom team review).
- **Featured upsell** (gold `workspace_premium`): `ميّز إعلانك` + gold «مميّز» tag, subtitle `يظهر في شريط «مميّز» أعلى الرئيسية — ٧ أيام` (shown in the Featured strip atop Home for 7 days), with an OFF toggle.
- Sticky footer: primary CTA **`انشر الإعلان مجاناً`** (Publish for free) + fine print `بالنشر أنت توافق على سياسة الإعلانات — لا رسوم على الإعلان الأساسي` (by publishing you agree to the ads policy; no fee on the basic listing).

---

### (b) ACCOUNT — حسابي (`profile · my listings · language + data-saver settings`)

Light surface `#F5F7FA`; page title `حسابي` (24px, 900). Bottom nav present with `حسابي` tab active (blue, `person` FILL). Composed of stacked white rounded (16px) cards:

**1. Profile header card:**
- 56px circular avatar (placeholder `person`) · name **أحمد الحموي** · phone `+963 932 445 187` (`dir="ltr"`) · green verified pill `الهاتف موثّق` (`check`) · trailing `تعديل` (edit, blue).
- Below: dashed-blue KYC prompt (`badge`): `وثّق هويتك لتحصل على شارة «معلن موثّق» وترفع ثقة المشترين` with `ابدأ` (start) CTA — identity verification to earn the "Verified advertiser" badge.

**2. My-listings card (إعلاناتي):**
- Header `إعلاناتي` + `عرض الكل (٣)` (view all).
- 3 stat tiles: `٢ نشط` (active) / `١ قيد المراجعة` (under review, amber) / `١٤٢ مشاهدة هذا الأسبوع` (views this week).
- One listing row: 52×44 thumb · `شقة ٣ غرف — المزة · ١٢٥٬٠٠٠ $` · status line `موثّق · ٤٨ مشاهدة · ٥ محادثات` (verified · views · chats, green) · `chevron_left` (RTL forward affordance).

**3. Settings — Preferences card (التفضيلات):** rows separated by hairline dividers, each = leading icon + label + trailing control.
- **اللغة (Language, `language`):** inline 2-way pill toggle `العربية` (selected, ink fill) / `English` (`dir="ltr"`). Immediate language switch, no sub-screen.
- **وضع توفير البيانات (Data-saver, `data_saver_on` blue):** two-line — title + subtitle `صورة واحدة لكل بطاقة · خرائط مبسطة · بلا تشغيل تلقائي` (one image per card · simplified maps · no autoplay). Trailing **ON toggle** (blue track, knob at the LTR-left / RTL-active position). This is the switch that trims images/maps/autoplay for low-bandwidth users.
- **الوضع الليلي (Dark mode, `dark_mode`):** trailing value `تلقائي` (Auto) + `chevron_left` → opens picker sub-screen.
- **الإشعارات (Notifications, `notifications`):** trailing value `تنبيهات البحث فقط` (search alerts only) + chevron.

**4. Settings — General card:**
- `مركز الثقة والأمان` (Trust & Safety center, green `shield`) + chevron.
- `المساعدة والدعم` (Help & Support, `support_agent`) + chevron.
- `عن التطبيق` (About, `info`) + trailing `v١٫٠ · ٤٫٨ MB` (`dir="ltr"`).

**5. Logout card:** red `logout` + `تسجيل الخروج` (Sign out, red).

*(The adjacent mock in this section is the Offline-fallback + skeleton-shimmer state, not part of Account proper: offline banner `لا يوجد اتصال بالإنترنت` showing 4 saved properties + last search, a cached "download_done / محفوظ للتصفح دون اتصال" card, and shimmer skeletons that appear within 0.1s — "no white screens, no long spinners." Related but a separate surface.)*

---

### (c) LOGIN + SIGN-UP — تسجيل الدخول وإنشاء حساب (`phone-first auth · guest mode`)

**LOGIN (تسجيل الدخول):** light surface.
- Brand mark: 56px blue gradient rounded-square with white `star_rate` FILL logo.
- Heading **أهلاً بعودتك** (Welcome back) + subtitle `سجّل دخولك لمتابعة المحفوظة والرسائل وإعلاناتك` (sign in to keep saved items, messages, listings).
- **Method segmented control** (pill): `رقم الهاتف` (Phone, selected, `smartphone`) / `البريد` (Email, `mail`) — phone-first.
- **Phone field** (focused, blue border + blue focus ring): country prefix `+963` (`dir="ltr"`, left divider) + number `٩٤٤ ١٢٣ ٤٥٦`.
- **Password field:** masked `••••••••` + `visibility` reveal toggle.
- `نسيت كلمة المرور؟` (Forgot password?) link, blue.
- Primary CTA **`تسجيل الدخول`** (54px, blue, glow).
- `أو` (or) divider.
- **Guest CTA** (outlined, `visibility_off`): **`الدخول كزائر — تصفّح بلا حساب`** (Continue as guest — browse without an account).
- Footer: `ليس لديك حساب؟ **أنشئ حساباً**` (no account? create one).

**SIGN-UP (إنشاء حساب):** light surface; header = back `arrow_forward` + title `إنشاء حساب`. Skill label notes OTP via WhatsApp/SMS.
- **الاسم الكامل (Full name):** value `أحمد الحمصي`.
- **رقم الهاتف (Phone):** `+963` prefix + placeholder `٩xx xxx xxx`; hint (`chat`, green): `سنرسل رمز التحقق عبر واتساب — أو SMS إن لم يتوفر` (we'll send the OTP via WhatsApp, or SMS if unavailable).
- **كلمة المرور (Password):** masked + `visibility` toggle; hint `٨ أحرف على الأقل` (at least 8 chars).
- **أنا (I am) role selector** — 2 tiles: `باحث عن عقار` (property seeker, selected, blue, `person`) / `مالك / مكتب` (owner/agent, `real_estate_agent`).
- **Terms checkbox** (checked, blue): `أوافق على **شروط الاستخدام** و**سياسة الخصوصية**` (I agree to Terms of Use and Privacy Policy) — required to proceed.
- Primary CTA **`إنشاء الحساب`** (54px, blue, glow).
- Footer: `لديك حساب بالفعل؟ **سجّل الدخول**` (already have an account? sign in).

Source file: `H:\alnujom-project\New design\extracted2\Al Nujom UI.dc.html` (Add flow lines 1358–1588; Account lines 1590–1719; Login/Sign-up lines 2429–2547).

---

## COMPONENT LIBRARY

Atomic vocabulary for the AlNujom rebuild, extracted verbatim from section 08 (مكتبة المكوّنات) of `Al Nujom UI.dc.html`. Panel background is white `#FFFFFF`, corner radius `28px`, inner sub-panels sit on `#F5F7FA` at `18px` radius with `16px` padding. All text is Tajawal; mono labels are IBM Plex Mono. Token role names below map color to intent, not literal hex only.

### Token roles referenced
- `brand/primary` = `#1F4FE6` (royal blue — UI accent, "for-sale" mode, primary actions)
- `brand/primary-tint` = `rgba(31,79,230,.08–.12)` (selected chip fill, nav pill, focus ring)
- `success/verified` = `#1F7A4D` (موثّق — the ONE meaning: verified)
- `gold/featured` = `#C2A14D` (مميّز — featured signal only)
- `warn/review` = `#E9A23B` (قيد المراجعة — under review)
- `danger/error` = `#D64545` (input error border/icon), text/help error `#D64545`
- `accent/heart` = `#F4795B` (favorite icon, notification badge, empty-state icon)
- `whatsapp/green` = `#1DAB61` (WhatsApp CTA only — distinct from verified green)
- `ink/primary` = `#0B182B`; `ink/secondary` = `#5B6B80`; `ink/muted` = `#9AA4B2`
- `surface/card` = `#FFFFFF`; `surface/sunken` = `#F5F7FA`; `hairline` = `#E4E9F0`; `hairline-strong` = `#D4DBE4`; `chip-neutral-fill` = `#E9EDF3`
- `shadow/card` = `0 2px 8px rgba(11,24,43,.07)`

---

### 1. Listing card — `ListingCard`

**Verified variant (default / primary)**
- Container: `surface/card` `#FFFFFF`, radius `16px`, `overflow:hidden`, `shadow/card`.
- Image area: height `130px`, placeholder gradient `linear-gradient(140deg,#D6DFEC,#B9C8DC)`, `position:relative`.
  - Top-**right** cluster (RTL leading edge): row of badges, `gap:5px`, inset `10px`.
    - Verified badge: fill `success/verified` `#1F7A4D`, white text, pill radius `999px`, padding `4px 10px`, font `11px/800`, filled `verified` Material icon `13px`, label `موثّق`.
    - Transaction-mode badge: fill `brand/primary` `#1F4FE6`, white, pill, padding `4px 10px`, `11px/800`, label `للبيع`.
  - Top-**left**: favorite button, `32×32`, radius `99px`, bg `rgba(255,255,255,.94)`, filled `favorite` icon `18px` in `accent/heart` `#F4795B`.
  - Bottom-**right**: freshness pill, bg `rgba(11,24,43,.72)`, white, pill, padding `4px 10px`, `10.5px/700`, e.g. `تم التأكد قبل ٣ أيام`.
  - Body: padding `12px 14px`, column `gap:5px`:
    - Price `18px/900` `ink/primary` (e.g. `١٢٥٬٠٠٠ $`)
    - Title `13.5px/700` `ink/primary`
    - Meta line `12px/500` `ink/muted` `#9AA4B2` — location · rooms · area · floor.

**Unverified variant**
- Same container/radius/shadow, but image height `90px`, gradient `linear-gradient(140deg,#E0E4EA,#CBD3DD)` (flatter/greyer).
- Single top-right badge: "not-yet-verified" pill — fill `chip-neutral-fill` `#E9EDF3`, text `ink/secondary` `#5B6B80`, `1px solid #D4DBE4`, pill, padding `4px 10px`, `11px/800`, label `غير موثّق بعد`. No favorite, no transaction badge, no freshness stamp.
- Body: price `18px/900`; title `13.5px/700`; then a **caution note** replacing the meta line: `11.5px/700` `ink/secondary`, bg `surface/sunken` `#F5F7FA`, `1px dashed #D4DBE4`, radius `8px`, padding `5px 10px` — `يظهر بعد الموثّقة · عايِن قبل دفع أي عربون`. (Encodes ranking rule: unverified sorts below verified.)

---

### 2. Badges — status & transaction-mode

Base pill: radius `999px`, padding `6px 13px`, `12.5px/800`, `white-space:nowrap`; icon-bearing ones use filled Material icon `15px`, `gap:4px`. **Rule: one color = one meaning.**

| Badge | Label | Fill | Text | Border | Icon |
|---|---|---|---|---|---|
| Verified | موثّق | `success/verified` `#1F7A4D` | `#FFF` | — | `verified` (filled) |
| Featured | مميّز | `gold/featured` `#C2A14D` | `#FFF` | — | `workspace_premium` (filled) |
| Not-yet-verified | غير موثّق بعد | `chip-neutral-fill` `#E9EDF3` | `#5B6B80` | `1px #D4DBE4` | — |
| Under review | قيد المراجعة | `warn/review` `#E9A23B` | `#FFF` | — | — |

Transaction-mode badges (pill, `6px 13px`, `12.5px/800`):
- Sale (active): fill `brand/primary` `#1F4FE6`, white — `للبيع`.
- Rent-yearly / Rent-monthly-daily (secondary): fill `brand/primary-tint` `rgba(31,79,230,.1)`, text `brand/primary` `#1F4FE6` — `إيجار سنوي`, `إيجار شهري/يومي`.

---

### 3. Filter chips — `FilterChip`

Base: radius `999px`, padding `8px 14px`, `12.5px`, `white-space:nowrap`. Three states:
- **Default (unselected):** bg `#FFFFFF`, `1px solid hairline #E4E9F0`, text `ink/secondary` `#5B6B80`, weight `700`.
- **Selected:** bg `brand/primary-tint` `rgba(31,79,230,.08)`, `1px solid rgba(31,79,230,.3)`, text `brand/primary` `#1F4FE6`, weight `800`.
- **Selected + removable:** as selected, plus trailing `close` icon `14px`, `gap:4px`.
- **Verified-only special chip:** bg `rgba(31,122,77,.1)`, `1px solid #1F7A4D`, text `success/verified` `#1F7A4D`, `800`, leading filled `verified` icon `14px` — `الموثّقة فقط`. (Uses the verified color so the semantic tie is explicit.)

**Toggles / switches:** track `48×28`, radius `99px`; thumb `22×22`, radius `99px`, white, inset `3px`.
- On: track `brand/primary` `#1F4FE6`, thumb pinned start (`left:3px`).
- Verified-on: track `success/verified` `#1F7A4D`, thumb start.
- Off: track `hairline #E4E9F0`, thumb pinned `right:3px` with `box-shadow:0 1px 3px rgba(11,24,43,.2)`.

---

### 4. Buttons

Guidance from header: **primary 52px · secondary 44–48px · min touch 44px.** Font Tajawal `800`.

| Button | Height | Radius | Fill | Text | Border | Extras |
|---|---|---|---|---|---|---|
| Primary | `52px` | `14px` | `brand/primary` `#1F4FE6` | `#FFF` `16px` | none | shadow `0 8px 24px rgba(31,79,230,.3)` |
| WhatsApp | `52px` | `14px` | `whatsapp/green` `#1DAB61` | `#FFF` `16px` | none | filled `chat` icon `21px`, `gap:8px` |
| Call (outlined-brand) | `48px` | `14px` | `#FFFFFF` | `brand/primary` `#1F4FE6` `15px` | `1.5px #1F4FE6` | filled `call` icon `19px`, `gap:8px` |
| Secondary (outlined-neutral) | `48px` | `14px` | `#FFFFFF` | `ink/primary` `#0B182B` `15px` | `1.5px hairline #E4E9F0` | e.g. حجز معاينة |
| Disabled | `44px` | `12px` | `chip-neutral-fill` `#E9EDF3` | `ink/muted` `#9AA4B2` `14px` | none | non-interactive |
| Text | `44px` | `12px` | transparent (`none`) | `brand/primary` `#1F4FE6` `14px` | none | — |
| Icon button | `44×44` | `12px` | `brand/primary` `#1F4FE6` | icon `#FFF` `20px` | none | e.g. `tune` (filters) |

---

### 5. Inputs / text fields

All: height `50px`, radius `12px`, bg `#FFFFFF`, horizontal padding `14px`. Four states:
- **Default:** `1.5px solid hairline #E4E9F0`. Leading icon `20px` `ink/muted` `#9AA4B2` (e.g. `search`), placeholder `13.5px/500` `ink/muted` — `ابحث عن منطقة أو مدينة…`.
- **Focus:** `2px solid brand/primary #1F4FE6` + focus ring `box-shadow:0 0 0 3px rgba(31,79,230,.12)`. Value text `14px/800` `ink/primary`; trailing hint label `12px/700` `ink/muted`.
- **Error:** `2px solid danger/error #D64545`, trailing `error` icon `19px` in `#D64545`; help text below `11.5px/700` `#D64545`, `gap:4px` (e.g. phone-format message).
- **Select / dropdown:** `1.5px solid hairline`, stacked label+value at start (`المحافظة` label `10px/700` `ink/muted` over value `13.5px/800` `ink/primary`), trailing `keyboard_arrow_down` `19px` `ink/muted`.

---

### 6. Bottom nav — `NavigationBar` (M3) + extended FAB

- Bar: bg `#FFFFFF`, `1px solid hairline #E4E9F0`, radius `16px`, padding `10px 8px 14px`, 5 equal `flex:1` destinations.
- Each item: column, `gap:3px`, centered — pill-holder `56×30` over label `11px`.
  - **Active** (استكشف): pill bg `brand/primary-tint` `rgba(31,79,230,.12)` radius `999px`, filled icon `22px` `brand/primary` `#1F4FE6`, label `800` `#1F4FE6`.
  - **Inactive:** no pill (icon centered in the `56×30` box), outline icon `22px` `ink/muted` `#9AA4B2`, label `700` `#9AA4B2`.
  - Destinations: `home` استكشف · `travel_explore` بحث وخريطة · `favorite` المحفوظة · `chat_bubble` الرسائل · `person` حسابي.
  - **Notification badge** (on الرسائل): `min-width:16px`, height `16px`, radius `99px`, bg `accent/heart` `#F4795B`, white `10px/800`, padding `0 4px`, positioned `top:2px; left:10px` on the icon.
- **Extended FAB** (أضف عقار): height `52px`, radius `16px`, bg `brand/primary` `#1F4FE6`, white, `add_home` icon `22px` + label `15px/800`, padding `0 18px`, shadow `0 12px 28px rgba(31,79,230,.35)`. Floats above nav, **start-aligned in RTL** (i.e. right side).

---

### 7. State components

**Empty state** (empty saved — "always offers a next step"):
- Sunken panel `surface/sunken` `#F5F7FA`, radius `18px`, padding `28px 16px`, centered column, `gap:12px`, `text-align:center`.
- Icon medallion: `76×76`, radius `24px`, bg `rgba(244,121,91,.12)`, `favorite` icon `38px` in `accent/heart` `#F4795B`.
- Title `16px/900` `ink/primary` — `لا عقارات محفوظة بعد`.
- Body `13px/500` `ink/secondary` `#5B6B80`, line-height `1.8`, `max-width:260px`.
- CTA button: height `46px`, radius `12px`, `brand/primary` `#1F4FE6`, white `14px/800`, padding `0 22px` — `تصفّح عقارات دمشق`.

**Skeleton / shimmer loader — NOT present in section 08.** The section renders only card / badge / chip / button / input / nav / empty-state. There is no dedicated skeleton, no shimmer loader, and no offline/error state component in these lines (1797–1936). Derive the skeleton from card geometry (radius `16px`, image block `130px`/`90px`, three text bars) using a `surface/sunken → hairline` shimmer; the offline affordance is only *referenced* in copy ("يبقى متاحاً حتى دون اتصال" / "متاحاً دون اتصال") but has no standalone component here — flag both as gaps to be specified elsewhere in the design doc before build.

---

Source file: `H:\alnujom-project\New design\extracted2\Al Nujom UI.dc.html` (section 08, lines 1797–1935).

---

## NAV + ROUTER (current → target)

### Current tab enum + route mapping

`MainTab { home, reels, favorites, profile, none }` — defined in `lib/core/widgets/main_bottom_nav.dart:28`. Rendered order and route wiring inside `MainBottomNav.build`:

| Slot (visual order) | Enum | Nav call | Route |
|---|---|---|---|
| Home | `home` | `context.go(AppRoutes.home)` | `/` → `HomePage` |
| Reels | `reels` | `context.go(AppRoutes.reels)` | `/reels` → `ReelsTabPage` |
| **+Publish** (FAB, publishers only) | — (never a tab) | `context.pushNamed(AppRouteNames.publisherListingsCreate)` | `/publisher/listings/create` |
| Favorites | `favorites` | `context.go(AppRoutes.favorites)` | `/favorites` (auth-gated → `/login`) |
| Profile | `profile` | `context.go(isSignedIn ? AppRoutes.profile : AppRoutes.login)` | `/profile` or `/login` |

`MainTab.none` = "highlight nothing"; used by surfaces that host the bar but aren't a tab (e.g. Search reachable from the Home hero bar renders under `none`).

### How the three nav pieces are wired

- **Bottom nav** (`MainBottomNav`, `main_bottom_nav.dart`): a custom bar (not Material `NavigationBar`), driven by `current: MainTab`. Each host page passes its own `MainTab`. Tab switches use `context.go` (clean stack roots); the FAB uses `context.pushNamed`. Guarded by `BlocBuilder<AuthBloc, AuthState>` — `isApprovedPublisher` (accountStatus==approved && publisherStatus==approved) gates the Publish FAB.
- **Publish FAB** (`_PublishFab`, same file, lines 231-281): elevated rounded-square lifted `-20px` above the bar, inserted into the `slots` list between Reels and Favorites only when `isApprovedPublisher`. Not a `MainTab`.
- **Right-side nav drawer** (`AppNavDrawer`, `app_nav_drawer.dart`): Phase 030 (W5). Opens from start side = RIGHT under RTL. Hosted by `HomePage` via `Scaffold.drawer: const AppNavDrawer()` (`home_page.dart:169`) + a hamburger `IconButton` in the AppBar leading (`home_page.dart:173-179`) calling `Scaffold.of(context).openDrawer()`. Sections: Selling (dashboard/CRM/inquiries/my-listings/agency), Admin, **Activity → Messages (chat) + Viewings**, More (reports/about). Chat + Viewings are opened via `Navigator.push(MaterialPageRoute)` with their own `BlocProvider` (not go_router routes).

### go_router + AppRoutes/AppRouteNames

- `app_router.dart` defines two constant classes: `AppRoutes` (path strings, `abstract final class`, lines 83-176) and `AppRouteNames` (route names, lines 178-266). `buildAppRouter(...)` builds a single `GoRouter` with `rootNavigatorKey`, a `redirect` (maintenance gate → `authRedirect`), and a flat `routes:` list of `GoRoute`s.
- Relevant existing routes: `home = '/'` (line 92, `HomePage`), `reels = '/reels'` (line 125, `ReelsTabPage`, line 605-609), `search = '/search'` (line 120, `SearchPage`, line 578-593, anonymous-accessible, takes `PropertyType`/`FilterState` via `state.extra` + `?focus=1`), `favorites` (line 135, auth-gated), `profile` (line 108). There is **no** go_router route for chat/conversations — it exists only as a `MaterialPageRoute` push (`ConversationsListPage` + `ConversationsCubit`) from the drawer.

### Where Reels + Search currently live

- **Reels**: a full bottom-nav tab → `/reels` → `ReelsTabPage` (`features/reels/presentation/pages/reels_tab_page.dart`). ALSO already folded into Home as a rail: `home_page.dart:256` renders `const ReelsRail()` (`features/reels/presentation/widgets/reels_rail.dart`, self-wired `ReelsRailCubit`, hides on empty).
- **Search**: NOT a tab (Phase 030 replaced the Search tab with Reels). Route `/search` (`SearchPage`) still exists and is reached from `HeroSearchBar` on Home and from property-type chips. `AppBottomNav` (`app_bottom_nav.dart`) is a **separate, legacy 5-slot bar** [الرئيسية/البحث/إضافة/المفضلة/حسابي] that is NOT the one used by HomePage — `MainBottomNav` is. Verify whether `AppBottomNav` is still referenced anywhere before reusing/deleting it.

---

## What must change to reach the target 5-tab IA

Target: استكشف(home) · بحث+خريطة(search) · المحفوظة(favorites) · الرسائل(chat) · حسابي(profile) + أضف عقار FAB, Reels folded into Home rail (drop Reels as a tab).

### 1. `lib/core/widgets/main_bottom_nav.dart` (primary edit)
- **Enum** `MainTab` (line 28): replace `reels` with `search` and add `chat` → `MainTab { home, search, favorites, chat, profile, none }`.
- **Slots list** (lines 72-121):
  - Replace the Reels `_NavTab` (lines 81-88) with a **Search** tab: icon `LucideIcons.search` (or `search`/`map` composite), label `l10n.search_*`, `onTap: () => context.go(AppRoutes.search)`, `current == MainTab.search`.
  - Keep Publish FAB between search and favorites (or reposition per 5-tab layout — FAB currently sits at index 2; with 5 real tabs + FAB you'll need to decide FAB placement, e.g. centered as a 5-tab + floating action, or drop to 4 tabs + center FAB. Note: 5 tabs + a center FAB = 6 slots, which is crowded — confirm intended layout).
  - Add a **Chat** tab (الرسائل): icon `LucideIcons.message_circle`/`Icons.forum_outlined`, label new l10n key, `current == MainTab.chat`, and it needs a **route to go to** (see #4). Auth-gated like favorites/profile.
- Consider an unread badge on the Chat tab (a `ConversationsCubit`/unread cubit already exists — used in drawer).

### 2. `lib/core/routing/app_router.dart`
- Add a **chat route**: new `AppRoutes.chat = '/chat'` + `AppRouteNames.chat = 'chat'`, and a `GoRoute` building `ConversationsListPage` wrapped in `BlocProvider<ConversationsCubit>(create: (_) => getIt<ConversationsCubit>())` (auth-gated redirect → `/login`, mirroring favorites at lines 672-678). Currently chat has no go_router route — `context.go` from a tab needs one.
- Decide fate of `/reels` route (lines 602-609): can remain as a deep-link/pushed page (Reels rail "see all" target) even though it's no longer a tab. No deletion strictly required.
- `/search` (lines 578-593) already exists and is anonymous-accessible — reuse as-is; optionally fold the map affordance in (بحث+خريطة) — `/map` exists (line 127) if you want a combined entry.

### 3. `lib/features/home/presentation/pages/home_page.dart`
- `bottomNavigationBar: const MainBottomNav(current: MainTab.home)` (line 219) — stays `MainTab.home`, no change beyond enum rename compiling.
- Reels rail already present (`ReelsRail()`, line 256) — keep. This is the "Reels folded into Home" piece; no work needed there beyond confirming it stays.
- Every OTHER tab host page passes its own `MainTab` to `MainBottomNav` — those must be updated for the renamed/added enum values:

### 4. All `MainBottomNav(current: …)` call sites
Grep `MainBottomNav(current:` across `lib/` and update each:
- `ReelsTabPage` currently passes `MainTab.reels` — either repurpose it (no longer a tab → `MainTab.none`) or remove its bar.
- `SearchPage` — should now pass `MainTab.search` (currently likely `MainTab.none`).
- `FavoritesPage` → `MainTab.favorites`, `ProfilePage` → `MainTab.profile` (unchanged).
- A new `ConversationsListPage` tab host → `MainTab.chat`, and it must host the bottom nav + drawer if it's now a top-level tab.

### 5. l10n
- New ARB keys for the Chat tab label (الرسائل) and a Search tab label if `l10n.nav_reels` is being retired. Existing keys: `nav_reels`, `nav_publish` (retire/repurpose `nav_reels`). Every new ARB key needs a matching `@override` in `_DebugAppLocalizations` (`app_strings.dart`) or `flutter analyze` fails (per project memory). `chatMessagesTile` already exists (used in drawer) and can seed the Chat label.

### 6. `lib/core/widgets/app_nav_drawer.dart`
- Chat currently lives ONLY in the drawer (Activity section, lines 168-182) as a `MaterialPageRoute` push. If Chat becomes a bottom-nav tab, decide whether to **remove it from the drawer** (to avoid duplication) and switch the drawer's remaining nav to the shared `/chat` route. Viewings stays in the drawer.

### 7. Legacy `lib/core/widgets/app_bottom_nav.dart`
- This standalone 5-slot bar [الرئيسية/البحث/إضافة/المفضلة/حسابي] already encodes the *old* 5-tab IA shape via `AppDimens.bottomNavAddIndex`. Verify it's dead (grep references); if used anywhere, reconcile or delete. It is NOT wired into HomePage.

### Key open decisions for the implementer
- 5 tabs + center Publish FAB = 6 slots (crowded). Confirm layout: 5 tabs with FAB as one of them / centered, or 4 tabs + center FAB with profile in drawer.
- بحث+خريطة: whether Search tab also surfaces Map (`/map` exists) or Search page absorbs a map toggle.
- Reels: keep `/reels` as a pushed deep page (rail "see all") vs delete route entirely.

Files to edit: `lib/core/widgets/main_bottom_nav.dart`, `lib/core/routing/app_router.dart`, `lib/features/home/presentation/pages/home_page.dart`, `lib/core/widgets/app_nav_drawer.dart`, all `MainBottomNav(current:)` host pages (`reels_tab_page.dart`, `search_page.dart`, `favorites_page.dart`, `profile_page.dart`, new chat tab host), the ARB files + `app_strings.dart` (`_DebugAppLocalizations`), and possibly retire `lib/core/widgets/app_bottom_nav.dart`.

---

I have everything needed. Here's the map.

## THEME + TOKEN SYSTEM

A single source of truth (the palette) flows: `AppPaletteTokens` → `ColorScheme` + `AppColorTokens` (ThemeExtension) → `ThemeData` → runtime accessors (`AppColors.of`, `AppTextStyles.of`, etc.). Widgets never touch raw values; a regex linter (`tool/lint_design_tokens.dart`) forbids literals outside the 8 whitelisted theme files.

### File map (`lib/core/theme/`)
- `color_palette.dart` — the DATA. `AppPaletteTokens` (30-field immutable struct) + the `ColorPalette` classes that hold the light/dark instances. **This is the primary file a designer edits to recolor the app.**
- `colors.dart` — `AppColors` (runtime color accessor) + `AppColorTokens` (the ThemeExtension carrying the ~17 tokens Material's `ColorScheme` can't hold).
- `typography.dart` — `AppTextStyles` (13 named text styles, locale-aware font selection).
- `spacing.dart` / `radii.dart` — bare `double` constant scales.
- `elevation.dart` — `AppElevation` (shadow ramps, light vs dark).
- `gradients.dart` — `AppGradients` (derived from color tokens, never raw).
- `motion.dart` — `AppMotion` (durations/curves; NOT linter-restricted).
- `app_theme.dart` — `buildAppTheme()` wires tokens into `ThemeData` (component themes: buttons, cards, chips, inputs, nav, dialogs, sheets, snackbar).
- `lib/core/widgets/_widget_support.dart` — helper fns `appRadius()` / `appPadding()` (NOT a theme file; these exist so widget code can produce a `BorderRadius`/`EdgeInsets` from a token without tripping the linter).

### How tokens are exposed at runtime

**`AppColors.of(context)`** (`colors.dart:77`) — reads `Theme.of(context).colorScheme` for standard M3 roles AND `Theme.of(context).extension<AppColorTokens>()` for the extra tokens, merging them into one flat `AppColors` with **32 color fields** (the 30 palette fields minus the ones folded into ColorScheme, plus derived `divider` = outline and `disabledOverlay` = `onSurface.withAlpha(0x61)`). Every non-scheme field has a scheme fallback (`tokens?.accent ?? scheme.tertiary`). Also constructible directly from a palette via `AppColors.fromTokens()` (used inside `buildAppTheme`).

**`AppTextStyles.of(context)`** (`typography.dart:23`) — pulls colors from `AppColors.of(context)` then delegates to `forLocale()`. Picks the font family by locale: **Arabic → `Tajawal`, Latin → `Inter`** (for both display and body). Exposes 13 styles: `displayLarge/Medium`, `headlineLarge/Medium`, `titleLarge/Medium`, `bodyLarge/Medium`, `labelLarge/Medium`, `priceLarge/Medium/priceCurrency`. Each built via `_style()` which computes `height = lineHeight/size`.

**`AppSpacing`** (`spacing.dart`) — pure static `const double`s, no context: `xxs 2, xs 4, sm 8, md 12, lg 16, xl 24, xxl 32, xxxl 48`.

**`AppRadii`** + **`appRadius()`** — `AppRadii` (`radii.dart`) is static consts `sm 8, md 12, lg 16, xl 24, pill 999`. `appRadius([double radius = AppRadii.md])` (`_widget_support.dart:12`) is a free function returning `BorderRadius.circular(radius)` — widgets call `appRadius(AppRadii.lg)` instead of a raw `BorderRadius.circular(16)` (which the L4 rule forbids).

**`AppElevation.of(context)`** (`elevation.dart:14`) — branches on `Theme.of(context).brightness`. Returns 5 fields: `level0` (empty), `level1/2/3` (`List<BoxShadow>` ramps — dark uses black shadows + a hairline border; light uses two-layer slate-tinted soft shadows), and `hairline` (a `BoxBorder`). Widgets use these instead of raw `BoxShadow` (L5).

**`AppGradients.of(context)`** — 3 gradients (`photoScrim`, `photoTopScrim`, `featuredTint`) derived from `AppColors`.

### AppPaletteTokens — full 30-field list
All `Color`, required. Values below are the active `ModernPalette` (Steel & Star), light / dark:

| Field | Light | Dark |
|---|---|---|
| primary | 0xFF1F4FE6 | 0xFF5896FF |
| onPrimary | 0xFFFFFFFF | 0xFF06122B |
| primaryContainer | 0xFFDCE6FB | 0xFF16315F |
| onPrimaryContainer | 0xFF11317A | 0xFFCFE0FF |
| accent | 0xFFF4795B | 0xFFFF8E72 |
| onAccent | 0xFFFFFFFF | 0xFF3A1207 |
| accentContainer | 0xFFFBE5DC | 0xFF4A2114 |
| secondary | 0xFF0F172A | 0xFFE7ECF5 |
| onSecondary | 0xFFFFFFFF | 0xFF0B1220 |
| tertiary (gold/featured) | 0xFFC2A14D | 0xFFD9B86A |
| success | 0xFF2E9E6B | 0xFF4CB587 |
| warning | 0xFFC98318 | 0xFFE2B25A |
| error | 0xFFD23F3F | 0xFFF0706E |
| surface | 0xFFF5F7FA | 0xFF0B1020 |
| surfaceVariant | 0xFFEAEFF5 | 0xFF161C2D |
| card | 0xFFFFFFFF | 0xFF161C2D |
| outline | 0xFFE2E8F0 | 0xFF252E44 |
| outlineStrong | 0xFFCBD5E1 | 0xFF38446A |
| onSurface | 0xFF0F172A | 0xFFEAF0FB |
| onSurfaceVariant | 0xFF475569 | 0xFF9FABC4 |
| textMuted | 0xFF64748B | 0xFF8694AC |
| verified | 0xFF1F7A4D | 0xFF57C48C |
| verifiedContainer | 0xFFDCF0E5 | 0xFF163A2A |
| onError | 0xFFFFFFFF | 0xFF420A0A |
| onSuccess | 0xFFFFFFFF | 0xFF04231A |
| onPhoto | 0xFFFFFFFF | 0xFFFFFFFF |
| photoOverlay | 0x8C0F172A | 0x8C05080F |
| scrim | 0x66000000 | 0x99000000 |
| whatsapp | 0xFF1DAB61 | 0xFF25D366 |
| onWhatsapp | 0xFFFFFFFF | 0xFF05301B |

`ColorPalette` is a `sealed` base with two concrete palettes — `ModernPalette` (`name: 'modern'`, the `defaultPalette`) and `TrustPalette` (`name: 'trust'`, selectable via `ColorPalette.fromName`). `_scheme()` (line 37) maps tokens into `ColorScheme.fromSeed(...).copyWith(...)`, hard-coding `onTertiary = 0xFF1A1714` (dark ink on gold) and killing the M3 elevation tint (`surfaceTint: transparent`, surface-container ramp all driven from tokens).

### How the LINTER decides violations (`tool/src/lint_design_tokens_lib.dart`)

It is a **regex scanner over `.dart` source** (not an AST). Files whose repo-relative path is in `_defaultAllowedFiles` are **skipped entirely** — exactly these 8 theme files:
`lib/core/theme/{colors,typography,spacing,radii,elevation,color_palette,app_theme,gradients}.dart`. Everything else in `lib/` (and `test/`) is scanned.

Rules (a match = a violation, printed and exit code 1):
- **L1** `\bColor(\s*0x[0-9A-Fa-f]+` — forbidden raw color literal → use `AppColors.of(context)`.
- **L2** `\bTextStyle\s*(` — forbidden inline `TextStyle` → use `AppTextStyles.of(context)`.
- **L6** `archive/luxury|Playfair Display|Reem Kufi` — forbidden archived design references.
- **L3** raw `EdgeInsets`/`EdgeInsetsDirectional.all|symmetric|only|fromLTRB|fromSTEB(` **with a numeric literal arg** → use `AppSpacing`.
- **L4** `BorderRadius.circular( <number>` → use `AppRadii` / `appRadius()`.
- **L5** `BoxShadow(... blurRadius|spreadRadius|offset: <number>` → use `AppElevation`.

L1/L2/L6 always run. **L3/L4/L5 (spacing/radius/shadow) are suppressed for `test/` files** (`includeSpacingRules: !isTestFile`). Note the checks are purely syntactic: `EdgeInsets.symmetric(horizontal: AppSpacing.lg)` passes (no bare number), `appRadius(AppRadii.lg)` passes, but `BorderRadius.circular(16)` fails. **`AppMotion` durations/curves are explicitly NOT restricted** — widgets may use raw `Duration`/`Curve`.

### Fonts — registration
Registered in `pubspec.yaml` under `flutter: fonts:` (lines 103-137), as bundled `.ttf` assets in `assets/fonts/`:
- **Tajawal** (active Arabic UI/body/heading): weights 400/500/700/800.
- **Inter** (active Latin): weights 400/500/600/700.
- Cairo and IBMPlexSansArabic are also registered but unused by the current `typography.dart` (legacy). Only the family strings `'Tajawal'` / `'Inter'` in `typography.dart:42-43` select which is used.

---

### What a developer edits to match a new design
1. **Colors:** edit the `_lightTokens` / `_darkTokens` maps in `color_palette.dart` (`ModernPalette`). All 30 fields per mode. That single edit propagates through `AppColors`, `ColorScheme`, component themes, gradients, and elevation-shadow tints. To add a brand-new color role you must add the field to `AppPaletteTokens` (+ its ctor/getters), thread it through `AppColors` and (if not a native `ColorScheme` role) `AppColorTokens` (fields, `fromPalette`, `copyWith`, `lerp`, and `AppColors.of`/`fromTokens`).
2. **Type:** edit sizes/weights/line-heights in `typography.dart`; swap the font family strings there and register the new `.ttf` in `pubspec.yaml`.
3. **Spacing / radii:** edit the constants in `spacing.dart` / `radii.dart`.
4. **Shadows / gradients / motion:** edit `elevation.dart` / `gradients.dart` / `motion.dart`.
5. **Component look (button shape, card radius, input fill, nav colors):** edit `buildAppTheme()` in `app_theme.dart`.
6. **Branding (icon/splash):** edit the `flutter_launcher_icons` / `flutter_native_splash` blocks in `pubspec.yaml` (assets in `assets/branding/`), then regen.

### Rules new widget code must follow to keep the linter green
- Colors: `AppColors.of(context).<field>` — never `Color(0x...)`.
- Text: `AppTextStyles.of(context).<style>` (`.copyWith` for tweaks) — never a bare `TextStyle(...)`.
- Padding/margins: `AppSpacing.*` (optionally via `appPadding(...)`) — never a numeric literal inside `EdgeInsets.*`.
- Corner radius: `appRadius(AppRadii.*)` or `BorderRadius.circular(AppRadii.*)` — never `BorderRadius.circular(<number>)`.
- Shadows: `AppElevation.of(context).level1/2/3` — never an inline `BoxShadow(... blurRadius: <number> ...)`.
- Gradients: `AppGradients.of(context)`; Motion: `AppMotion.*` (allowed raw).
- Never reference `archive/luxury`, `Playfair Display`, or `Reem Kufi`.
- Feature/widget code (anything outside the 8 theme files) is always scanned; do not add new files to `_defaultAllowedFiles` to dodge the rules. Run `dart run tool/lint_design_tokens.dart` to verify.

Key file paths: `H:\alnujom-project\lib\core\theme\color_palette.dart`, `H:\alnujom-project\lib\core\theme\colors.dart`, `H:\alnujom-project\lib\core\theme\typography.dart`, `H:\alnujom-project\lib\core\theme\app_theme.dart`, `H:\alnujom-project\tool\src\lint_design_tokens_lib.dart`, `H:\alnujom-project\lib\core\widgets\_widget_support.dart`, `H:\alnujom-project\pubspec.yaml`.

---

## FEATURE INVENTORY

**Nav shell** (`lib/core/widgets/main_bottom_nav.dart`): `enum MainTab { home, reels, favorites, profile, none }`. The 5 primary tabs are **Home · Reels · [+Publish FAB] · Favorites · Profile** (Search was demoted from a tab in Phase 030 — still reachable from the Home search bar). The center "+Publish" is a publishers-only FAB that pushes the create-listing form, not a tab.

### Target-tab → feature-dir map
| Target | Feature dir(s) | Entry page |
|---|---|---|
| Tab 1 · Home | `home` | `pages/home_page.dart` |
| Tab 2 · Reels | `reels` | `pages/reels_tab_page.dart` (wraps `reels_feed_page.dart`) |
| Center · Add-listing | `listing_form` | `pages/listing_form_page.dart` (+ `listing_detail_form_page.dart`, `listing_express_form_page.dart`) |
| Tab 3 · Favorites | `favorites` | `pages/favorites_page.dart` |
| Tab 4 · Profile | `profile` | `pages/profile_page.dart` (+ `profile_edit_page.dart`, `profile_private_page.dart`) |
| (demoted) Search | `search` | `pages/search_page.dart` |
| Login/Signup | `auth` | `pages/login_page.dart`, `pages/register_page.dart` |
| Notifications | `notifications` | `pages/notification_center_page.dart` |

---

### (A) Rebuild-to-new-design — user-facing hero/secondary screens

**home** — HERO
- Pages: `home_page.dart`
- Bloc/Cubit: `home_bloc.dart`, `featured_listings_cubit.dart`
- Widgets: `featured_hero_card.dart`, `featured_listings_carousel.dart`, `featured_mini_card.dart`, `hero_search_bar.dart`, `home_listing_card.dart`, `inquiries_app_bar_action.dart`, `map_entry_tile.dart`, `property_type_shortcut_row.dart`

**listing_details** — HERO (secondary)
- Pages: `listing_details_page.dart`, `panorama_tour_page.dart`
- Blocs/Cubits: `listing_details_bloc.dart`, `market_insights_cubit.dart`, `nearby_amenities_cubit.dart`, `similar_listings_cubit.dart`
- Widgets: `affordability_calculator.dart`, `buyer_safety_banner.dart`, `contact_block.dart`, `listing_details_skeleton.dart`, `listing_facts_block.dart`, `market_insights_section.dart`, `nearby_amenities_section.dart`, `per_listing_action_block.dart`, `similar_listing_card_tile.dart`, `similar_listings_carousel.dart`, `similar_listings_empty.dart`

**search** — HERO (secondary; still core even if not a tab)
- Pages: `search_page.dart`, `saved_searches_page.dart`
- Blocs/Cubits: `search_bloc.dart`, `recent_searches_cubit.dart`, `saved_searches_cubit.dart`
- Widgets: `inline_sort_control.dart`, `price_range_input.dart`, `recent_searches_panel.dart`, `save_search_dialog.dart`, `search_filter_sheet.dart`, `search_map_view.dart`, `search_result_card.dart`

**listing_form** — HERO (Add-listing / center FAB)
- Pages: `listing_form_page.dart`, `listing_detail_form_page.dart`, `listing_express_form_page.dart`
- Bloc: `listing_form_bloc.dart`
- Widgets: `detail_form_sections.dart`, `express_form_fields.dart`, `media_picker.dart`, `media_thumbnail.dart`, `price_preview_subline.dart`, `publish_success_dialog.dart`, `required_field_chip.dart`, `revision_banner.dart`, `step_basics/details/location/media/prices/review/visibility.dart`, `step_progress_indicator.dart`, `step_section.dart`, `submit_failure_dialog.dart`

**favorites** — tab
- Pages: `favorites_page.dart`
- Blocs/Cubits: `favorites_cubit.dart`, `favorites_page_bloc.dart`
- Widgets: `favorite_card.dart`, `favorite_heart_button.dart`, `favorites_empty_state.dart`, `favorites_sort_bar.dart`

**profile** — tab
- Pages: `profile_page.dart`, `profile_edit_page.dart`, `profile_private_page.dart`
- Cubit: `profile_cubit.dart`; Widgets: none

**reels** — tab
- Pages: `reels_tab_page.dart`, `reels_feed_page.dart`
- Cubits: `reels_feed_cubit.dart`, `reels_rail_cubit.dart`
- Widgets: `reel_player.dart`, `reels_rail.dart`

**auth** — Login/Signup
- Pages: `login_page.dart`, `register_page.dart`, `reset_password_page.dart`, `pending_approval_page.dart`, `publisher_approval_pending_page.dart`, `rejected_page.dart`, `suspended_page.dart`
- Bloc: `auth_bloc.dart`; Widgets: `auth_status_message.dart`, `auth_text_field.dart`, `auth_trust_note.dart`

**notifications**
- Pages: `notification_center_page.dart`
- Cubits: `notifications_cubit.dart`, `notification_badge_cubit.dart`
- Widgets: `notification_bell_action.dart`, `notification_tile.dart`, `notification_deep_link_resolver.dart`*, `notification_push_listener.dart`* (*logic — see C)

**onboarding** — first-run/splash
- Pages: `onboarding_page.dart`, `splash_page.dart`; Cubit: `onboarding_cubit.dart`

**map** — user-facing (reachable from Home/Search)
- Pages: `map_page.dart`; Bloc: `map_bloc.dart`
- Widgets: `center_on_my_location_fab.dart`, `filter_active_alert_dialog.dart`, `map_control_button.dart`, `map_refresh_button.dart`, `marker_pins.dart`, `marker_preview_popover.dart`, `osm_attribution_widget.dart`

**assistant** — user-facing helper
- Pages: `assistant_page.dart`; Cubit: `assistant_cubit.dart`

**chat** — user-facing (secondary)
- Pages: `conversations_list_page.dart`, `chat_thread_page.dart`
- Cubits: `conversations_cubit.dart`, `chat_thread_cubit.dart`

**viewings** — user-facing (secondary)
- Pages: `viewings_list_page.dart`; Cubit: `viewings_cubit.dart`

**comparison** — user-facing (secondary)
- Pages: `comparison_page.dart`; Cubit: `comparison_cubit.dart`; Widgets: `compare_bottom_bar.dart`, `compare_toggle_button.dart`

**settings** — user-facing support pages
- Pages: `about_support_page.dart`, `maintenance_screen.dart`; Cubit: `app_settings_cubit.dart`; Widgets: `maintenance_gate.dart`, `support_contact_row.dart`

**inquiries** — user-facing (3 pages; surfaced via Home app-bar action `inquiries_app_bar_action.dart`)

### (C) Supporting logic / embedded widgets reused by new screens (no standalone hero page)
- **reviews** — `seller_trust_cubit.dart` + `seller_reviews_section.dart`, `seller_trust_summary.dart` (embedded in listing_details / profile)
- **recently_viewed** — `recently_viewed_cubit.dart` + `recently_viewed_card.dart`, `recently_viewed_carousel.dart` (embedded in home/details)
- **notifications** logic bits — `notification_deep_link_resolver.dart`, `notification_push_listener.dart` (wiring, not visual)
- **currencies** (5 pages, mostly admin CRUD but currency display/format reused), **locations** (5 pages; city/area pickers reused by search & listing_form), **app_update** (0 pages — update-gate logic/dialogs)

### (B) Keep-as-is / internal — inherit theme only (no rebuild)
- **admin** (11 pages), **super_admin** (4 pages), **agency** (7 pages), **publisher_dashboard** (4 pages), **dashboard** (1 page), **crm** (2 pages), **reports** (1 page), **ads** (2 pages)
- Also largely internal/admin CRUD: **currencies** (5 pages), **locations** (5 pages) — inherit theme; only their user-facing picker widgets touch category C.

Notes: `chat`, `profile`, `viewings`, `assistant`, `onboarding` have **no** `widgets/` subdir (logic lives in pages). Reels entry is `reels_tab_page.dart` (tab wrapper) not `reels_feed_page.dart`.

---

## SHARED WIDGETS + L10N + DATA MODEL

### 1. Shared listing card + `listing_display` widgets (the property-card anatomy)

There is **no single canonical card** — four parallel implementations plus a detail-block set:

- **`lib/core/widgets/property_card.dart`** — the generic, DS-styled, callback-based card (`PropertyCard`). Anatomy: `AppSurface` (elevated) → `AspectRatio(4x3)` image with `AppBadge` featured pill (top-start) + `_FavoriteChip` heart (top-end) + placeholder → `_body`: `titleLarge` title (2 lines) → `PriceTag(amount, currency)` → `map_pin` + location row → optional `agencyBadge` slot. Two layouts: `vertical` (fixed `propertyCardVerticalWidth`) / `horizontal`. Pure token consumption (`AppColors/AppSpacing/AppRadii/AppElevation/AppTextStyles`, `flutter_lucide`). **Takes plain strings** — no listing entity, no rooms/baths/area/verified fields.
- **`lib/features/search/presentation/widgets/search_result_card.dart`** — Phase-33-restyled horizontal card bound to `SearchResultItem`. 116×116 photo (`GlassPill` purpose tag + `FavoriteHeartButton` + `AgencyBadge`/`_ByOwnerPill` overlay) → title → location → `priceMedium` price → single `_MetaItem` (property type only). **Explicitly documents (lines 15-19) that `SearchResultItem` carries NO beds/baths/area** — so surfacing those facts on the card requires an entity + datasource + SQL change, not a restyle.
- **`lib/features/home/presentation/widgets/home_listing_card.dart`** (bound to `HomeListingCard`), **`lib/features/listing_details/presentation/widgets/similar_listing_card_tile.dart`**, **`lib/features/publisher_dashboard/presentation/widgets/listing_card.dart`**, **`lib/shared/presentation/widgets/listing_card.dart`** — feature-owned variants (each feature owns its own card surface; they do NOT cross-import).
- **`lib/shared/presentation/widgets/listing_display/`** = **detail-page blocks, not cards**: `listing_gallery.dart`, `fullscreen_gallery_viewer.dart`, `listing_price_block.dart`, `listing_location_block.dart`, `listing_amenities_block.dart`, `listing_description_block.dart`. These are the reusable detail-screen sections.

Trust/badge widgets to reuse: `lib/features/agency/presentation/widgets/agency_badge.dart` (+ `listing_agency_badge.dart`), `core/widgets/glass_pill.dart`, `core/widgets/app_badge.dart`, `favorites/.../favorite_heart_button.dart`, `core/widgets/price_tag.dart`, `core/widgets/press_scale.dart`, `core/widgets/app_network_image.dart`.

### 2. Search FilterState + `search_listings` RPC — what exists vs. what's missing

**`lib/features/search/domain/entities/filter_state.dart`** — existing filter fields: `query`, `purpose`, `propertyType`, `governorateId`, `cityId`, `areaId`, `priceMin/Max/Currency`, `rooms`+`roomsMode`, `bathrooms`+`bathroomsMode`, `areaSizeMin/Max`, `furnished` (bool), `parking` (bool), `amenities` (Set<String> JSONB containment), `isAgency` (bool: owner/agency/any), `displayMode` (view-only). Has full `toJson`/`fromJson` (saved-searches JSONB) + `copyWith` with clear-sentinels + `hasAnyActiveFilter`/`isEmpty`/`props`.

The RPC call is centralized in **`lib/features/search/data/datasources/supabase_search_datasource.dart`** (`_client.rpc('search_listings', params)`, the sole `supabase_flutter` importer under `features/search/`) — each filter maps to a `p_*` param sent only when non-null.

**MISSING (confirmed absent codebase-wide):** `deed`/طابو type, `finish`/`finishLevel`/كسوة/تشطيب level, and any listing-level `verified`/verification field. The only "verification" in the code is **agency** verification (`features/agency/**`, `features/admin/agencies/**`) — unrelated to listing trust. The redesign brief (`docs/brand/redesign-brief.md` lines 28, 47-48, 77-81, 102, 179) explicitly calls for **new backend columns**: deed type (طابو أخضر/أحمر/مؤقت/زراعي), finish level (على العظم→سوبر ديلوكس), and a listing verification model + "الموثّقة فقط" filter. **These are new fields → new `FilterState` fields + new `p_*` RPC params + new migrations, not achievable as a visual restyle.**

### 3. l10n mechanics — the triple-write rule for every new key

- ARB source: **`lib/l10n/app_en.arb`** (template, per `l10n.yaml`: `arb-dir: lib/l10n`, `synthetic-package: false`) + **`lib/l10n/app_ar.arb`**. ~862 keys today.
- Generated: `lib/l10n/app_localizations.dart` + `_en.dart` + `_ar.dart` (`AppLocalizations.of(context)`).
- **`lib/core/localization/app_strings.dart` (6405 lines)** wraps generation with `_DebugAppLocalizations` (line 77), which **`@override`s every getter** and, in debug + Arabic, flags any key whose value equals the English baseline as a missing-translation marker (`_intentionallyIdenticalKeys` allowlist for genuinely-identical values like symbols).

**Rule (matches memory note):** every new ARB key needs (a) entry in `app_en.arb`, (b) entry in `app_ar.arb`, (c) an `@override` `_resolve('key', (loc) => loc.key)` in `_DebugAppLocalizations` — omitting (c) breaks `flutter analyze`. This file is a known wave merge-contention point (union it). Parameterized keys (e.g. `priceWithCurrency`) follow the same pattern with a function override.

### 4. Data model — listing entity/auth (verification/deed/finish presence)

**`lib/features/listing_form/domain/entities/listing.dart`** — `Listing` fields: id, publisherUserId, agencyId, purpose (`ListingPurpose`: sale/rent/dailyRent/investment), propertyType (`PropertyType`: apartment/villa/land/shop/office/farm/warehouse/other), status, title, governorate/city/areaId, addressText, lat/long, locationVisibility, phone/whatsapp, contactNameVisibility, areaSize, rooms, bathrooms, floor, timestamps. **No deed / finish / verified / verifiedAt fields.**

**`lib/features/listing_form/domain/entities/listing_details.dart`** — `ListingDetails`: description, `amenities` (List<String>), yearBuilt, furnished (bool?), parking (bool?), timestamps. **No deed/finish/verification.**

Auth pages already built (reusable shells to restyle): `login_page.dart`, `register_page.dart`, `reset_password_page.dart`, `pending_approval_page.dart`, `publisher_approval_pending_page.dart`, `rejected_page.dart`, `suspended_page.dart`, plus widgets `auth_text_field.dart`, `auth_status_message.dart`, `auth_trust_note.dart`. No listing-verification concept lives here (the account/publisher approval gate is a separate `account_status`/`publisher_status` mechanism per memory).

---

### Reuse vs. new (for the new screens)

**Reuse as-is (token-clean, restyle-only):** `PropertyCard` + all card variants, the `listing_display/` detail blocks, `AgencyBadge`/`GlassPill`/`AppBadge`/`FavoriteHeartButton`/`PriceTag`/`AppNetworkImage`/`PressScale`, the whole `FilterState`→`supabase_search_datasource` RPC pipeline for existing filters, saved-searches JSON round-trip, and the l10n triple-write pattern.

**New fields / keys / migrations required (backend + model, out of pure-restyle scope):**
- **Listing verification** — new columns (verified flag + site-visit/geotag/freshness-timestamp per brief), a listing-level `verified` on `Listing`/`SearchResultItem`, a "verified ranks first" sort + `p_verified_only` RPC param + `FilterState.verifiedOnly`, and a verified card variant/badge.
- **Deed type** (طابو أخضر/أحمر/مؤقت/زراعي) — enum + column + `FilterState.deedType` + `p_deed_type` + migration.
- **Finish level** (على العظم→سوبر ديلوكس) — enum + column + `FilterState.finishLevel` + `p_finish_level` + migration.
- **Card facts** — to show غرف/حمامات/مساحة/طابق/كسوة/طابو tiles on the search card, `SearchResultItem` + the `search_listings` projection (`v_listings_public`) need rooms/baths/area/floor/finish/deed added (currently absent).
- Each new field ⇒ ARB keys in both `app_en.arb`/`app_ar.arb` + `@override` in `_DebugAppLocalizations` (`app_strings.dart`); each new column ⇒ a Supabase migration applied via MCP `apply_migration` per-file.

Key files: `H:\alnujom-project\lib\core\widgets\property_card.dart`, `H:\alnujom-project\lib\features\search\presentation\widgets\search_result_card.dart`, `H:\alnujom-project\lib\shared\presentation\widgets\listing_display\`, `H:\alnujom-project\lib\features\search\domain\entities\filter_state.dart`, `H:\alnujom-project\lib\features\search\data\datasources\supabase_search_datasource.dart`, `H:\alnujom-project\lib\features\search\domain\entities\search_result_item.dart`, `H:\alnujom-project\lib\features\listing_form\domain\entities\listing.dart`, `H:\alnujom-project\lib\features\listing_form\domain\entities\listing_details.dart`, `H:\alnujom-project\lib\l10n\app_en.arb`, `H:\alnujom-project\lib\l10n\app_ar.arb`, `H:\alnujom-project\lib\core\localization\app_strings.dart`, `H:\alnujom-project\docs\brand\redesign-brief.md`.