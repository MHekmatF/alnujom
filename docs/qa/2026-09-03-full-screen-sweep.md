# Every screen, one at a time — 2026-09-03

The owner asked for the whole app walked "screen by screen, button by button".
This is that pass, on the **Infinix X692** (Android 10, 720×1640) over USB,
signed in as super-admin — so the admin and publisher surfaces are included, not
just the public ones.

It continues [`2026-09-03-signed-in-walk.md`](2026-09-03-signed-in-walk.md),
which covers the sign-in and sign-out fixes that came first.

## How it was driven, and one thing worth knowing

`adb shell uiautomator dump` reads a Flutter screen as **text**: Flutter does not
expose `text=`, but it does expose each semantics label as `content-desc`, and
uiautomator connecting as an accessibility client is enough to make Flutter build
the tree. That gives a labelled list with tap bounds — far cheaper than reading
screenshots, and it lets a control be tapped by *name* instead of by guessed
pixels. The driver is `walk.ps1` in the session scratchpad.

**Its limit, found the hard way:** the tree goes stale across a *pushed* route.
With the listing detail page plainly on screen, three consecutive dumps still
returned the search page. Screenshots stayed the source of truth for anything
reached with `context.push`. Worth re-checking with TalkBack — if a real screen
reader sees the same thing, pushed pages are a genuine accessibility problem
rather than a tooling quirk. **Not established either way here.**

---

## Five defects found, all fixed

### 1. The listing detail page slid under the status bar

Scroll past the gallery and the spec cards collided with the clock and the
signal icons. The `SliverAppBar` is `pinned: true` — correct — but it was also
`backgroundColor: Colors.transparent`, and a pinned bar with no fill does not
hide what scrolls beneath it. `FlexibleSpaceBar` fades the photo out as it
collapses, so past that point the bar was a window onto the moving body.

Fixed by giving the bar an opaque `card` floor, which only shows once the photo
has faded — expanded, the gallery still paints over it, so nothing changes there.
The back arrow moved into the same white disc the favourite heart already uses
(extracted as `OnPhotoChip`), because one fixed foreground colour cannot be
readable both on an arbitrary photograph and on an opaque bar in two themes.

### 2. An exchange rate that read backwards

The currencies screen showed **`SYP = 0.00006 USD 1`**. The template is
`1 {base} = {amount}`; left to the ambient RTL, the leading `1` is reordered to
the far end. An exchange rate that reads backwards is one an admin can act on
wrongly, so this is not only cosmetic. Fixed with `textDirection:
TextDirection.ltr` — the idiom `price_tag`, `ds_listing_card`, `favorite_card`
and the audit-log viewer already use for LTR expressions. Applied to both call
sites.

### 3. Loaded photographs announced themselves as missing

Six call sites passed `semanticLabel: l10n.image_unavailable` to
`AppNetworkImage`, which wraps **the whole result** in `Semantics` — so a
photograph that loaded perfectly announced "الصورة غير متاحة" to a screen
reader. The decision now lives in the widget: the caller's label describes what
the image *shows*, and "unavailable" is supplied automatically when there is no
url. The six callers dropped the argument — the cards already announce their own
title and price, so the image needs no second label.

### 4. Three unnamed buttons in the home app bar

`uiautomator` returned 21 labelled nodes for the home screen and **not one of
them was the menu, the messages icon or the bell**. They are bare glyphs on a
coloured bar. `_CrownAction` now takes a required `label` and wraps itself in
`Semantics(button: true)` — required, so a fourth action cannot be added without
one.

### 5. An English date in an Arabic screen

Covered in the companion file: `DateFormat.yMMMd()` with no locale on the
account-approval card. Fixed and confirmed on the device as `٥ يونيو ٢٠٢٦`.

---

## What was walked, and what it did

**Public / shared**

