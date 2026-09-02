# Signed-in device walk — 2026-09-03

**Device:** Infinix X692 (Android 10, 720×1640), driven over USB with
`F:\mm\sdk\platform-tools\adb.exe`.
**Build:** the release `1.1.0+2` that was on the phone, then a rebuild carrying
the two fixes below.
**Account:** the owner's own super-admin account. He typed the password himself —
Claude may not, which is why every previous walk stopped at the guest boundary.

This is the first time anything behind the sign-in wall has been exercised on
hardware since the July pass. Two of the "NOT VERIFIED" rows in
`docs/release/v1.0.0.md` close here; the rest are listed at the bottom.

---

## 1. Sign-in appeared to fail, and had not — FIXED

The owner's words: *"the first time I pressed Login it stayed on the same
screen, so I pressed the back arrow to open the app."*

The sign-in had worked. What he was looking at was a login page with nothing
left to do that would not leave.

**Cause — two correct things interacting.** `authRedirect` sends an
authenticated caller away from `/login`, and it does that by *location*. Since
PR #107 the guest sheet, the drawer, the favourite heart and the listing contact
block all reach the login screen with `context.push`, and a pushed route is an
imperative entry stacked on top of the match list. Moving the location
underneath it does not remove it. So the stack below was already correct — that
is exactly why Back revealed a signed-in app — while the form sat on top of it
looking like a failure.

Neither half was wrong on its own. `push` is what stopped Back from quitting the
app when a guest tapped one of the account tabs, which was the #107 fix and must
stay. The login page simply never had a reason to dismiss itself before, because
until #107 it was always the stack root.

**Fix:** `lib/features/auth/presentation/widgets/dismiss_when_signed_in.dart`.
Once a session exists, an auth page that *can* pop, pops. `context.canPop()` is
the whole guard: where `/login` still is the stack root — splash, the
maintenance screen, register → login — nothing pops and the global redirect
behaves exactly as before. The pop is deferred to the end of the frame because
the same `AuthState` emission also drives `GoRouter.refreshListenable`.

Applied to the login page and the register page — the guest sheet pushes both,
and a new account lands in `PendingApproval`, which is still a session.

**Severity.** This was on the first screen of the app for every returning user
who arrived through the sheet, the drawer, a favourite or a contact button. It
reads as "my password is wrong". Nobody who hit it would report a navigation
bug; they would just try again, or leave.

## 2. One card printed its date in English — FIXED

The account-approval queue showed `Jun 5, 2026 02:03` in the middle of an
otherwise fully Arabic screen.

`account_approvals_page.dart` called `DateFormat.yMMMd()` with **no locale**, so
`intl` fell back to `en_US`. A sweep of all 16 `DateFormat` call sites in `lib/`
found this was the only one missing it; every other one already passes
`Localizations.localeOf(context)`. Fixed the same way.

---

## Walked and correct

| Screen | Result |
|---|---|
| Cold start, signed in | Session survives a force-stop and relaunch — straight to Home, no re-auth |
| Home | Publish FAB appears for an approved publisher (it is hidden for guests) |
| المفضلة | Saved listing renders with its photo, price, specs and location |
| الرسائل | Conversation list loads with thumbnail and timestamp |
| ملفي الشخصي | Name, مقبول badge, phone, email, both role chips, edit button |
| الإشعارات | Real notification, correct relative age ("منذ ٩١ يوم") |
| إضافة عقار | Opens on the سريع mode; three-mode switch, media block, submit button present. Exit guard let an untouched form close cleanly |
| الإدارة | Counters are real and match the database (0 listings pending, 1 account pending) |
| موافقات الحسابات | Queue loads, badge count correct |
| الوكالات · البلاغات | Proper empty states, not errors |

## Two things that look like defects and are not

- **The approval card showing a raw user id.** The code falls back to the id
  only when name, phone *and* email are all null, and it says so in a comment.
  Checked the row: that profile genuinely has all three null in the database. It
  is a June test row, not a code path — `pre_launch_data_cleanup.sql` will take
  it. Registration always writes a phone, so a real registrant cannot produce
  this card.
- **`يونيو` rather than `حزيران`.** That is what the standard `ar` locale in
  `intl` gives. Levantine month names would need a custom pattern. Cosmetic, and
  a product call rather than a bug — noted, not changed.

## Small things seen, not worth their own PR

- The add-listing mode switch truncates its Arabic labels: `عرض تف…`,
  `خطوات …`. Three segments do not fit at 720 px.
- The selected bottom-nav label truncates to `ملفي الشخص…`.
- The reports queue's two filter dropdowns show `—`, matching the known
  single-item-stub note in `specs/018`'s deferred list.

## Still not verified

- **Sign-out.** Deliberately left until last: it costs the owner another
  password entry, so it is batched with the check that fix 1 above actually
  works on the device.
- **Two-account flows** — chat both directions with realtime inbound, a viewing
  request and its confirmation, a push notification arriving on a second phone.
  Needs the `Pixel_8_Pro` AVD signed in as a second account.
- **Creating a real listing end to end**, including photo upload and the
  approve → stay-live-edit → revision path. Not done, because it writes real
  rows into a production database that is about to have its demo content
  deleted.
