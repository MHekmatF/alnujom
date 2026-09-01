# Pending migrations — apply in this order

Four migrations were written on 2026-09-01 while the Supabase project was
**paused**. None of them has ever run. They are not interchangeable: one of them
fixes a bug that is live right now, and one of them **must not** be applied until
a new app build is in users' hands.

Apply them with the Supabase MCP `apply_migration` tool, one file at a time, in
the order below. Do not use `supabase db push` — this project's CLI database path
does not work (see `docs/ops/HANDOVER.md`).

After each one, run `get_advisors(security)` and confirm no new errors appear.

---

## 1. `20260901120001_gate_listing_coordinates.sql` — apply first, on its own

**Apply this as soon as the project is restored.** It is additive, backward
compatible with the app build that is already out, and it repairs a live defect.

**The live defect:** an earlier migration (`20260717120007`) revoked
`latitude`/`longitude` on `listings` from the `anon` role. But
`v_listings_map_public` is a `security_invoker` view that reads those columns,
and an invoker view checks column privileges against the *caller* — so the map
view very likely **fails for signed-out visitors today**: the guest map and the
guest listing-detail marker.

This migration adds a `listing_marker_coordinates()` SECURITY DEFINER function
that owns the raw read and returns only the visibility-gated marker, and rebuilds
the map view on top of it.

**Verify right after applying:** open the app signed out and confirm the map
shows markers and a listing's detail page shows its pin. Then check the same
while signed in.

---

## 2. `20260901120004_self_serve_account_deletion.sql` — apply any time after 1

Independent of the coordinate work. Creates the `request_account_deletion()` RPC
and the `account_deletion_requests` operator queue.

**Until this is applied, the app's "Delete my account" button will fail.** That
button is already in the build, and the published privacy policy promises it
works — so this is not optional if you host the policy.

It soft-deletes and anonymises rather than hard-deleting, because a hard
`DELETE FROM auth.users` would cascade away the *other* party's chats, viewings
and reviews.

**Verify:** delete a throwaway account end to end. Check that the profile is
tombstoned, its listings disappear from search/map/home, its three Vault secrets
are gone, and a row lands in `account_deletion_requests`.

**Note:** the RPC does not remove the `auth.users` row or the account's uploaded
files. `account_deletion_requests.purge_status` is your queue for doing that.

---

## 3. `20260901120002_revoke_authenticated_listing_coordinates.sql` — **only after the new app build is live**

⚠️ **Do not apply this before users have the new build.** It revokes
`latitude`/`longitude` from `authenticated`. The current build reads those
columns directly in the publisher edit form, the admin revision snapshot and the
admin listing preview — applying it early breaks all three for everyone still on
the old build. A one-line rollback is in the file's header.

What it closes: a signed-in user could make a raw REST call and read the exact
coordinates of any listing, defeating the "approximate location" privacy setting
that owners chose.

**Verify:** the publisher edit form (load, change location, save, submit), the
stay-live revision flow, the admin revision diff, the admin listing preview —
and confirm a raw REST `select=latitude` now returns `42501` for a signed-in
user.

---

## 4. `20260901120003_normalize_auth_emails_to_synthetic.sql` — **needs a decision first**

Independent of everything above. Closes a small disclosure: `lookup_email_by_phone`
returns the real login email for the handful of accounts that have one, which
leaks a phone-to-email mapping and confirms whether a number is registered.

**The trade-off, which is yours to make:** `request_password_reset` finds users by
their `auth.users` email. Once those are synthetic, **emailed password reset stops
working for the 3 accounts that currently have a real email.** It fails quietly —
nothing breaks or leaks, the caller still gets the uniform `{ok:true}` — those
users simply never receive a mail, and you would reset their password by hand
from the dashboard, exactly as you already do for every phone-only account.

The file's header documents a per-account opt-out if you want to keep emailed
reset for one specific staff login.

**Verify:** sign in with one of the three real-email accounts, and confirm the
post-apply `RAISE NOTICE` reports 0 remaining non-synthetic emails.

---

## Also waiting on the restore

- **`supabase functions deploy request_password_reset`** — the password-reset
  deep link does nothing until this is redeployed. See `HANDOVER.md` section 2.
- **`supabase/scripts/pre_launch_data_cleanup.sql`** — removes the development
  listings. Read it before running; its delete block ends in `ROLLBACK` so you
  see the counts before committing to them.
