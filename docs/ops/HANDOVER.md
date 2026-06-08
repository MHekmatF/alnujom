# AlNujom — Operator Handover Playbook

A plain-language guide for the new owner of AlNujom. It walks you through the
handful of one-time setup steps needed to run the app, then gives you a
First-30-Days checklist for day-to-day operations.

You do **not** need to be a programmer to follow this. Where a step needs a
developer's help, it says so. Everything is done from web dashboards (Supabase)
and a couple of small text files on the build machine.

> **The two dashboards you will live in:**
> - **Supabase** — the database, user accounts, and login settings.
>   Project name **AlNujom**, project reference `hczsgceagommznjaohyk`.
>   Log in at <https://supabase.com/dashboard>.
> - **GlitchTip** — the crash-report inbox (tells you when the app breaks for a user).

---

## A quick mental model

- **Buyers and sellers** use the Android app. Sellers ("publishers") post
  property listings; buyers browse and send inquiries.
- **Moderators and admins** approve new seller accounts, approve listings before
  they go public, and handle reports.
- **You (the super-admin)** sit at the top: you create the moderators and admins,
  and you hold the master keys (the "service-role key", below).

Nothing happens automatically. A new seller's account must be approved by a
person before they can post, and each listing must be approved before the public
sees it. That is by design.

---

## 1. Create the first super-admin

When the app first goes live there are **no administrators** — every new sign-up
gets the plain "user" role automatically, and a plain user cannot approve
anyone. So the very first admin has to be granted by hand, one time, directly in
the database. After that, you can create every other moderator/admin from inside
the app's admin screens.

**Step by step:**

1. **Install the app and register a normal account** with the phone number you
   want to be the owner account. Choose a strong password. Complete the sign-up
   so the account exists.

2. Open the **Supabase dashboard** → project **AlNujom** → **SQL Editor**
   (left sidebar).

3. Find your new account's internal ID by running this query (replace the phone
   number with yours, in full international form, e.g. `+9639XXXXXXXX`):

   ```sql
   select user_id, phone, full_name
   from public.profiles
   where phone = '+9639XXXXXXXX';
   ```

   Copy the `user_id` value (a long string of letters/numbers).

4. Grant that account the **super-admin** role by running this (paste your
   `user_id` where shown):

   ```sql
   insert into public.user_roles (user_id, role_id)
   values (
     'PASTE-YOUR-USER-ID-HERE',
     (select id from public.roles where key = 'super_admin')
   )
   on conflict (user_id, role_id) do nothing;
   ```

5. If your account is still **pending approval** (a brand-new sign-up usually
   is), also approve it so you can log all the way in:

   ```sql
   update public.profiles
   set account_status = 'approved'
   where user_id = 'PASTE-YOUR-USER-ID-HERE';
   ```

6. **Fully close and reopen the app, then log in again.** You should now see the
   admin section. From here on, use the in-app **Roles** screen to create
   moderators and other admins — you should never need step 4 again.

> **Do this only once.** Granting super-admin by hand is a master-key action.
> Keep the list of super-admins tiny (ideally just you, plus one trusted backup).

---

## 2. Turn on password reset (Supabase login settings)

The app lets a user request a "reset my password" link. For that link to
actually work, Supabase has to be told which addresses it is allowed to send
people back to. Today this is set to a **placeholder** and must be pointed at the
app's real reset address: **`alnujom://auth/reset-password`**.

(That funny-looking address is a "deep link" — tapping it opens the AlNujom app
directly instead of a web page.)

**Step by step:**

1. Supabase dashboard → project **AlNujom** → **Authentication** (left sidebar)
   → **URL Configuration**.

2. **Site URL** — set it to exactly:

   ```
   alnujom://auth/reset-password
   ```

3. **Redirect URLs** — click **Add URL** and add the same value (and keep it on
   the allow-list):

   ```
   alnujom://auth/reset-password
   ```

4. Click **Save**.

5. While you are in Authentication, confirm these two settings are correct (they
   were set during build and should already be right — just verify):
   - **Settings → Password → Minimum length** = **8**
   - **Providers → Email → Confirm email** = **OFF / unchecked**
     (the app uses phone numbers, not real mailboxes, so email confirmation must
     stay off or sign-ups will break).

> **Known limitation to be aware of.** Finishing a password reset from the
> emailed link is a feature that is **not fully built yet** (it is on the parked
> list — see Section 5). In the meantime, if a user is truly locked out, a
> super-admin can set a temporary password for them from
> **Authentication → Users** → pick the user → **Change password**, and tell them
> to change it in the app afterwards. The app uses phone numbers, so there is no
> self-serve email recovery to rely on.

---

## 3. Crash reporting and the master key (two small text files)

