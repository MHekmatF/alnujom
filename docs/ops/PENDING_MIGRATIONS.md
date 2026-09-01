# Migration status — 2026-09-01

Four migrations were written on 2026-09-01. **Two are applied and verified. Two
are deliberately held back** — each for a specific reason, below.

Apply the remaining ones with the Supabase MCP `apply_migration` tool, one file
at a time. Do not use `supabase db push` — this project's CLI database path does
not work (see `docs/ops/HANDOVER.md`). After each, run `get_advisors(security)`
and confirm no new errors appear.

> **A note on an earlier scare.** During this session the project appeared to be
> paused: DNS for `hczsgceagommznjaohyk.supabase.co` would not resolve and every
> query timed out. That turned out to be a **local resolver failure on the build
> machine**, not the project. The database was live the whole time. If you ever
> see the same symptom, check from a second network before concluding anything —
> and note that `nslookup` on that machine still fails while `curl` succeeds.

---

## ✅ 1. `20260901120001_gate_listing_coordinates.sql` — APPLIED 2026-09-01

**This repaired a defect that was live in production.**

An earlier migration (`20260717120007`) revoked `latitude`/`longitude` on
`listings` from the `anon` role. But `v_listings_map_public` is a
`security_invoker` view that reads those columns, and such a view checks column
privileges against the *caller* — so every anonymous read of the map view failed
with `42501 permission denied for table listings`. **The guest map and the guest
listing-detail marker were broken for every signed-out visitor.**

Verified before: `anon` → `42501`.
Verified after: `anon` sees all **16** approved listings, all with markers.

The fix adds `listing_marker_coordinates()` (SECURITY DEFINER) which owns the raw
read and returns only the visibility-gated marker; the view is rebuilt on top of
it and stays `security_invoker`. Also adds `get_listing_coordinates()` for
owner/admin reads, and drops the two coordinate columns from
`v_publisher_listings`.

Privacy re-verified after applying: all 16 approximate listings return a
**jittered** marker; **0** return their exact coordinate.

---

## ✅ 2. `20260901120004_self_serve_account_deletion.sql` — APPLIED 2026-09-01

Creates `request_account_deletion()` and the `account_deletion_requests` operator
queue. Without it the app's "Delete my account" button fails, and the published
privacy policy promises that button works.

It soft-deletes and anonymises rather than hard-deleting, because a hard
`DELETE FROM auth.users` would cascade away the *other* party's chats, viewings
and reviews.

Checked against the live schema **before** applying: every column and enum value
it touches exists, and the live body of `enforce_profile_status_admin_only()`
matched the base the amendment was written against.

Verified after: RPC owned by `postgres` (so it bypasses RLS as intended), `anon`
holds no EXECUTE, `authenticated` does, and no row in `profiles` or `listings`
changed.

**Still owed:** the RPC does not remove the `auth.users` row or the account's
uploaded files. `account_deletion_requests.purge_status` is your work queue for
that. And **nobody has actually deleted an account yet** — run one end-to-end on
a throwaway account before relying on it.

---

## ⏸ 3. `20260901120002_revoke_authenticated_listing_coordinates.sql` — HOLD until the new build is out

⚠️ **Do not apply this until users have the build from this branch.** It revokes
`latitude`/`longitude` from `authenticated`. The build people are running today
reads those columns directly in the publisher edit form, the admin revision
snapshot and the admin listing preview — applying it early breaks all three. A
one-line rollback is in the file's header.

What it closes: a signed-in user can currently make a raw REST call and read the
exact coordinates of any listing, defeating the "approximate location" setting
owners chose. Migration 1 already built everything this one needs; this is only
the privilege change.

**Verify after applying:** the publisher edit form (load, change location, save,
submit), the stay-live revision flow, the admin revision diff, the admin listing
preview — and confirm a raw REST `select=latitude` returns `42501` for a
signed-in user.

---

## ❓ 4. `20260901120003_normalize_auth_emails_to_synthetic.sql` — needs your decision

Closes a small disclosure: `lookup_email_by_phone` returns the real login email
for the handful of accounts that have one, leaking a phone-to-email mapping and
confirming whether a number is registered.

**The trade-off, and why it is not obviously worth taking.**
`request_password_reset` finds users by their `auth.users` email. Once those are
synthetic, **emailed password reset stops working for the 3 accounts that have a
real email** — and those 3 are the only accounts the newly-completed
password-reset deep link can serve at all. Applying this would switch off the
feature that was just built, for everyone who can use it.

It fails quietly (the caller still gets the uniform `{ok:true}`; nothing breaks
or leaks) and you would reset those passwords by hand from the dashboard, exactly
as you already do for every phone-only account. The file's header documents a
per-account opt-out if you want to keep emailed reset for one specific login.

**Recommendation: leave it unapplied for now.** The disclosure is small and
limited to non-end-user accounts; working password recovery is worth more.

---

## ✅ Also done

- **`request_password_reset` redeployed** (version 2) and verified live: the
  GoTrue log shows `generate_link` returning 200 with
  `redirect_to=alnujom://auth/reset-password`, so the deep link is accepted and
  **no dashboard change is needed**. The function now also falls back to sending
  the mail without the deep link if that address is ever refused, rather than
  sending nothing.

## Still outstanding

- **Leaked-password protection** is still off — a dashboard toggle
  (Authentication → Settings), and the only remaining WARN worth acting on in
  `get_advisors(security)`. It cannot be set through the API.
- **`supabase/scripts/pre_launch_data_cleanup.sql`** — removes the 26 development
  listings. **Deliberately not run**: with distribution deferred, that content is
  what the app has to demo. Run it when launch is actually close. Its delete
  block ends in `ROLLBACK` so you see the counts before committing to them.