| Screen | Result |
|---|---|
| Home | Header, location picker, search field, three purpose tabs, eight category tiles, ad slot, publish FAB, five nav tabs — all present and labelled |
| Search — list | 16 results, correct count, cards with photo, price, title, location, age, publisher |
| Search — filters | Every field: purpose, 8 property types, advertiser, verified-only, deed type, finish level, location, currency, price range, bedrooms, bathrooms, area. Reset + Apply |
| Search — map | OSM tiles in Arabic, clusters of 4 and 10 plus 2 single pins = the 16 in the list. "View full map", list/map toggle |
| Listing detail | Gallery, purpose chip, title, verified agency, price, 4-spec row, field-verified badge, deed + finish cards, **finance calculator**, location + map link, **nearby amenities with distances**, safety warning, contact block, 4.7★ with distribution and three review cards, sticky call / message / WhatsApp bar |
| Favourites | Saved listing with photo, sort sheet |
| Messages | Conversation list with thumbnail and timestamp; thread opens with empty state and composer |
| Notifications | Real notification, correct relative age |
| Assistant | Greeting, three suggestion chips, "instant — no AI subscription" note, composer |
| Settings | Theme (auto/dark/light), language, currency SYP/USD, data saver, notification toggles |
| About + support | All three support channels, and the **privacy-policy link** now that it is published. Terms row correctly hidden while unset |

**Publisher**

| Screen | Result |
|---|---|
| Add listing | Three modes (quick / detailed / stepped), media block, submit. Exit guard released an untouched form |
| My listings | Status tabs, cards with status chips, prices in both currencies |
| CRM leads | Six stage tabs, empty state that explains itself, add-lead FAB |
| Inquiries inbox | Proper empty state |
| Viewings | Request card with date, status chip, contact and cancel actions |
| Agency | Create-agency form (no agency exists yet) |
| My reports | Loads |

**Admin / super-admin**

| Screen | Result |
|---|---|
| Admin home | Counters match the database exactly (0 listings pending, 1 account pending); all sections present |
| Account approvals | Queue loads, badge correct, approve/reject present |
| Listing review · agencies · reports · inquiries | Correct empty states, not errors |
| Currencies | SYP and USD with rates and add FAB |
| Locations | 14 governorates with city counts |
| Ads | Three active ads with preview and delete |
| Audit log | Real entries — including this session's own `app_settings` changes, correctly timestamped in Arabic |
| Analytics | KPI cards, a line chart with Arabic month labels, listings-by-governorate |
| Super-admin roles | Seven roles with permission and user counts |
| App settings editor | Shows `default_language = العربية` and the rest of the live values |

---

## Deliberately not done

Each of these writes something real, and none of them is reversible by pressing
back:

- **Sending a chat message** — that is a message from the owner to a real person.
- **Creating a listing end to end** — real rows in a production database whose
  demo content is about to be deleted (plan item A11).
- **Approving or rejecting the pending account** — a decision about a real person.
- **Deleting an ad, a currency or a location** — destructive, and nothing needed
  deleting.

## Two things that look wrong and are not

- **The viewing card shows a grey building glyph, not the listing photo.** By
  design — `viewings_list_page.dart` says so in as many words. Not the
  storage-path bug that hit the agency profile.
- **The admin analytics tile looked unreachable.** It is not; it sits below the
  audit-log section at the very bottom of the admin home, permission-gated. My
  first scroll simply stopped short.

## Small things, not worth their own change

- The add-listing mode switch truncates Arabic labels: `عرض تف…`, `خطوات …`.
- The selected bottom-nav label truncates: `ملفي الشخص…`.
- "My listings" shows bare `2026-06-15` dates rather than locale-formatted ones —
  already recorded in the spec's deferred list.
- The avatar is set by pasting a URL. A normal user has no URL to paste; picking
  an image is the expected affordance. Product call, not a defect.
- Month names come out as `يونيو`/`سبتمبر` (standard `ar` locale) rather than the
  Levantine `حزيران`/`أيلول`. A custom pattern would change it everywhere.
