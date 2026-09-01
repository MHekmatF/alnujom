# Legal documents — what they are and what you must do with them

This folder holds the app's privacy policy:

| File | What it is |
|---|---|
| [`privacy-policy.md`](privacy-policy.md) | **Arabic — the authoritative version.** This is the one users read. |
| [`privacy-policy.en.md`](privacy-policy.en.md) | English translation of the same document. |

They were written by reading the app's actual database schema and code, not from a
template — so what they describe is what the app really does. If the app changes
what it collects, **these files must change too**.

---

## Before you do anything else: three blanks to fill

Search both files for `TODO(owner)`. There are **four markers in each file —
eight in total across the two**, covering three facts only you know:

1. **The legal entity name** (and country of registration) — who legally operates
   the app. Appears in section 1 and section 14 of each file.
2. **A contact email address** for privacy questions and account-deletion
   requests. Appears in section 14 of each file. Google Play requires this to be
   a real address that someone actually reads — they do test it.
3. **The hosting jurisdiction and governing law.** The files already state, from
   the project record, that Supabase hosts the project in the `us-east-2` (US
   East) region — confirm that is still true and add which country's law applies.
   Appears in section 8 of each file.

**Do not publish the policy with `TODO(owner)` still in it.** A policy with
placeholder text visible is worse than none — it tells a reviewer the document
was never finished.

---

## One thing to verify before publishing

Section 9 of both files says a user can delete their account from
**Profile → Settings → Delete account**. **Open the app and confirm that button
exists and works** before you host the policy. A privacy policy that promises a
deletion path the app does not have is a false statement to your users and a
failed review with Google.

If the button is not there yet, either wait for the build that adds it, or edit
section 9 down to the email-request route only until it ships.

---

## You must host these at a public web address

A file in this repository is not a privacy policy. Google Play requires a **live
URL**, and it has specific rules. The URL must be:

- **Publicly accessible** — no login, no password, no "request access".
- **Not geo-blocked** — a Google reviewer, likely outside Syria, must be able to
  open it.
- **A real web page**, not a PDF download and not a file-sharing link.
- **Not user-editable** — a public Google Doc that anyone can edit will be
  rejected.
- **Stable** — the same URL has to keep working. If it dies later, the app can be
  removed from the store.

A Telegram post does **not** satisfy this. Neither does a link to this GitHub
file, which requires a GitHub account to render reliably and is not a
presentation-quality page.

### Easy ways to host it

| Option | Cost | Notes |
|---|---|---|
| **GitHub Pages** | Free | Turn on Pages for this repository, put the Arabic policy at `index.html` (or as Markdown with a Jekyll theme). Gives you a stable `https://mhekmatf.github.io/alnujom/` style URL. Simplest option if you already own the repository. |
| **A page on your own domain** | Cost of the domain | Best long-term. `https://alnujom.app/privacy` reads as trustworthy and you control it forever. |
| **Notion / Google Sites, published** | Free | Works, but make sure the published page is view-only and not editable by visitors. |

### Publish both languages

Google Play accepts **one** privacy-policy URL. Because the app is Arabic-first,
make the **Arabic** page the URL you submit, and put a clear "English" link at the
top of it pointing to the English page. Both pages must be publicly reachable.

---

## Where the URL goes — four places

Once the policy is live, put the URL in all four:

1. **Google Play Console → your app → Policy → App content → Privacy policy.**
   This is the mandatory field; the app cannot be published without it. See
   [`docs/release/google-play-readiness.md`](../release/google-play-readiness.md).
2. **Google Play Console → Store listing.** The store page shows a privacy-policy
   link to users.
3. **Google Play Console → App content → Data safety.** The Data Safety form asks
   for the privacy-policy URL again; it must match.
4. **Inside the app.** Sign in as an administrator → **Admin → Settings** → set
   the **`privacy_url`** setting to the same URL. The About screen then links to
   it. This takes effect immediately — no new app build needed. While you are
   there, set `terms_url` too if you have terms of service.

---

## Keep it accurate

The policy makes specific factual claims that must stay true. Re-check this
folder whenever the app changes in any of these ways:

- A new Android permission is added, or one is removed.
- A new kind of data starts being collected or stored.
- A new third-party service is added (a new analytics tool, a different map
  provider, a payment processor).
- Data retention changes — for example if a cleanup job is ever added, section 8
  should stop saying there is no automatic deletion.
- The account-deletion behaviour changes.
- Crash reporting is turned on or off in the shipped build.

When you change the policy, update the **"Last updated"** date at the top of both
files, re-publish the hosted pages, and — for a material change — announce it in
the app.

---

## Still missing (not written here)

- **Terms of Service.** Not required by Google Play, but strongly advisable for a
  marketplace where strangers transact over property. It is what lets you remove
  a listing, ban an abusive user, and disclaim responsibility for what sellers
  claim. Worth a lawyer's hour.
- **A web page where someone can request account deletion without installing the
  app.** Google Play requires this **in addition** to the in-app deletion button.
  Details in [`docs/release/google-play-readiness.md`](../release/google-play-readiness.md).
