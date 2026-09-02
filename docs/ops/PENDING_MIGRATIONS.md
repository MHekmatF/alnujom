# Migration status — 2026-09-02

Four migrations were written on 2026-09-01 and two more on 2026-09-02. **Four
are applied and verified. Two are deliberately held back** — each for a specific
reason, below.

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

**Verified end to end** on 2026-09-01: a throwaway account was registered through
the app, deleted through the app's own button, and checked afterwards — phone
released, status tombstoned, name nulled, operator-queue and audit rows written,
and `auth.users.email` renamed to `deleted-<uuid>@deleted.alnujom.local` so the
number can register again. The test account was then purged completely.

**Still owed:** the RPC does not remove the `auth.users` row or the account's
uploaded files. `account_deletion_requests.purge_status` is your work queue for
that.

---

## ✅ 2b. `20260902120001_restore_anon_execute_on_permission_helper.sql` — APPLIED 2026-09-02

**A second live guest-facing defect, the same shape as the first.**

`v_agencies` is a SECURITY DEFINER view, so its WHERE clause is its only
visibility gate — and that clause calls `current_user_has_permission()`. Function
EXECUTE is checked against the **calling** role even inside a definer view, and
`anon` held none, so **every anonymous read of the agencies directory failed**
with `42501: permission denied for function current_user_has_permission`.

Verified before: `42501`. After: the approved agencies come back.

Granting it to `anon` is safe — the helper answers only "does the CURRENT caller
hold this permission", keyed on `auth.uid()`, so an anonymous caller gets FALSE
and learns nothing. The July audit had left the boolean RLS helpers alone for
exactly this reason.

**How it was found, and how to find the next one:** not by reading grants or
policies — both looked correct. By actually reading every relation *as* the role.
`supabase/scripts/probe_role_read_access.sql` does that sweep. **Run it after any
migration that touches grants, policies, views or the RLS helpers** — including
after applying migration 3 below, which revokes columns.

---

## ✅ 2c. `20260902120002_seal_map_jitter_oracle.sql` — APPLIED 2026-09-02

**A privacy control that could be undone by anyone holding the public anon key.**

Listings set to `approximate` location visibility are shown on a *jittered* pin —
the true position plus a secret offset derived from `sha256(listing_id || vault
salt)`. The offset has to be deterministic, or the pin would wander between page
loads. That determinism was fine. What was not fine is that
`map_jitter_coordinates()` took the true coordinates as **caller-supplied
arguments** and was executable by `anon`, which made it an oracle:

```
1. read the public marker                     m  = true + offset
2. call the jitter RPC with m as the anchor   m' = m + offset
3. offset = m' - m      →      true = m - offset
```

Two RPC calls, no account. **Verified against the live database on 2026-09-02
using only `SUPABASE_ANON_KEY`: recovered `33.511000 / 36.306000` for a listing
stored at `33.511000 / 36.306000` — error 0.000000 on both axes.**

The ±0.02° clamp around the area centroid happens to defeat this for listings
that sit far from their centroid (both readings clamp to the same bound). That
is luck, not a control: a listing near its area centroid — the normal case —
gave up its exact pin every time.

Fixed in two layers:

- **The function no longer trusts the caller for the thing it protects.** It now
  reads `listings.latitude/longitude` for `p_listing_id` itself;
  `p_original_lat` / `p_original_lng` are ignored, kept only so the signature and
  its one caller are unchanged. Proven live: calls with anchor `0,0` and with
  anchor = the published marker now return the *same* point, equal to the marker.
- **EXECUTE revoked from `anon` and `authenticated`.** The oracle call now
  answers `42501 permission denied for function map_jitter_coordinates`.

**No pin moved.** `listing_marker_coordinates` already passed exactly the
coordinates the function now looks up; the guest map returned byte-identical
markers before and after.

Why the revoke is safe now though it was not in July: `20260717120010` left the
anon grant deliberately, noting the function was "called by the security_invoker
view `v_listings_map_public`". That note went stale *the day before* — migration
1 above rebuilt that view on top of `listing_marker_coordinates`, which is
SECURITY DEFINER, so the inner call is authorised as the function owner and needs
nothing from the caller. **The lesson: a grant justified by one call site
outlives the call site. When a migration re-points a view, re-check the grants
the old shape needed.**

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
`request_password_reset` finds users by their `auth.users` email. Checked live on
2026-09-01: **exactly one** account has a real email — the founder's — not the
three the audit estimated. So the disclosure is one account wide, and applying
this would switch off emailed password reset for the only account the
newly-completed reset flow can serve at all.

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

- **Leaked-password protection — not actionable on this plan.** The toggle
  ("Prevent use of leaked passwords", Authentication → Sign In / Providers →
  Email) is gated behind Supabase's **Pro plan**; this project is on Free. Its
  standing WARN in `get_advisors(security)` is expected and should not be
  treated as an open task.
- **`supabase/scripts/pre_launch_data_cleanup.sql`** — removes the 26 development
  listings. **Deliberately not run**: with distribution deferred, that content is
  what the app has to demo. Run it when launch is actually close. Its delete
  block ends in `ROLLBACK` so you see the counts before committing to them.
