# AlNujom "Blue Crown" — Features Tier — DESIGN SPEC

> Digest of `AlNujom - Features.dc.html` (ground truth for exact values). 8 screens + write-review sheet + shared non-OK states. RTL. Arabic=Noto Sans Arabic; prices/numerals/phones/counts=Roboto WESTERN digits. Icons=Material Symbols Outlined (FILL 1 where noted).

Token map = project DC contract. Crown header padding standard = `34px 8px 14px`; sticky variants use `34px 8px 16px`. heart `#FF5B6E` (fixed both themes). Demo top nav/theme toggle/phone-frame = prototype scaffolding, DO NOT implement.

---

## Screen 1 — Compare · `المقارنة`
**Shell:** `DcCrownScaffold(title:'المقارنة', dense:true, leading:back, actions:[count pill])`. Root bg `--surface`.
Crown: bg `--header` pad `34px 8px 14px`; back `arrow_forward` 24px white; title 18/700 white; count pill trailing (margin-inline-start:auto) `{{count}} عقارات` bg `rgba(255,255,255,.16)` white pad `3 10` radius 100 12/700.
**Body — sticky-first-column matrix** (`overflow:auto` both axes, bg surface, min-width max-content):
- Header image row (border-bottom 1px divider): sticky label spacer (right, sticky right:0 z:3) w **96** bg surface; per col (`compareCols` 2–3) w **150** pad 10 border-inline-start 1px divider → image placeholder 100%×**84** radius 10 bg surface2 icon `apartment` 30px `--outline`; remove btn overlay top:5 left:5 24×24 circle bg scrim icon `close` 16 white (disabled when cols ≤ 2).
- Data rows (7, border-bottom 1px divider, press bg surface2): sticky label cell (right sticky z:2) w96 bg surface2 pad `0 11` **12/700** `--onVar`; value cells w150 pad `12 11` **13/600** `--on`.
- Rows: السعر (`$210,000` Roboto) · غرف النوم · الحمامات · المساحة (`220 م²`) · الطابو (طابو أخضر / حكم محكمة) · الكسوة (سوبر ديلوكس / ديلوكس) · الموقع.
**NEW:** `DcCompareTable({columns,rows})` (min 2 cols). Empty: icon `compare_arrows`, title لا عقارات للمقارنة, body أضف عقارات من نتائج البحث لمقارنتها جنباً إلى جنب.

---

## Screen 2 — Reels · `ريلز العقارات`
Full-bleed `Stack`, bg = per-item tint. Tap anywhere = next (wraps). Content colors fixed white/black except WhatsApp = `--wa`.
1. Scrim `linear-gradient(180deg, rgba(0,0,0,.42) 0%, transparent 26%, transparent 52%, rgba(0,0,0,.82) 100%)`.
2. Ghost `play_circle` **120px** white opacity .16 center.
3. Top bar (top36 l14 r14 z5 space-between): back 40×40 circle bg `rgba(0,0,0,.3)` `arrow_forward` 23 white; title ريلز العقارات 16/700 white; search 40×40 circle `search` 22.
4. Progress dots (vertical left edge, top50% start:8): w4 radius3 white, active h**22** opacity1, inactive h8 opacity .4.
5. **Right rail** (bottom150 start:12 gap 20): Like `favorite` **32px** (saved `#FF5B6E` FILL 1 / else white outline) + likes 11/700 white Roboto; Comment `chat_bubble` 31 + count; Share `share` 30 + مشاركة 11/700; Mute 38×38 circle bg `rgba(0,0,0,.3)` `volume_off` 20.
6. **Content block** (bottom0, pad `16px 16px 24px 66px` z4): agency row (avatar 36×36 circle `storefront` 20 `#111`; name 14/700 white; متابعة border 1px `rgba(255,255,255,.7)` transparent white pad `4 13` radius 100 12/700); price **23/700 white Roboto**; title mt5 14 white; meta row mt5 gap12 `rgba(255,255,255,.9)` 12 Roboto — `king_bed`/`bathtub`/`square_foot`/`location_on` 15px each; action row mt13 gap8 → primary flex:1 h**44** radius100 bg white `#111` 14/700 icon `visibility` 19 label عرض الإعلان; WhatsApp **52×44** radius100 bg `--wa` `chat` 21 white.
**NEW:** `DcReelOverlay`, `DcReelActionRail`. Rail buttons must stopPropagation.

