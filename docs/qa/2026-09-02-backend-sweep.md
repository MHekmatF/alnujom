# Backend + platform sweep — 2026-09-02

The device walk earlier the same day (`2026-09-02-device-walk.md`) covered what a
guest can *see*. This pass covers what the app sits on: the database's public API
surface, the deployed Edge Functions, and the Android platform wiring. Two real
defects came out of it. Everything else in here is a **negative result** — worth
recording so nobody spends the afternoon re-deriving it.

---

## 1. Anyone with the public key could undo the map-privacy jitter — FIXED

**Severity: the highest thing found in either pass.** A listing set to
`approximate` location visibility is meant to show a pin that is *near* the
property, not on it. That control could be removed by two anonymous RPC calls.

`map_jitter_coordinates()` added a secret per-listing offset — derived from
`sha256(listing_id || vault salt)`, so it is stable, which it has to be or the
pin would move on every page load. The flaw was that it took the true
coordinates as **caller-supplied arguments** and `anon` held EXECUTE on it. That
makes it an oracle:

```
1. read the published marker                m  = true + offset   (public, by design)
2. call the jitter RPC, passing m as the anchor
                                            m' = m + offset
3. offset = m' - m       →       true = m - offset
```

Verified live against production with nothing but `SUPABASE_ANON_KEY`:

```
1) public marker a guest sees : 33.51452239811188 , 36.30231272860798
2) jitter(marker)             : 33.51804479622376 , 36.29862545721597
3) recovered secret offset    : +0.003522 , -0.003687
4) RECOVERED EXACT LOCATION   : 33.511000 , 36.306000
   ground truth in listings   : 33.511000 , 36.306000
   error                      : 0.000000 , 0.000000
```

The ±0.02° clamp around the area centroid does defeat this for a listing that
sits far from its centroid — both readings clamp to the same bound, and the
first listing I tried returned an offset of exactly zero for that reason. That
is luck, not a control. A listing near its area centroid, which is the ordinary
case, gave up its exact position every time.

**Fixed by `20260902120002_seal_map_jitter_oracle.sql`, in two layers:**

- The function now reads `listings.latitude/longitude` for `p_listing_id`
  itself. `p_original_lat` / `p_original_lng` are ignored — kept only so the
  signature and its one caller are unchanged. Proven live: calls with anchor
  `0,0` and with anchor = the published marker now return the *same* point, and
  that point equals the marker. The oracle is dead for every role, including any
  future one that gets re-granted EXECUTE.
- EXECUTE revoked from `anon` and `authenticated`. The attack call now answers
  `42501 permission denied for function map_jitter_coordinates`.

**No pin moved.** The guest map returned byte-identical markers before and
after — `listing_marker_coordinates` was already passing exactly the coordinates
the function now looks up.

### How it got there, which is the part worth remembering

July's `20260717120010` left the anon grant on purpose, with a note in the
migration: *"map_jitter_coordinates — called by the security_invoker view
v_listings_map_public, so anon needs EXECUTE for the public map to work."* That
was true when it was written. It stopped being true on **2026-09-01**, when
`20260901120001` rebuilt that view on top of `listing_marker_coordinates`, which
is SECURITY DEFINER — inside a definer function PostgreSQL checks EXECUTE
against the function *owner*, so the caller needs nothing.

A grant justified by one call site outlived the call site by one day. **When a
migration re-points a view, re-check the grants the old shape needed.**

---

## 2. Every push notification showed a solid white square — FIXED

`AndroidManifest.xml` declared
`com.google.firebase.messaging.default_notification_channel_id` but **not**
`default_notification_icon`. With that meta-data absent, FCM falls back to
`android:icon`, which here is `@mipmap/launcher_icon`.

Since Android 5.0 the system keeps only a small icon's **alpha** and paints every
non-transparent pixel white. `launcher_icon.png` is 100% opaque at every density
(measured: `opaque 1.0, transparent 0.0`). So the status-bar icon — and the icon
in the notification shade — was a **solid white square** on every push the app
has ever sent. The CRM reminder notifications had the same problem through
`AndroidInitializationSettings('@mipmap/ic_launcher')`.

Fixed with a purpose-drawn `@drawable/ic_notification`: a flat white silhouette
at mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi (24/36/48/72/96 px), three towers of different
widths with a mast on the tallest and a four-point star. The mast and the varied
widths are what stop it reading as a bar chart at 24 px. Also added
`default_notification_color` → `@color/notification_accent` (`#1F4FE6`, matching
`ColorPalette.light.primary`), and pointed the local-notification plugin at the
same drawable.

Verified: both meta-data entries are in the merged release manifest and all five
densities are in `packaged_res/release`. (They do **not** show up by name in
`unzip -l` of the APK — release resource shrinking renames them to `res/0Z.png`
and the like. That is not a missing resource.)

