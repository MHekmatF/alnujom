# AlNujom — Operator Handover Playbook

A plain-language guide for the owner of AlNujom. It covers the one-time setup,
the routine jobs, and the emergencies — what to do when push stops working, when
Supabase pauses, when you need to take the app down, and when you want to ship a
new version.

You do **not** need to be a programmer to follow this. Where a step needs a
developer, it says so. Most of it happens in web dashboards.

> **The dashboards you will live in:**
> - **Supabase** — database, user accounts, login settings, file storage, server
>   functions. Project **AlNujom**, reference `hczsgceagommznjaohyk`.
>   <https://supabase.com/dashboard>
> - **GlitchTip** — the crash-report inbox (tells you when the app breaks for a user).
> - **Firebase Console** — push notifications (project `alnujom-real-estate-test`).
> - **GitHub** — the code, and the keep-alive robot that stops Supabase pausing.
>   Repository `MHekmatF/alnujom`.

---

## Start here

The database is **live** — an earlier scare during the 2026-09-01 session turned
out to be a DNS failure on the build machine, not a paused project. Read
[`PENDING_MIGRATIONS.md`](PENDING_MIGRATIONS.md) first: two migrations were
applied that day (one of them repaired a broken guest map), two are deliberately
held back, and one of those needs a decision from you.

## Contents