---

## Screen 3 — Panorama 360 · `جولة 360`
Full-bleed `Stack`, bg `#0b0d12` (fixed, dark chrome only).
1. Panning tint `linear-gradient(90deg, {tint}, #0b0d12 40%, {tint} 70%, #0b0d12)` size `220% 100%` `pan 22s`.
2. Grid overlay 2× 1px line gradients `rgba(255,255,255,.05)` size `38px 38px`.
3. Center hint: `360` glyph **52px** `rgba(255,255,255,.85)` FILL 1 + caption اسحب للتدوير والاستكشاف 13 `rgba(255,255,255,.8)`.
4. Top bar (top36): close 40×40 circle bg `rgba(0,0,0,.4)` `close` 23; center chip `جولة افتراضية · {label}` bg `rgba(0,0,0,.4)` white pad `6 12` radius100 12/700; share 40×40 `share` 22.
5. **Scene strip** (bottom22, pad `0 14`): h-scroll gap9; each scene w**82** → thumb **82×58** radius10 bg tint icon `panorama_photosphere` 20 `rgba(255,255,255,.7)`, selected `outline:2px solid #fff outline-offset:-2px`; label mt5 11/600 white.
Scenes: الصالون `#20304f` · المطبخ `#264a3a` · غرفة النوم `#3a2a4a` · التراس `#4a3a24`.
**NEW:** `DcPanoViewer`, `DcSceneStrip({scenes,selectedIndex,onSelect})`.

---

## Screen 4 — AI Assistant · `المساعد الذكي`
**Shell:** `DcCrownScaffold(title custom, body scroll, bottomNavigationBar: composer)`. Root bg `--bg`.
Crown (custom, pad `34px 8px 14px` gap8): back `arrow_forward` 24 white; logo tile 34×34 radius10 bg `rgba(255,255,255,.16)` `auto_awesome` 20 white FILL1; title stack line1 المساعد الذكي 16/700 white, line2 مدعوم بالذكاء الاصطناعي 11 `rgba(255,255,255,.7)`.
Body (bg `--bg`, pad `16px 14px`, gap 12):
- **Empty state:** hero tile **70×70** radius20 bg `--tonal` `auto_awesome` 36 `--onTonal` FILL1 mb14; title اسأل عمّا تبحث عنه 17/700; body اكتب طلبك بلغتك الطبيعية… 13 `--onVar` lh1.7. Suggestion chips (gap9), each bg surface 1px divider radius **14** pad `13 14` text-align right: leading `search` 20 `--primary`, label flex:1 14/600, trailing `north_west` 18 `--onVar`. Suggestions: شقة بدمشق تحت 100 ألف دولار · فلل مع حديقة في حلب · أراضٍ طابو أخضر في ريف دمشق.
- **Conversation:** user bubble align-end max-w82% bg `--primary` radius `16 4 16 16` pad `10 14` 14 `--onPrimary`; bot bubble align-start (avatar 28×28 radius9 bg tonal `auto_awesome` 16 onTonal FILL1 + bubble bg surface 1px divider radius `4 16 16 16` pad `10 13` 14 text) reply وجدت لك عدة عقارات مطابقة لطلبك:; inline result cards (pad-inline-start 36) bg surface 1px divider radius **12** pad9 row gap10 → thumb 66×56 radius9 surface2 `apartment` 24 outline; price 15/700 Roboto, title mt3 12 ellipsis, loc·area mt3 11 `--onVar`.
- **Composer** (bottomNav): bg surface border-top 1px divider pad `10px 12px 18px` gap8 → input flex:1 h**46** border 1px outline radius100 bg surface2 pad `0 16` 14 placeholder مثال: شقة بدمشق تحت 100 ألف…; send **46×46** circle bg primary `auto_awesome` 22 onPrimary FILL1 press scale .94.
**NEW:** `DcAiChatBubble({text,isMine})`, `DcAiSuggestionChip`, `DcAiResultCard`, `DcAiComposer`.

---

