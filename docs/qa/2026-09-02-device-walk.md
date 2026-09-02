# Device walk — 2026-09-02

**Infinix Note 8 (X692, Android 11, arm64), real hardware, release APK signed
with the release keystore, run against the live Supabase backend.**

The point of this walk was to check the fixes from the previous session on a
real phone rather than an emulator, because one of them — the blank
password-reset screen — had been fixed but never actually run on a device. It
found two more defects of the same kind.

## The fix that had never been checked

The password-reset screen was blank in the build the founder tested. The cause
was a missing `@injectable` on `RequestPasswordReset`, so `get_it` threw while
the screen was building; in release that renders as a bare grey rectangle, and
with no crash-reporter DSN the exception reached neither the screen nor the log.

| # | Check | Result |
|---|---|---|
| 1 | Cold start from a fresh install | PASS — 3.79 s to first frame (`am start -W`) |
| 2 | Onboarding → register → login | PASS — Arabic RTL throughout |
| 3 | **Login → "نسيت كلمة المرور؟"** | **PASS — the screen renders.** This is the one that was blank |
| 4 | **Submit an unregistered number** | **PASS** — "لا يوجد حساب مسجّل بهذا الرقم" with a "جرّب رقماً آخر" button, instead of the old "if you have an account you will get an email" |
| 5 | Guest home feed | PASS — categories, ad banner, listings with images, prices, WhatsApp/call |
| 6 | Guest search | PASS — 16 results |
| 7 | Guest listing details | PASS — facts grid, field-verified badge, deed/finish, finance calculator, nearby places, similar listings, share/report |
| 8 | Notification channel | PASS — `alnujom_notifications_v2`, `mImportance=4`, not deleted. Heads-up banners are real |

No account was available to test sign-in, sign-out or a real reset mail; those
are noted as unverified below rather than assumed.

## What this walk found

### 1. A guest tapping an agency name was thrown to the login screen

`/agency/:id` is the public agency profile. Its route in `app_router.dart` even
says *"no auth redirect"* — but that only means the route adds none. The global
`authRedirect` runs on every navigation and did not recognise the path, so it
sent guests to `/login`.

This is the screen the `v_agencies` grant fix (migration `20260902120001`) was
meant to repair. The database was fixed; the guest still could not reach it.

### 2. The same for `/settings`, `/assistant` and `/reels`

`/settings` is the one that mattered. A signed-out visitor's drawer offers
exactly two destinations — About and Settings — and tapping Settings threw them
out of the app's own navigation into a login screen.

This also explains a "blank settings screen" seen on the emulator in the
previous session and written off as a mis-tap. It was not a mis-tap.

**Both fixed**, and `tool/lint_public_routes.dart` now cross-checks every route
that declares itself anonymous-accessible against what the redirect actually
allows. It was proven by removing `/settings` from the allow-list: the linter
fails by name. Three separate batches of screens have now shipped with this
defect (`/search` + `/map`, then `/agency/:id`, then these three), and nothing
in the build ever noticed.

### 3. The Settings screen crashed for everyone

Fixing #2 made `/settings` reachable — and it immediately failed to build. The
release error view came up ("تعذّر عرض هذه الشاشة"), which is the first time that
view has earned its keep: before it existed this would have been a grey
rectangle with nothing in the log.

A debug build gave the actual cause:

```
The following _TypeError was thrown building SettingsPage:
Null check operator used on a null value
#0  NotificationPrefs.notifier (core/settings/notification_prefs.dart:48:32)
#1  _SettingsPageState._notificationsGroup (settings_page.dart:203:41)
```

`NotificationPrefs.notifier` populated **every** category's notifier, but only
when the map was completely empty, then returned `_notifiers[category]!`. And
`load()` awaits secure storage *inside* its loop — so the instant it reads the
first category it yields, leaving the map non-empty and missing the rest. A
build in that window skipped the population branch and the `!` threw.