1. [Create the first super-admin](#1-create-the-first-super-admin)
2. [Supabase login settings (password reset)](#2-supabase-login-settings-password-reset)
3. [The secret files on the build machine](#3-the-secret-files-on-the-build-machine)
4. [Vault secrets — the ones that must never be lost](#4-vault-secrets--the-ones-that-must-never-be-lost)
5. [Server functions (Edge Functions)](#5-server-functions-edge-functions)
6. [Push notifications — how they work and how to fix them](#6-push-notifications--how-they-work-and-how-to-fix-them)
7. [Shipping a new version](#7-shipping-a-new-version)
7b. [Finishing an account deletion](#7b-finishing-an-account-deletion)
8. [Maintenance mode — taking the app down safely](#8-maintenance-mode--taking-the-app-down-safely)
9. [The project is paused — how to restore it](#9-the-project-is-paused--how-to-restore-it)
10. [The keep-alive robot](#10-the-keep-alive-robot)
11. [First-30-days checklist](#11-first-30-days-checklist)
12. [Known gaps and where the truth lives](#12-known-gaps-and-where-the-truth-lives)

---

## A quick mental model

- **Buyers and sellers** use the Android app. Sellers ("publishers") post
  listings; buyers browse, chat, and send inquiries.
- **Moderators and admins** approve new seller accounts, approve listings before
  they go public, and handle reports.
- **You (the super-admin)** sit at the top: you create the moderators and admins,
  and you hold the master keys.

Nothing happens automatically. A new seller's account must be approved by a
person before they can post, and each listing must be approved before the public
sees it. That is by design.

---

## 1. Create the first super-admin

When the app first goes live there are **no administrators** — every new sign-up
gets the plain "user" role, and a plain user cannot approve anyone. So the very
first admin has to be granted by hand, one time, directly in the database. After
that you create every other moderator/admin from inside the app.

1. **Install the app and register a normal account** with the phone number you
   want as the owner account. Choose a strong password. Finish the sign-up.

2. Supabase dashboard → project **AlNujom** → **SQL Editor**.

3. Find your account's internal ID (use your phone in full international form,
   e.g. `+9639XXXXXXXX`):

   ```sql
   select user_id, phone, full_name
   from public.profiles
   where phone = '+9639XXXXXXXX';
   ```

   Copy the `user_id`.

4. Grant super-admin:

   ```sql
   insert into public.user_roles (user_id, role_id)
   values (
     'PASTE-YOUR-USER-ID-HERE',
     (select id from public.roles where key = 'super_admin')
   )
   on conflict (user_id, role_id) do nothing;
   ```

5. If your account is still pending approval (a brand-new sign-up usually is),
   approve it:

   ```sql
   update public.profiles
   set account_status = 'approved'
   where user_id = 'PASTE-YOUR-USER-ID-HERE';
   ```

6. **Fully close and reopen the app, then log in again.** You should now see the
   admin section. From here on use the in-app **Roles** screen — you should never
   need step 4 again.

> **Do this only once.** Keep the list of super-admins tiny: you, plus one
> trusted backup so you are not locked out if you lose your phone.

---

## 2. Supabase login settings (password reset)

A user who forgets their password taps "forgot password" and enters their phone.
The app asks the server for a reset link. For that link to bring them back into
the app, Supabase has to know the app's address.

That address is a **deep link** — `alnujom://auth/reset-password`. It is not a
web page; tapping it opens the AlNujom app straight onto the "set a new password"
screen. The app registers this address with Android, so Android knows to hand it
over.

**Why the allow-list matters here:** the server function that sends the reset
(`request_password_reset`) now names the app's address explicitly. Supabase will
only honour an address that is on the **Redirect URLs** allow-list — anything
else is rejected and the user is stuck.

### Set it

Supabase dashboard → project **AlNujom** → **Authentication** → **URL
Configuration**.

| Field | Exact value to enter |
|---|---|
| **Redirect URLs** → *Add URL* | `alnujom://auth/reset-password` |

Click **Save**. **Site URL does not need changing** — the function supplies the
return address itself. (If the allow-list rejects the value, or the link still
fails, add `alnujom://auth/reset-password**` as a second entry.)

### The function itself is already live — do not redeploy blindly

Verified against production on 2026-09-02: the deployed `request_password_reset`
is the corrected one. Leave it alone unless you are deliberately shipping a
change.

**Why it was broken before:** the old version called `generateLink()`, which
*generates* a recovery link and hands it back to the caller. It never sends
anything. That is the whole reason no reset mail ever arrived. It now calls
GoTrue's `/auth/v1/recover`, which is the call that actually dispatches.

**One trap to know about:** the deployed function and the copy in the repo drifted
apart once — production was fixed and the repo was not, so a redeploy from the
repo would have silently restored the version that mails nothing. They are back
in sync now. If you ever change this function, deploy from the repo and commit in
the same breath.

### The reset mail still needs a real mail sender — THIS IS THE REMAINING BLOCKER

Supabase's built-in email service is a development convenience, not a mail
provider: it is heavily rate-limited (a couple of messages an hour) and Supabase
states plainly it is not for production use. On that service, most reset mails to
real users will simply never arrive, and nothing in the app or the logs will look
wrong — the function will honestly report `sent`, because Supabase accepted the
request.

`sent` means *Supabase accepted it*, not *it reached an inbox*.

**Fix before launch:** Supabase dashboard → **Authentication → Emails → SMTP
Settings** → enable custom SMTP. Any free tier will do (Resend, Brevo, and
SendGrid all have one). You enter the provider's host, port, username and
password there yourself — those are credentials, so keep them out of the repo and
out of any chat.

Until that is done, treat password reset as working only for you and anyone else
on the project team, and fall back to the manual reset below for real users.

### While you are on that screen, verify three more settings

- **Authentication → Settings → Password → Minimum length** = **8**
- **Authentication → Providers → Email → Confirm email** = **OFF / unchecked**
- **Authentication → Sign In / Providers → Email → Secure password change**
  = **ON** — stops a stolen old session from silently changing the password. A
  reset still works, because a recovery session is brand new.
  (**Not** "Prevent use of leaked passwords". That toggle is Pro-plan only and
  cannot be switched on here — see section 11. An earlier version of this list
  said to turn it on; it was wrong.)

Email confirmation must stay off. The app signs people up with a made-up email
built from their phone number (`+9639XXXXXXXX@alnujom.local`) — that mailbox does
not exist and can never receive a confirmation, so turning this on breaks every
sign-up.

### Test it, once

Register a throwaway account **with a real email address**, tap "forgot
password", and confirm the link opens the app on the "set a new password" screen
rather than a browser. If it opens a browser or an error page, the address is
missing from the Redirect URLs allow-list, or the function was not redeployed.

### If a user is genuinely locked out

Because most accounts use a made-up email, the reset email only reaches the few
accounts that have a **real** email on file. For everyone else:

1. Supabase → **Authentication → Users** → find them by phone.
2. Use the **Change password** field to set a temporary password.
   ("Send password recovery" does nothing useful for a made-up email.)
3. Tell them the temporary password and to change it in the app.

---

## 3. The secret files on the build machine

Three files live on the **build machine** (the computer that produces the app's
installable file) and are deliberately kept out of the code repository. All three
are "gitignored", meaning the repository is configured to refuse them. Keep it
that way.

| File | What it holds | Ships inside the app? |
|---|---|---|
| `.env.json` | Public-safe build settings: the Supabase web address, the public **anon** key, and the crash-report address (`SENTRY_DSN`) | **Yes** — safe to ship |
| `.env.admin.json` | The **master key** (`SUPABASE_SERVICE_ROLE_KEY`) used only by back-office tools | **Never** |
| `android/app/google-services.json` | The Firebase configuration that makes **push notifications** work | Yes (it is meant to) |
| `android/key.properties` + the keystore file | The **signing key** that proves an update really comes from you | The signature does |

### `.env.json`

```json
{
  "SUPABASE_URL": "https://hczsgceagommznjaohyk.supabase.co",
  "SUPABASE_ANON_KEY": "....(the public key)....",
  "SENTRY_DSN": "https://....(your GlitchTip DSN)....",
  "DESIGN_TOOLS": false
}
```

- Every `flutter run` and `flutter build` **must** include
  `--dart-define-from-file=.env.json`. Without it the app cannot reach Supabase
  and shows a red error screen on launch. This is the single most common build
  mistake.
- If `SENTRY_DSN` is left empty, crash reporting is simply off — the app works
  fine, it just does not report errors. That is safe.
- The app must be rebuilt for any change to this file to take effect.

### `.env.admin.json` — the one rule

This holds the **service-role key**: the master key to the entire database. It
bypasses every safety rule.

- It lives **only** on the build/admin machine.
- It is **never** put into `.env.json` and **never** shipped inside the app.
  (The app carries only the harmless public anon key — confirmed by scanning the
  built app; see `docs/release/v1.0.0.md`.)
- Never paste it into chat, email, screenshots, or the repository.
- If you suspect it leaked, rotate it immediately: Supabase → **Project Settings
  → API** → roll the key, then put the new value into `.env.admin.json`.

### `android/app/google-services.json`

The Firebase config for push notifications. **It is not in the repository** — the
build is written to work with or without it:

- **Present** → push notifications work.
- **Absent** → the app still builds and runs perfectly; users just get in-app
  notifications only, no phone-tray banners.

Download it from **Firebase Console → Project settings → Your apps → Android app
`com.alnujom.app` → `google-services.json`** and place it at
`android/app/google-services.json` on the build machine. Back it up alongside
your other build secrets — it is not secret in the dangerous sense, but losing it
means push silently stops working on the next build.

### The signing key

`android/key.properties` points at your keystore file:

```
storePassword=<password>
keyPassword=<password>
keyAlias=<alias>
storeFile=<absolute-path-to-keystore>
```

⚠️ **Back up the keystore file and its passwords in two separate places.** If you
lose them you can never ship an update to this app again — not on Telegram
(Android refuses an update signed by a different key) and not on Google Play.
There is no recovery. This is the single most irreplaceable thing you own.

A release build with no `key.properties` **fails on purpose** rather than
producing an unsigned or debug-signed file.

---

## 4. Vault secrets — the ones that must never be lost

Supabase **Vault** is an encrypted safe inside your database. Some of the app's
most important values live there. You can see them at **Supabase dashboard →
Project Settings → Vault** (or via SQL, below).

**Five secrets are managed by you.** Losing one is not always fatal, but each has
a real consequence:

| Secret name | What it is for | What breaks if it is lost or changed |
|---|---|---|
| `map_jitter_salt` | The secret ingredient that scrambles a property's map pin when the seller chose "approximate location" | **Silent damage.** The privacy feature keeps working, but *every* approximate listing's pin jumps to a new spot. Nothing errors; the map just quietly becomes wrong for everyone. If the secret is deleted outright, the map function raises an error and map markers stop loading. |
| `app-inquirer-phone-key` | The key that encrypts the phone number of someone who sends an inquiry through the contact form | Existing encrypted phone numbers become **permanently unreadable**. There is no recovery. |
| `fcm_service_account` | The Firebase credentials the server uses to send push notifications | Push stops. In-app notifications still work. |
| `push_dispatch_url` | The address of the server function that sends pushes | Push stops silently. |
| `push_dispatch_token` | The password the database uses to prove it is allowed to trigger a push | Push stops (the function answers "401 unauthorized"). |

> **Save the raw values in your password manager the day they are created.**
> Vault will show them back to you, but only while the project is alive and you
> have access. If the database is ever rebuilt from scratch, these are gone.

There is also a **large, automatic** set of Vault secrets you never touch: one
per user per sensitive field, named `pii.<user-id>.<field>`. These hold each
user's **legal name**, **national ID number**, and **private contact methods**
(WhatsApp / Telegram / Signal / private email / secondary phone), plus agency ID
and commercial-registration numbers. They are created and read automatically, and
only the user themselves or an admin can decrypt them. Never edit these by hand.

### Checking what is in the Vault

Supabase → **SQL Editor**:

```sql
-- List the operator-managed secrets (names + descriptions only, no values).
select name, description, created_at
from vault.secrets
where name not like 'pii.%'
order by name;
```

To confirm the map salt is the right shape without revealing it:

```sql
select length(decrypted_secret) as hex_length
from vault.decrypted_secrets
where name = 'map_jitter_salt';
-- Expected: 64
```

### Creating a missing secret

If `map_jitter_salt` is ever missing, generate a fresh 64-character value **out
of band** (PowerShell: `openssl rand -hex 32`, or ask your developer) and:

```sql
select vault.create_secret(
  '<the-64-character-value>',
  'map_jitter_salt',
  'Map jitter salt — changing it re-scrambles every approximate marker'
);
```

Full detail, including rotation: `supabase/docs/map_jitter_coordinates.md`.

---

## 5. Server functions (Edge Functions)

Seven small programs run on Supabase's servers rather than in the app. They exist
for jobs that must not be trusted to a phone. You can see them at **Supabase
dashboard → Edge Functions**.

| Function | What it does | Who may call it |
|---|---|---|
| `approve_listing` | Publishes a listing after a moderator approves it | Admin/moderator with the right permission, checked server-side |
| `reject_listing` | Rejects a listing with a reason | Same |
| `moderate_agency` | Approves or rejects an agency | Same |
| `resolve_report` | Closes a report from the reports queue | Same |
| `dispatch_push` | Sends the actual push notification through Firebase | Only the database, using the shared `push_dispatch_token` |
| `request_password_reset` | Starts a password reset from a phone number | Anyone. It now answers `sent` / `no_email` / `not_found` so the screen can tell the user what actually happened. That deliberately gives up the old "identical answer for every number" property — see section 2. |
| `lookup_email_by_phone` | Translates a phone number into the made-up login email at sign-in | Anyone (same enumeration-resistant design) |

**You will rarely touch these.** They are already deployed and running. A
developer redeploys one only after changing its code:

```bash
supabase functions deploy <function-name> --project-ref hczsgceagommznjaohyk
```

The source lives in `supabase/functions/<name>/index.ts`.

> One known piece of housekeeping: the live `dispatch_push` predates a small fix
> to the data it sends. Two redeploy attempts in June failed with a Supabase
> platform error. It should be redeployed from source when convenient — see
> `specs/022-notifications-realtime/DEFERRED.md`.

---

## 6. Push notifications — how they work and how to fix them

### The chain

Something happens in the database (a listing is approved, an inquiry arrives) →
the database writes a notification row → a trigger posts to the `dispatch_push`
function → that function reads the Firebase credentials from the Vault → Firebase
delivers the banner to the phone → tapping it opens the right screen in the app.

**Every link can fail silently by design.** If any piece is missing, push simply
does not happen and the app keeps working with **in-app** notifications (the bell
icon and the notification centre) intact. Nothing crashes. That is deliberate —
Firebase may be unreachable from the region, and the app must survive that.

### What has to be in place

1. **The three Vault secrets** — `fcm_service_account`, `push_dispatch_url`,
   `push_dispatch_token` (section 4).
2. **`android/app/google-services.json`** on the build machine when the app is
   built (section 3).
3. **`dispatch_push` deployed** (section 5).

Push was verified working end-to-end in June 2026 against the Firebase project
`alnujom-real-estate-test`: the app registered a device token on login, the
server dispatched in 1–2 seconds, and tapping the notification opened the correct
listing.

### "Push stopped working" — what to check, in order

1. **Did the last build include `google-services.json`?** This is by far the most
   common cause. The file is not in the repository, so a build on a fresh machine
   silently produces an app with no push. Symptom: nobody gets phone banners, but
   the in-app bell still works.
2. **Are the three Vault secrets still there?** Run the `vault.secrets` query in
   section 4. If `push_dispatch_url` or `push_dispatch_token` is missing, the
   database trigger skips quietly — no error anywhere.
3. **Is the Firebase project still active?** Firebase Console → check the project
   and that the service account has not been disabled or its key revoked.
4. **Look at the function's logs.** Supabase → **Edge Functions → dispatch_push →
   Logs**. It answers with a reason:
   - `skipped: no_provider` → the `fcm_service_account` secret is missing.
   - `skipped: no_tokens` → that user's phone never registered (they may not have
     granted the notification permission, or have not logged in since install).
   - `skipped: muted` → the user turned notifications off in their own settings.
   - `401` → the `push_dispatch_token` in the Vault no longer matches.
5. **Did the user allow notifications?** Android 13 and newer ask permission. A
   user who declined gets nothing until they re-enable it in Android settings.

### Two appearance problems, both fixed — what to expect now

This section used to say notifications never popped up as a banner, and that was
right at the time. Both of the things that made pushes look broken are fixed in
code now, so if you are testing on a device, this is what "working" looks like.

**They pop over the screen.** Android channels own the importance, not the
message, and the app never created the channel it pointed FCM at — so the SDK
fell back to a quiet default and everything landed silently in the shade. The
app now creates `alnujom_notifications_v2` with high importance at startup. The
`_v2` is load-bearing: a channel is immutable once created, and Android
deliberately remembers deleted channels, so the only way an existing install
picks up the upgrade is a new id.

**They no longer show a white square.** The manifest never declared a
notification icon, so FCM fell back to the launcher icon — and since Android 5.0
the system keeps only the icon's transparency and paints everything else white.
The launcher icon is completely opaque, so every push arrived as a plain white
block. There is now a proper flat-white `ic_notification` drawable at five sizes.

⚠️ **If a designer ever replaces that icon, it must be white-on-transparent
only.** A full-colour image brings the white square straight back and nothing in
the build will warn you.

Both need a **new build** to reach anyone — they are app-side, not server-side.

---

## 7. Shipping a new version

Two things must happen, in this order. Getting them backwards tells everyone an
update exists before it is downloadable.

### Step 1 — Build the app

On the build machine, from the project folder:

```bash
flutter build apk --release \
  --split-per-abi \
  --obfuscate --split-debug-info=build/symbols \
  --dart-define-from-file=.env.json
```

- `--dart-define-from-file=.env.json` is **mandatory**. Without it the app cannot
  reach Supabase.
- `--split-per-abi` produces one file per phone type instead of one giant file.
  Take **`app-arm64-v8a-release.apk`** — about **38 MB** instead of ~90 MB. That
  difference matters a great deal on mobile data. It covers essentially every
  phone in use today.
- `--obfuscate` makes the app harder to copy. Keep the `build/symbols` folder
  somewhere safe (out of the repository) — without it, crash reports from this
  build are unreadable.

Before you hand the file out, **install it on a real phone and open it.** Check
the icon and splash look right, log in, and browse.

> **If the build suddenly fails with "no versions of androidx.test:rules are
> available"** — nothing is broken and nothing needs installing. `dl.google.com`,
> which hosts Google's Maven repository, answers **404 for every path from this
> network**. Two of the app's test dependencies are requested as open ranges
> (`1.2+`, `3.3+`), and a range has to be re-checked against the repository once
> a day. When that check cannot be made, Gradle fails the whole build rather
> than using the copy it already has.
>
> `android/build.gradle.kts` now pins those two to the exact versions on disk, so
> the question is never asked. If it ever comes back, the fix is the same shape:
> find the range in the error, pin it to a version already in
> `~/.gradle/caches/modules-2/files-2.1/`.
>
> The wider point: **this machine cannot reach Google's Maven.** A fresh build
> machine will need one build from a network that can, or a copy of the
> `~/.gradle` folder from this one.

### Step 2 — Post it to Telegram

Upload the APK to the Telegram channel as a **file attachment**, and copy the
**post URL**.

### Step 3 — Update the version manifest

The app checks a small file on Supabase Storage once per launch and shows an
"Update available" prompt if the file says a newer version exists.

Supabase dashboard → **Storage** → bucket **`app-release`** → folder **`android`**
→ replace **`latest.json`**.

Its shape (the template lives at `docs/release/version-manifest.example.json`):

```json
{
  "latest_version": "1.1.0",
  "latest_build": 2,
  "min_supported_version": null,
  "download": {
    "telegram_url": "https://t.me/YOUR_CHANNEL/123",
    "website_url": null
  },
  "release_notes": {
    "ar": "تحسينات على البحث وسرعة أعلى.",
    "en": "Search improvements and better speed."
  }
}
```

- `latest_version` / `latest_build` must match the `version:` line in
  `pubspec.yaml` for the build you just posted (currently `1.1.0+2` → `"1.1.0"`
  and `2`).
- `telegram_url` is the post URL from step 2. This is what the **Update** button
  opens.
- `release_notes` shows inside the prompt. Write the Arabic one; it is what most
  users read.

### Step 4 — Check it

Open the app on a phone still running the old version. You should see the update
prompt on a cold start (fully close the app first — it checks once per launch).
Tap **Update** and confirm Telegram opens on the right post.

> **If the manifest is wrong or unreachable, nothing bad happens** — the app
> silently skips the check. A broken manifest cannot break the app; it just means
> nobody is told about the update.

### The order that matters

Manifest **last**. If you update `latest.json` before the APK is on Telegram,
every user is prompted to update and the Update button takes them to nothing.

---

## 7b. Finishing an account deletion

When someone taps **Delete my account**, the app does most of the work at once:
their name, phone and email are wiped, their listings drop out of search and the
map, and their chats and saved items are removed. Two things are deliberately
left behind for a while:

- the **login row** itself, and
- the **photos** they had uploaded.

That is on purpose. People delete accounts by mistake, and this is the only
window in which it can be undone. After **30 days** the rest should go.

**How to finish it.** Supabase dashboard -> **Edge Functions** ->
`purge_deleted_accounts` -> **Invoke**, with your own admin login. Send this
first, to see what *would* happen without changing anything:

```json
{ "dry_run": true }
```

It answers with how many accounts are due and how many files each one has. If
that looks right, send it again without the dry run:

```json
{}
```

It then deletes the photos, removes the login row, and marks each request done.
The reply lists what it did per account.

**When to run it:** once a month is plenty. There is nothing to do until someone
actually deletes an account — with an empty queue the function simply reports
zero and changes nothing.

**Who can run it:** only an account holding the **suspend users** permission.
Anyone else gets "permission denied", and so does a request with no login at
all.

> Not on a timer, on purpose. Automating it would mean putting the master key
> into GitHub, which the project's own rule forbids
> (`docs/decisions/0001-secrets-and-pii-storage.md`). Running it by hand once a
> month is the honest trade at this size. **The purge itself has never been
> exercised on a real account** — do it once with a throwaway account before
> trusting it, and check afterwards that the photos give a "not found" and the
> request shows as purged.

---

## 8. Maintenance mode — taking the app down safely

This is your emergency brake. Turn it on and every user sees a polite
"we'll be back" screen in their own language instead of a broken app. Use it
when you are fixing data, when something is badly wrong, or during a risky
change.

### Turning it on

**From inside the app** (the normal way): log in as an admin with the settings
permission → **Admin → Settings** → the **Maintenance mode** switch. Write a
short message in Arabic and English explaining what is happening and roughly when
you will be back. Save.

**From the Supabase dashboard** (if the app itself is the problem) → SQL Editor:

```sql
select public.set_app_setting(
  'maintenance_mode',
  '{"on": true, "message": {"ar": "نقوم بأعمال صيانة، نعود قريباً.", "en": "We are doing maintenance, back shortly."}}'::jsonb
);
```

### Turning it off

```sql
select public.set_app_setting(
  'maintenance_mode',
  '{"on": false, "message": {"ar": null, "en": null}}'::jsonb
);
```

### What you need to know

- **The app notices on launch and when it comes back to the foreground** — not
  instantly. A user already deep inside a screen may keep going for a minute or
  two. Do not treat it as an instant kill switch.
- **It is not a security control.** It hides the app's screens; it does not stop
  the database. If you need to actually block access, that is a different
  conversation with your developer.
- **Every change is recorded.** Who flipped it and when is written to the audit
  log automatically.
- **The `set_app_setting` call refuses anyone without the settings permission** —
  running it as yourself in the SQL Editor works because the SQL Editor runs with
  elevated rights.

### The other settings on that screen

The same `app_settings` table holds seven more values you can change without a
new app build:

| Setting | What it does |
|---|---|
| `default_language` | Language a brand-new account starts in. Seeded as `"ar"`, **but the live value is `"en"`** — see below. |
| `default_currency` | Currency a brand-new account starts in (`"SYP"`) |
| `default_publisher_name_visibility` | Whether a new listing shows the seller's name by default |
| `default_location_visibility` | Whether a new listing's map pin is exact or approximate by default (`"approximate"`) |
| `support_contact` | The phone / WhatsApp / email shown on the About and maintenance screens |
| `terms_url` | Link to your terms of service |
| `privacy_url` | **Link to your privacy policy** — set this once you host it (see `docs/legal/README.md`) |

Changing a default only affects **new** accounts and **new** listings. Existing
ones keep what they had.

### What those settings actually hold right now (read live, 2026-09-02)

Three of them are not what the app was built to assume. None of them break
anything today, but two should be set before real users arrive.

**1. `default_language` is `"en"`, not `"ar"` — change it.** The migration seeds
it to Arabic; it was switched to English from this screen on 2026-06-02, most
likely while trying the screen out. Nothing reads a user's stored language today
(the interface picks Arabic on its own, and the server does not use the value),
so no one has seen an English app because of it. But it is the wrong default for
an Arabic-first product to be carrying into launch, and the moment anything does
start reading it — a notification template, an email — every account created
until then would be flagged English. **Admin → Settings → Default language → set
to Arabic.** One click.

**2. `support_contact` is completely empty** — no phone, no WhatsApp, no email.
The screens that offer support handle this correctly (they hide the buttons and
say no contact is available rather than showing dead links), so nothing looks
broken. But it means a user who is locked out of their account reaches a dead
end: the "we cannot email you a reset" screen is exactly where the WhatsApp
button belongs. **Set at least the WhatsApp number before launch.**

**3. `terms_url` and `privacy_url` are empty**, so the About screen shows no
legal links at all. The privacy policy is already written (`docs/legal/`), it is
simply not hosted anywhere. Not urgent for Telegram distribution; **required**
before Google Play will accept the app.

---

## 9. The project is paused — how to restore it

Supabase's **free plan pauses a project after about 7 days with no activity.**
When that happens the app stops working completely — every screen fails to load,
logins fail, nothing recovers on its own.

You have chosen to stay on the free plan and prevent this with the keep-alive
robot (section 10) rather than upgrading. But if it ever does pause:

### Symptoms

- The app loads but every list is empty or shows a connection error.
- Login fails for everyone, including you.
- The keep-alive robot on GitHub turns red and emails you.
- The Supabase dashboard shows the project as **Paused** / **Inactive**.

### Restoring it

1. Go to <https://supabase.com/dashboard> and open the **AlNujom** project.
2. You will see a banner saying the project is paused, with a **Restore project**
   button. Click it.
3. Wait. Restoring typically takes a few minutes; a large project can take
   longer. The dashboard shows progress.
4. When it says active, open the app and check that listings load and you can log
   in.
5. **Check the keep-alive robot.** GitHub → repository `MHekmatF/alnujom` →
   **Actions** tab → **supabase keep-alive**. If its recent runs are red, that is
   why the project paused. Fix the cause (usually a missing or wrong repository
   secret — see section 10) and click **Run workflow** to confirm it goes green.

### Things to know

- **Your data is not deleted when a project pauses.** It is preserved and comes
  back with the restore.
- A project left paused for a very long time may need Supabase support to bring
  back. Do not leave it paused for months.
- While paused, **nothing works** — not the app, not push, not the admin screens.
  There is no partial degradation.

### If it keeps happening

The keep-alive robot is not running. Either its schedule was disabled (GitHub
switches off scheduled jobs in a repository with no activity for 60 days and
emails the owner), or its repository secrets are missing. Both are covered next.

---

## 10. The keep-alive robot

`.github/workflows/supabase-keepalive.yml` is a small GitHub robot that makes one
tiny read from the database **every Monday, Wednesday and Friday**. That counts
as activity, so Supabase never decides the project is idle. Longest gap between
pings: about 3 days — comfortably inside the ~7-day window.

It is also an early-warning alarm: if Supabase cannot be reached, the run turns
**red** and GitHub emails you. A red run is worth looking at the same day.

### One-time setup — two repository secrets

GitHub → repository **`MHekmatF/alnujom`** → **Settings** → **Secrets and
variables** → **Actions** → **New repository secret**. Add both:

| Secret name | Where to get the value |
|---|---|
| `SUPABASE_URL` | Supabase → Project Settings → Data API → **Project URL**. Looks like `https://hczsgceagommznjaohyk.supabase.co` — no trailing slash. |
| `SUPABASE_ANON_KEY` | Same page → Project API keys → the **anon / public** key. This is the same key already inside the app. |

Use the **anon** key. **Never** put the `service_role` master key into GitHub.

### Running it by hand

GitHub → **Actions** tab → **supabase keep-alive** → **Run workflow**. Useful
right after you set the secrets, and any time you want to check the project is
alive.

### If it turns red

1. Open the failed run and read the last lines. It prints the HTTP status.
2. **Project paused** → restore it (section 9).
3. **HTTP 401** → the anon key secret is wrong or was rotated. Copy it again
   from Supabase and update the GitHub secret.
4. **Nothing reachable at all** → check <https://status.supabase.com>. If
   Supabase is having an outage, wait; the next scheduled run will go green.
5. **"Missing repository secrets"** → you have not added them yet.

### One thing to watch

GitHub **switches off scheduled robots in a repository with no pushes for 60
days** and emails the owner. If development goes quiet for two months, go to the
Actions tab and re-enable the workflow — otherwise the pings stop and Supabase
pauses.

---

## 11. First-30-days checklist

### Week 1 — the team and the safety nets

- [ ] **Log in as super-admin** and confirm you see the admin section (section 1).
- [ ] **Set the password-reset URLs** in Supabase and test one real reset
      (section 2).
- [ ] **Turn on custom SMTP** (section 2). Without it, reset mail does not
      reliably reach real users — and it fails silently, which is the worst kind.
- [ ] **Set the default language back to Arabic** and **fill in the support
      WhatsApp number** — Admin → Settings. Both are one click and both are
      wrong right now (section 8).
- [x] **Add the two GitHub secrets and run the keep-alive robot by hand** — done
      2026-09-01: `SUPABASE_URL` and `SUPABASE_ANON_KEY` are in the repository
      secrets and the manual run went green in 10 s. It now runs on its
      schedule; keep an eye out for the red email (section 10).
- [ ] **Save all the secrets in a password manager**: the keystore file and its
      passwords, `.env.admin.json`'s master key, the GlitchTip DSN, and the five
      operator Vault secrets (section 4). Losing the keystore is unrecoverable.
- [ ] **Confirm the crash inbox works** — ask your builder to send a test crash
      and confirm it appears in GlitchTip. If GlitchTip stays empty, `SENTRY_DSN`
      is blank or wrong.
- [ ] **Confirm push works on a real phone** — log in, have someone approve a
      listing, and check the banner arrives (section 6).
- [ ] **Enroll your moderators** via the in-app **Roles** screen. Keep
      super-admin to you plus one backup.
- [ ] **Write down a backup super-admin** so someone else can get in if you lose
      your phone.

### Weeks 1–4 — run the queues

- [ ] **Approve or reject new seller accounts.** A seller cannot post until both
      their **account** and their **publisher** status are approved.
- [ ] **Approve or reject listings** before they go public.
- [ ] **Work the reports queue** from the admin **Reports** screen.
- [ ] **Watch GlitchTip a few times a week.** A spike after a release means
      something broke — send the report to your developer.
- [ ] **Watch the keep-alive robot's emails.** Red means look now.
- [ ] **Glance at Supabase → Logs** if something seems off; **Authentication →
      Users** shows recent sign-ups.

### Before the month is out

- [ ] **Confirm backups and do one restore drill.** Supabase → **Database →
      Backups**. **The free plan does not include automatic daily backups.** If
      you are staying on free, arrange a manual export on a schedule with your
      developer — otherwise a mistake is permanent. Practise the restore once, so
      an emergency is not your first attempt.
- [ ] **Host the privacy policy and set `privacy_url`** in the admin settings
      (see `docs/legal/README.md`). Required before Google Play, and good
      practice regardless.
- [x] **Leaked-password protection — NOT AVAILABLE, stop chasing it.** Verified
      on 2026-09-01: the toggle lives at Authentication → Sign In / Providers →
      Email → "Prevent use of leaked passwords", and it is labelled *"Only
      available on Pro plan and above."* This project is on the **Free** plan,
      so it cannot be switched on. `get_advisors(security)` will keep reporting
      it as a WARN — that is expected, not a task. Revisit only if the project
      is ever upgraded.
      What IS available on Free, and worth turning on: **"Secure password
      change"** on the same screen, which stops a stolen old session from
      silently changing the password. It does not break the reset flow — a
      recovery session is brand new, so it satisfies the recency check.
      Do **not** turn on "Require current password when updating" without
      testing: password reset completes with a recovery session and no current
      password, so it may block the reset flow.
- [ ] **Restrict the Firebase Android key** — Google Cloud Console → the `AIza…`
      key → restrict to package `com.alnujom.app` plus your release signing
      fingerprint, and to the Firebase/FCM APIs only.
- [ ] **Review who has admin/super-admin** and remove anyone who no longer needs
      it.
- [ ] **Rotate the master key** once the team is stable — Supabase → Project
      Settings → API. Put the new value into `.env.admin.json`. Rotate
      *immediately*, not on schedule, if you suspect a leak or someone with
      access leaves.

---

## 12. Known gaps and where the truth lives

The authoritative, always-current list of what is finished and what is not lives
in the release dossier:

➡️ **[`docs/release/v1.0.0.md`](../release/v1.0.0.md)**

At the time of writing, the headline items are:

- **The Telegram channel** — the one thing still blocking distribution
  (section 7).
- **A signed `1.1.0+2` build has not been recorded as verified.** The app has
  changed enormously since the `1.0.0` checks. Re-walk the basics before handing
  the file out.
- **Two open security items**, neither of which blocks launch: a signed-up user
  could hand-craft a raw request to read a property's exact map pin; and a
  phone-number lookup reveals the real email for three non-end-user accounts.
  Both are described precisely in
  [`docs/qa/e2e-2026-07-16/SECURITY_AUDIT.md`](../qa/e2e-2026-07-16/SECURITY_AUDIT.md).
- **Phone numbers are not verified by SMS** — someone can register a number they
  do not own. Verify numbers manually in admin where it matters.

  **"Can we just send a free SMS code instead?"** — no, and it is worth knowing
  why so the question does not keep coming back. Supabase can send login codes
  by SMS, but only through a paid gateway you connect yourself (Twilio,
  MessageBird, Vonage). None of them are free, all of them charge per message,
  and — the part that actually decides it — none of them deliver reliably to
  Syrian `+963` numbers. Sanctions and carrier agreements, not price, are the
  blocker. Paying would not fix it.

  What works instead, in rough order of effort:
  1. **WhatsApp.** Practically everyone here has it, it reaches `+963` fine, and
     the app already treats it as the support channel. A code sent by hand over
     WhatsApp costs nothing today; a WhatsApp Business API sends them
     automatically later.
  2. **Manual reset in admin** — already documented in section 2, and fine at
     current volume.
  3. **A real email at sign-up.** The reset flow works properly for anyone who
     gives one, which is why the register screen asks.
- ~~Push notifications do not pop up as banners~~ — **fixed and verified.** They
  now arrive as heads-up banners. An Android channel's importance is frozen the
  moment it is created, so the fix had to ship a new channel id
  (`alnujom_notifications_v2`) rather than raise the old one. Confirmed on the
  Infinix Note 8 with `importance=4` (section 6).
- **Two-device checks** carried over from earlier phases are still unverified.

**Branding is done** — the placeholder blue star described in older versions of
this document was replaced in Phase 033 by the "orbit" emblem (icon and splash).
Ignore any note still warning about the star.

**For Google Play**, see [`docs/release/google-play-readiness.md`](../release/google-play-readiness.md).
**For the privacy policy**, see [`docs/legal/README.md`](../legal/README.md).

---

*Operator handover playbook. Pair with `docs/release/v1.0.0.md` (what is verified
and what is open) and `docs/RUNBOOK.md` (record of one-time dashboard settings
already applied). Whenever you change a Supabase dashboard setting, write it into
the RUNBOOK so the next person knows.*