## Screen 5 — Reviews · `التقييمات` (+ Write-Review sheet)
**Shell:** `DcCrownScaffold(title:'التقييمات', leading:back)`. Root bg `--surface`.
Body (pad `16px 14px 24px`):
1. **Summary card** row gap16 bg surface2 radius14 pad14: left avg `{avg}` (1 decimal Roboto) **38/700**; star row mt5 gap2 5× `star` **15px** filled=gold FILL1/empty=outline; count mt4 `{n} تقييم` 11 `--onVar`. Right (flex:1) office مكتب الشام العقاري 14/700 + subtitle شارك تجربتك… 12 `--onVar`.
2. **Write button** mt12 full-width h**46** radius100 bg primary onPrimary 14/700 icon `rate_review` 19 label اكتب تقييماً → `AppButton(filled,expanded)`.
3. **Review list** mt16 gap12, per card bg surface 1px divider radius14 pad13: header gap10 avatar 38×38 circle bg tonal initial 15/700 onTonal; name 13/700 + stars mt2 13px gold; time 11 `--onVar`; body mt9 13 lh **1.75**.
Empty: icon `star`, title لا تقييمات بعد, body كن أول من يشارك تجربته مع هذا المكتب.
**Write-Review sheet** (`sheetOpen` z60): scrim; sheet bg surface radius `24 24 0 0` pad `10px 18px 24px` `sheetUp .28s`: grab handle 36×4 radius3 outline; title قيّم مكتب الشام العقاري 17/700 center; star picker mt16 center gap8 5× tappable `star` **38px** gold FILL1/outline; rating label mt6 `{label}` 12 (اختر تقييمك/سيئ/مقبول/جيد/جيد جداً/ممتاز); textarea mt14 h**104** border 1px outline radius14 bg surface2 pad `12 14` 14 lh1.7 placeholder اكتب تجربتك مع هذا المكتب…; submit mt14 full-width h**48** radius100 bg primary onPrimary 14/700 label إرسال التقييم.
**NEW:** `DcRatingStars({value,size,interactive})`, `DcReviewCard`, `DcWriteReviewSheet`.

---

## Screen 6 — Saved Searches · `عمليات البحث المحفوظة`
**Shell:** `DcCrownScaffold` sticky-crown+rounded-sheet (crown bg header pad `34px 8px 16px`, back + title 18/700 white; sheet surface radius `20 20 0 0` mt -14 pad `16px 14px 24px` gap12). Root bg `--bg`.
**Saved-search card** bg surface 1px divider radius14 pad14:
- Top row gap11 align-start: icon tile 40×40 radius **11** bg tonal `saved_search` 22 onTonal; text col title 15/700 + summary mt4 12 `--onVar` lh1.6 (e.g. `المزة · للبيع · $50k–$150k · 3 غرف · موثّق`); delete 30×30 circle transparent `delete_outline` 20 `--onVar`.
- Divider 1px `margin:12px 0 11px`.
- Bottom row space-between: result count inline `home_work` 16 primary + `{count} · {ago}` 12/600 `--on`; **alert-bell toggle** pill pad `5 11` radius100 12/700 gap5 — ON bg greenC text onGreenC `notifications_active` 16 FILL1 label التنبيهات مفعّلة / OFF bg surface2 text `--onVar` `notifications_off` 16 label مغلقة.
Empty: icon `bookmark`, title لا عمليات بحث محفوظة, body احفظ بحثك من شاشة النتائج لتصلك تنبيهات بالعقارات الجديدة المطابقة.
**NEW:** `DcSavedSearchCard({title,summary,count,ago,alertOn,onToggle,onDelete})`.

---

## Screen 7 — Private Profile · `معلوماتي الخاصة`
**Shell:** `DcCrownScaffold(title, leading:back)`. Root bg `--surface`. Body pad `16px 14px 24px` gap16.
Grouped rows (per group): group label 12/700 `--onVar` ls .3 mb8; container bg surface 1px divider radius14 overflow hidden; row (non-first prefixed 1px divider) pad `13 14` gap10 → text col label 12 `--onVar` + value mt3 14/600 `--on`; trailing = verified badge (inline gap3 bg greenC text onGreenC pad `4 9` radius100 11/700 `verified` 14 FILL1 موثّق) OR unverified btn (h**32** pad `0 13` radius100 bg tonal text onTonal 12/700 توثيق) OR none.
Groups: **الهوية** → الاسم الكامل أحمد الخطيب (none) · رقم الهوية الوطنية `•••• 4821` (verified). **معلومات التواصل** → رقم الهاتف `+963 944 210 337` (verified, Roboto) · البريد الإلكتروني `ahmad@example.com` (unverified). **الحساب** → نوع الحساب فردي · تاريخ الانضمام مارس 2023.
Empty: icon `lock`, title لا معلومات, body أكمل بيانات ملفك الشخصي.
**NEW:** `DcInfoGroup({title,children})`, `DcVerificationRow({label,value,state})`.