That window is not rare. It is exactly what happens every time Settings opens,
because the page calls `load()` in `initState` and reads the notifiers in the
very next build. **Settings was broken for signed-in users too** — this had
nothing to do with being a guest. It also explains the "blank settings screen"
seen on the emulator the day before and written off as a mis-tap.

`notifier()` now creates the one notifier it was asked for, the same idiom
`LiteMode.notifier` already used.

### 4. Guests were offered "delete my account"

With Settings reachable, a signed-out visitor saw a delete-my-account row that
had no account to delete and bounced them to login. Now shown only when signed
in.

### 5. The currency picker showed a red error to guests

With Settings finally rendering, the currency control under "العملة المفضلة"
carried a red *"تعذّر إكمال العملية. حاول مجدداً."*

The control seeds a value on first open — and the seed is a WRITE.
`readUserDisplayCurrency` returns null for a signed-out visitor, but
`writeUserDisplayCurrency` read `currentUser!.id`, so the write threw and the
control fell into its error state. Simply opening Settings as a guest was enough.
The write now returns early when there is no session, matching the read. A sweep
found no other `currentUser!` in the codebase.

### 6. The error screen itself rendered badly

`AppErrorView` can be substituted anywhere a widget throws — including above the
`MaterialApp`, where there is no `Directionality` and no `DefaultTextStyle`. Its
text fell back to Flutter's yellow-on-double-underline debug style, so the
screen meant to say "something went wrong, calmly" looked like a second failure.
It now carries its own `Directionality` and `DefaultTextStyle`, with
`inherit: false` on every style.

### 7. Listing thumbnails were broken on two screens

With the agency profile finally reachable, it showed a broken-image placeholder
on every listing it owns — titles and prices loaded, pictures did not.

`v_listings_public` returns a raw storage path. Every other listing surface
rewrites it to a public URL before the UI sees it — home, search, map,
favorites, similar listings, chat. The agency profile (and the agency's own
listings page, which shares its bloc) never did, so `CachedNetworkImage` was
handed `<uuid>/living-luxury-1.jpg` and failed.

A sweep for the same shape found one more: **My reports** reads
`v_reports.main_image_path` and hands it straight to the image widget. Both
fixed at the datasource, the same idiom the other surfaces use. Every remaining
`imageUrl:` fed from a `*Path` field was checked and already resolves correctly.

### 8. Ad creatives were cropped to unreadability

Every ad banner is 1200×375 (16:5). `AdBannerCard` drew them in a 16:7 box with
`BoxFit.cover`, which scales to fill the height and crops **~20% off each side**.
On an Arabic banner that removed the start of the headline and most of the
call-to-action. The ad rendered, and could not be read.

`AdCarousel` already used 16:5 — with a comment saying it matched the card it
did not match. Fixed to 16:5; all three now agree.

## Re-checked on the device after the fixes

Same phone, release build, live backend.

| Check | Result |
|---|---|
| Guest → drawer → Settings | Renders: theme picker, language, currency, data saver, notification toggles, About, version footer |
| Currency control as a guest | Shows "ليرة سورية (ل.س)" selected and "دولار أمريكي ($)" — no error |
| "Delete my account" as a guest | Correctly absent |
| Guest → listing → agency chip | Opens the agency profile: name, verified badge, phone, WhatsApp, and its listings |
| Agency listing thumbnails | Load — no broken-image placeholders |
| Ad banner on the home feed | Full artwork: the "وكالات موثّقة" headline and the "استكشف الوكالات" button are both intact |
| Reset screen, unknown number | "لا يوجد حساب مسجّل بهذا الرقم" with a "جرّب رقماً آخر" button |

## Not verified

- **Sign-in, sign-out and the sign-out freeze fix.** No test account exists on
  this device and creating one is the owner's call. The freeze fix and the
  non-blocking session wiring are code-reviewed and analyzer-clean, but neither
  has been exercised on hardware.
- **A real reset email.** Sending one means mailing a real person. Separately,
  Supabase's built-in SMTP is development-only, so this cannot be honestly
  tested until custom SMTP is configured — see `docs/ops/HANDOVER.md` section 2.