The app's settings and secrets live in two small text files on the **build
machine** (the computer that produces the app's installable file). These files
are deliberately kept out of the shared code so secrets never leak.

You will rarely touch these yourself — they are usually managed by whoever builds
the app — but you must understand what they are and the one rule that protects
you.

### The two files

| File | What it holds | Goes into the app? |
|---|---|---|
| `.env.json` | Public-safe settings: the database web address, the public "anon" key, and the **crash-report address (`SENTRY_DSN`)** | **Yes** — these are safe to ship |
| `.env.admin.json` | The **master key** (`SUPABASE_SERVICE_ROLE_KEY`) used only by back-office tools | **No, never** — it must never go into a build |

### Set the crash-report address (`SENTRY_DSN`)

Crash reports go to **GlitchTip**, a private crash inbox. To switch it on, the
builder puts the GlitchTip "DSN" (a long web address GlitchTip gives you) into
`.env.json`:

```json
{
  "SUPABASE_URL": "https://hczsgceagommznjaohyk.supabase.co",
  "SUPABASE_ANON_KEY": "....(the public key)....",
  "SENTRY_DSN": "https://....(your GlitchTip DSN)....",
  "DESIGN_TOOLS": false
}
```

- If `SENTRY_DSN` is **left empty**, crash reporting is simply off (the app still
  works fine — it just does not phone home about errors). This is safe.
- When it is filled in, crashes from real users land in your GlitchTip inbox with
  the technical detail a developer needs to fix them. Reports are scrubbed of
  personal data by design.
- The app must be rebuilt for a change to this file to take effect.

### The one rule about the master key

`.env.admin.json` holds the **service-role key** — think of it as the master key
to the entire database. It bypasses every safety rule.

- It lives **only** on the build/admin machine, in `.env.admin.json`.
- It is **never** put into `.env.json`, and **never** shipped inside the app.
  (The app only carries the harmless public "anon" key.)
- Never paste it into chat, email, screenshots, or the code repository.
- If you ever suspect it leaked, rotate it immediately (see the 30-day
  checklist).

> Both files are "gitignored" — meaning the code repository is configured to
> ignore them so they can't be committed by accident. Keep it that way.

---

## 4. First-30-Days checklist

Work through these in roughly this order during your first month of running the
app. Tick them off as you go.

### Week 1 — get the team and the safety nets in place

- [ ] **Confirm you can log in as super-admin** and see the admin section
      (Section 1 done correctly).
- [ ] **Set the password-reset URLs** in Supabase (Section 2).
- [ ] **Confirm the crash inbox works** — ask your builder to send a test crash;
      confirm it appears in GlitchTip. If GlitchTip stays empty, `SENTRY_DSN` is
      probably blank or wrong.
- [ ] **Enroll your moderators.** In the app's admin **Roles** screen, create
      each trusted helper an account and assign **moderator** (day-to-day
      approvals) or **admin** (broader control). Keep **super-admin** to just you
      plus one backup.
- [ ] **Write down a backup super-admin.** Make sure one other trusted person can
      get in if you lose your phone.

### Weeks 1–4 — run the queues

- [ ] **Approve (or reject) new seller accounts** as they come in. A seller
      cannot post until both their **account** and their **publisher** status are
      approved — both are done from the admin screens.
- [ ] **Approve (or reject) listings** before they go public. Nothing a seller
      submits is visible to buyers until an admin approves it.
- [ ] **Work the reports queue.** When buyers report a bad listing, resolve it
      from the admin **Reports** screen.
- [ ] **Watch the crash inbox (GlitchTip) a few times a week.** A sudden spike
      after a new release means something broke — loop in your developer with the
      report.
- [ ] **Glance at the Supabase logs** if something seems off. Supabase dashboard
      → **Logs** lets you see database and login activity; **Authentication →
      Users** shows recent sign-ups.

### Before the month is out — protect your data and your keys

- [ ] **Confirm database backups are on, and do one restore drill.**
      Supabase dashboard → **Database → Backups**. Paid plans take **daily
      automatic backups**; confirm yours are running and note how many days are
      retained. Once, practice the restore path (Supabase's
      **Point-in-Time Recovery** / restore screen) so a real emergency isn't your
      first time. If you are on a plan without automatic backups, ask your
      developer to schedule a manual export.
- [ ] **Rotate your secrets once you're confident the team is stable.**
      In **Supabase → Project Settings → API**, you can roll keys; the
      **service-role (master) key** is the important one. After rotating it, the
      new key must be put back into `.env.admin.json` on the build machine (it is
      never shipped in the app). Rotate immediately, not on schedule, if you ever
      suspect a leak or when a person with access leaves the team.
- [ ] **Review who has admin/super-admin** and remove anyone who no longer needs
      it (in the app's **Roles** screen).

---

## 5. Parked / unfinished items — read before you launch wide

A small number of items were intentionally left for later. They will **not**
stop the app from running, but you should know they exist. The authoritative,
always-up-to-date list lives in the release dossier:

➡️ **`docs/release/v1.0.0.md`**

That file tracks, among other things:
- **Telegram distribution** — the channel where the app's installable file is
  posted, and the "an update is available" prompt that points users to it.
- **Finishing the password-reset link** — today a user can request a reset, but
  completing it from the emailed link isn't wired up yet; until it is, use the
  admin "Change password" workaround in Section 2.
- **Cold-start performance check** on a real low-end phone.
- **Two-device checks** carried over from earlier testing.
- **Branding** — the current launcher icon/splash may still be a placeholder
  star; confirm the real logo is in place before any wide release.

When in doubt about whether something is finished, that document is the source of
truth. Keep it updated as you close items out.

---

*Operator handover playbook. Pair this with `docs/release/v1.0.0.md` (release
status + parked items) and `docs/RUNBOOK.md` (record of one-time dashboard
settings already applied). When you change a Supabase dashboard setting, note it
in the RUNBOOK so the next person knows.*