---

## Screen 8 — My Reports · `بلاغاتي`
**Shell:** `DcCrownScaffold` sticky-crown+rounded-sheet (as Saved). Root bg `--bg`. Sheet pad `16px 14px 24px` gap11.
**Report card** bg surface 1px divider radius14 pad13:
- Top row gap10: icon tile 38×38 radius10 bg surface2 `{icon}` 20 `--onVar` (`apartment` listing / `person` user); text col subject 13/700 ellipsis + date mt3 11 `--onVar`; **status badge** pad `3 9` radius **7** 10/700 gap3 — resolved bg greenC text onGreenC `check_circle` 13 FILL1 تمّت المعالجة / rejected bg redC text onRedC `cancel` 13 مرفوض / review bg surface2 text `--onVar` `hourglass_top` 13 قيد المراجعة.
- Reason box mt10 bg surface2 radius10 pad `9 11` `السبب: {reason}` 12 lh1.6.
Empty: icon `flag`, title لا بلاغات, body عند الإبلاغ عن إعلان أو مستخدم مخالف ستظهر حالة بلاغك هنا.
**NEW:** `DcReportCard`, `DcStatusBadge({tone:green/red/neutral,label,icon})`.

---

## §9 — Shared non-OK states (compare/ai/reviews/saved/private/reports; NOT reels/pano)
Frame: outer scroll bg `--bg`; crown non-sticky bg header pad `34px 12px 16px` back + `{title}` 19/700 white; sheet surface radius `20 20 0 0` mt -14.
- **Loading:** pad14 gap12, 4 skeleton rows — 1px divider radius14 pad13 gap11: avatar 44×44 radius11 + 2 bars (50%×14, 80%×11 radius6); shimmer `linear-gradient(90deg, surface2 25%, divider 37%, surface2 63%)` size `400% 100%` `shim 1.4s`.
- **Empty:** pad `60px 32px` centered; icon circle **88×88** bg tonal `{icon}` **44px** onTonal mb20; title 18/700 `--on`; body mt8 14 `--onVar` lh1.7.
- **Error:** same; icon circle 88×88 bg redC `cloud_off` 44 onRedC; title تعذّر تحميل البيانات; body حدث خطأ في الاتصال بالخادم. تحقّق من الإنترنت وحاول مرة أخرى.; retry mt22 h**46** pad `0 24` radius100 bg primary onPrimary 14/700 `refresh` 20 إعادة المحاولة.
**NEW:** `DcSkeletonListRow`, `DcEmptyState({icon,title,body})`, `DcErrorState({onRetry})` — app-wide reuse.

---

## Shell mapping summary
| Screen | Shell | New components |
|---|---|---|
| Compare | DcCrownScaffold(dense), actions:count pill | DcCompareTable |
| Reels | full Stack | DcReelOverlay, DcReelActionRail |
| Pano 360 | full Stack | DcPanoViewer, DcSceneStrip |
| AI Assistant | DcCrownScaffold, bottomNav composer | DcAiChatBubble, DcAiSuggestionChip, DcAiResultCard, DcAiComposer |
| Reviews | DcCrownScaffold, sheet | DcRatingStars, DcReviewCard, DcWriteReviewSheet |
| Saved Searches | DcCrownScaffold sticky+sheet | DcSavedSearchCard |
| Private Profile | DcCrownScaffold | DcInfoGroup, DcVerificationRow |
| My Reports | DcCrownScaffold sticky+sheet | DcReportCard, DcStatusBadge |
| non-OK (6) | DcCrownScaffold sticky+sheet | DcSkeletonListRow, DcEmptyState, DcErrorState |

Hoist shared: `DcRatingStars`, `DcStatusBadge` (green/red/neutral — reused by reports + saved-alert pill + private verified badge), `DcEmptyState`/`DcErrorState`/`DcSkeletonListRow`. `AppButton(filled)` = all solid pill CTAs; `AppButton(whatsapp)` = Reels WA (52×44 icon-only).
