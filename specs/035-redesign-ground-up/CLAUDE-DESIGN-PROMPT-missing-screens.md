# Prompt for Claude Design — the missing AlNujom screens

Paste this into a **new claude.ai chat** (English instructions produce better
results; the UI it generates is still Arabic). It reuses the exact tokens +
components from your approved `AlNujom.dc.html` so the new screens match it
pixel-for-pixel. Ask for a design artifact.

---

Continue the design of "AlNujom" (النجوم), a Syrian real-estate marketplace mobile
app — Arabic-first, full RTL, Material 3 Android. I already have Home, Search results,
and Listing Detail designed. Now design the REMAINING screens in the SAME visual
language so they drop into the same app. It must look like a real shipped app
(Bayut / dubizzle / OpenSooq), never an AI mockup.

REUSE THESE EXACT TOKENS (light / dark):
- bg #EAEDF2 / #0C0C10 · surface(cards) #FFFFFF / #131318 · surface2 #F2F4F9 / #1C1D25
- primary #1F4FE6 / #AEC2FF · brand header #1A3FC4 / #12235E (white text) · header search field #FFFFFF / #20232C
- tonal button #E2E9FF / #26356E (text #123287 / #DCE4FF) · secondary(selected/pill) #DAE1F6 / #2A3352 (text #182C58 / #DEE4FA)
- text #1A1C22 / #E7E8ED · secondary text #5B6070 / #A7ABB8 · chip/button border #C6CAD6 / #3B3D48 · card border/divider #E7EAF1 / #26272F
- verified green #0E7A3C on #E4F3E9 (dark #74D99A on #12331F) · WhatsApp #1FA855 · gold(featured) #8A6912 on #FBEDC7 · red(badges) #D93B3B · heart #FF5B6E

REUSE THESE COMPONENTS exactly as in the existing screens: the deep-blue crown
header with white search field; the white content sheet with 20px rounded top
corners overlapping the crown; tonal icon squares (54px, r15); pill segmented
control with a check on the selected segment; filter chips (removable with ×,
toggle with check); the bottom navigation with a pill indicator behind the
selected icon (الرئيسية، البحث، المحفوظة، الرسائل، حسابي); tonal buttons (r100);
Material Symbols Outlined icons; Noto Sans Arabic for text + Roboto for digits;
WESTERN digits everywhere; Android status bar tinted the brand blue with the
clock on the LEFT.

DESIGN THESE SCREENS:

1. المحفوظة (Saved) — bottom-nav tab. Two segments at top: "العقارات" (saved listings,
   reusing the same listing cards) and "عمليات البحث" (saved searches as rows: query +
   filters summary + result count + a bell toggle for alerts). Empty state that teaches.

2. الرسائل + المحادثة (Messages + Chat thread) — conversation list (avatar, name with
   verified tick, last message, time, unread count badge) and the chat thread itself
   (WhatsApp-like bubbles, but in-app; a listing preview card pinned at top; input bar).

3. حسابي (Account) — profile header (avatar, name, phone, "موثّق" state), then grouped
   list rows: إعلاناتي، المفضلة، عمليات البحث المحفوظة، لوحة الناشر، الإعدادات، اللغة،
   المظهر (light/dark), المساعدة، تسجيل الخروج. Rows with leading icon + label + chevron.

4. أضف إعلانك (Add listing) — a multi-step publish flow: (a) نوع العقار + الغرض
   (sale/rent) chips, (b) الموقع (governorate/city/area pickers + map pin), (c) التفاصيل
   (rooms, baths, area, floor, deed type طابو, finish الكسوة), (d) الصور (photo upload
   grid), (e) السعر + الوصف, (f) مراجعة ونشر. Stepper header, primary "التالي"/"نشر" button.

5. الفلاتر (Filters bottom sheet) — opened from the "الفلاتر" chip on Search. Full sheet:
   الغرض (sale/rent segmented), نوع العقار (chips), المدينة/المنطقة, نطاق السعر (range
   slider), الغرف/الحمامات (stepper chips 1/2/3/4+), المساحة, نوع الطابو, الكسوة, and a
   "الموثّقة فقط" switch. Sticky footer: "مسح الكل" + "عرض (24) نتيجة".

6. الدخول / التسجيل (Auth) — a login screen (phone/email + password), a register screen,
   and an OTP verification screen. Brand crown at top with the star logo; a "متابعة كزائر"
   (continue as guest) option.

7. الإشعارات (Notifications center) — opened from the bell. List of notification rows
   (icon, title, body, time; unread has a subtle tint + dot). Section headers by date.

8. الخريطة (Map results) — full-screen map with price pins; a bottom peeking card
   carousel of the listings in view; a "القائمة" toggle back to the list; the same
   filter chips row at top.

CONTENT REALISM: real Damascus/Aleppo/rural areas (أبو رمانة، المزة، كفر سوسة،
الحمدانية، دمشق القديمة، صحنايا)، USD prices $52,000–$310,000 with "≈ … مليار/مليون
ل.س" secondary lines, relative times (منذ يوم، منذ 3 أيام), Syrian features: field
verification (موثّق ميدانياً)، طابو أخضر، الكسوة سوبر ديلوكس، WhatsApp-first contact.
Include light AND dark for each screen where it matters.