> **If you ever replace this icon, keep it alpha-only.** A coloured or opaque
> replacement brings the white square straight back, and nothing in the build
> will tell you.

---

## Checked and clean — do not redo these

**Edge Function drift.** The repo's `request_password_reset` had silently
diverged from production (fixed on 2026-09-01). I checked whether any of the
other six had the same problem by pulling each deployed source and testing the
repo copy for every distinctive marker in it — `dispatch_push`,
`lookup_email_by_phone`, `resolve_report`, `moderate_agency`, `approve_listing`,
`reject_listing`. **All six match.** Only the reset function had drifted.

**Role-read sweep** (`supabase/scripts/probe_role_read_access.sql`), run after
the migration: `anon` 44 relations / **0 failing**, `authenticated` 53 / **0
failing**. It also runs fine through the Supabase MCP `execute_sql` tool, not
just the dashboard SQL Editor — the script header said otherwise and has been
corrected.

**Guest RPC surface**, called as `anon` over HTTP with the real anon key:
`search_listings`, `search_map`, `list_video_reels`, `listing_marker_coordinates`,
`current_user_has_permission`, `market_area_stats`, `market_price_trend`,
`publisher_response_stats`, `publisher_rating_distribution`,
`get_listing_coordinates` — **all 200**.

**Other SECURITY DEFINER functions that take a user id.** Read every one.
`app_vault_secret_for_user` / `app_vault_set_secret_for_user` are gated by
`current_user_is_admin()`; `remove_agency_member` / `set_agency_member_role` by
`is_agency_admin()`. `publisher_response_stats` and
`publisher_rating_distribution` take an arbitrary `p_user_id` with no gate and
are anon-callable — that is correct, they return only aggregate reputation
numbers (counts, a rate, an average) for a public publisher profile.
`get_listing_coordinates` returns NULL for `auth.uid() IS NULL` and otherwise
requires owner-or-`listings.view_all`. No IDOR found.

**Storage.** Six buckets. Every write policy is `authenticated` and gated on
ownership or a permission, each with a `^<uuid>/…` path regex. No anon
INSERT/UPDATE/DELETE anywhere. The `listing-images` bucket accepts only
`image/jpeg`, which matches the uploader exactly — it always watermarks to JPEG
and sets `contentType: 'image/jpeg'`.

**Android notification permission.** `POST_NOTIFICATIONS` is declared, and
`main.dart` requests it post-first-frame for FCM plus
`requestNotificationsPermission()` for local notifications. Android 13+ is
handled.

**Crash-prone Dart patterns.** Swept for the shapes behind the Settings crash:
`!` on map lookups, `.first`/`.last` on possibly-empty lists, `currentUser!`,
unguarded `int.parse`/`DateTime.parse`. The initials helpers in `app_nav_drawer`
and `agent_card` both filter empty parts and guard `parts.isEmpty`;
`InquiryStatus._allowed` covers all five enum values; `PlacementPicker` builds a
controller for every `AdPlacement.values`. Clean.

**Bloc provision.** Swept all 86 page/sheet files for a bloc consumed via
`context.read`/`BlocBuilder`/etc. with no `BlocProvider` anywhere in the tree —
a `ProviderNotFoundException` is the same red screen the Settings crash was.
Clean; the two that looked suspicious resolve fine (`ComparisonPage` is never a
route, it is always pushed wrapped in a `BlocProvider.value`).

---

## Not defects, but the owner should know

- **15 of the 16 publicly visible listings are demo data.** A guest opening the
  app today sees a catalogue that is ~94% fake. `supabase/scripts/
  pre_launch_data_cleanup.sql` exists and has never been run — it is deliberately
  a decision, not a task, so it stays that way.
- **The Reels tab is empty for everyone.** `listing_media` holds **zero** rows of
  kind `video`, so `list_video_reels` returns `[]`. The screen has a proper empty
  state with a friendly hint, so nothing is broken — there is simply no content,
  and Reels is a main bottom-nav tab.
- **`terms_url` is null too**, alongside the already-flagged `privacy_url` and
  all three `support_contact` channels. Both legal screens handle null correctly
  (the section is hidden, not blank).
- **The update manifest advertises build 1**, while this build is `1.1.0+2`. That
  is why no user is being prompted to update — correct today, but it must be
  bumped when the new build ships to Telegram or nobody on build 1 will hear
  about it. There is also a stray duplicate object at
  `app-release/app-release/android/latest.json`; harmless, delete when convenient.
- **Leaked-password protection is off** (Supabase advisor
  `auth_leaked_password_protection`). One toggle in Authentication → Policies; it
  rejects passwords known from public breaches. Cheap, and worth doing before
  real users sign up.
- The six `security_definer_view` advisor ERRORs are the documented deliberate
  pattern for this project (a definer view with a WHERE clause, so an
  INNER JOIN against an RLS table does not silently drop caller-invisible rows).
  Not findings.
