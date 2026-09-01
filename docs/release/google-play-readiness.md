# Google Play readiness checklist — AlNujom

**Prepared:** 2026-09-01 · **App version at the time:** `1.1.0+2` · **Package:** `com.alnujom.app`

Everything Google Play requires before AlNujom can be submitted, with the current
state of each item and the evidence behind it. Telegram is the immediate
distribution channel; Play is the later track.

**Status key**

| Mark | Meaning |
|---|---|
| ✅ **DONE** | Verified in this repository — evidence cited |
| 🟡 **OWNER ACTION** | Nothing technical blocks it; someone has to go and do it |
| 🔧 **DEV WORK** | Requires a code or build change |
| ⛔ **BLOCKED** | Cannot proceed until something outside our control is resolved |
| 🔍 **VERIFY** | Play's rules on this change annually — confirm the current wording before you rely on this line |

---

## 0. The blocker to settle first

### ⛔ Can you even open a Google Play Console account?

Google Play Console developer registration is only available from a list of
supported countries, and Google's services are restricted in Syria under US
sanctions. The earlier release notes already flagged this: *"needs a Google Play
Console (likely sanctions-blocked from Syria)"*
(`docs/release/v1.0.0.md`, pre-2026-09 revision).

**Nothing below matters until this is answered.** Options, roughly in order of
practicality:

1. Check Google's current list of supported developer-account countries directly.
2. Register through a legal entity established in a supported country, if one
   genuinely exists and can accept the legal responsibility. Do not fabricate one
   — Google verifies developer identity with government ID (individuals) or a
   D-U-N-S number (organisations), and a false declaration ends the account.
3. Stay on Telegram, and consider a regional Android store as a second channel.

Everything else in this document is preparation work that is useful regardless —
the privacy policy and account deletion are good practice even for Telegram
distribution.

---

## 1. Developer account

| # | Item | Status | Notes |
|---|---|---|---|
| 1.1 | Play Console account registered | 🟡 OWNER ACTION | One-time $25 fee. Requires a payment method Google accepts. |
| 1.2 | Developer identity verified | 🟡 OWNER ACTION | Government ID for a personal account; D-U-N-S number and organisation documents for a company account. Decide personal vs. organisation **before** registering — changing it later is painful. |
| 1.3 | Developer contact details (email, phone, address) | 🟡 OWNER ACTION | Shown publicly on the store listing for organisation accounts. |
| 1.4 | Closed test before production access | 🔍 VERIFY / 🟡 OWNER ACTION | Google requires new **personal** developer accounts to run a closed test — historically **12 testers opted in for 14 continuous days** — before applying for production access. Organisation accounts have been exempt. Confirm the current rule in the Console; if it applies, budget an extra 2–3 weeks and line up 12 real testers with Google accounts. |

---

## 2. The build artifact

| # | Item | Status | Notes |
|---|---|---|---|
| 2.1 | **Android App Bundle (`.aab`), not APK** | 🔧 DEV WORK | New apps on Play must be uploaded as an **AAB**. This repository builds APKs (`flutter build apk`, documented throughout `docs/release/v1.0.0.md`). The Play build command is `flutter build appbundle --release --obfuscate --split-debug-info=build/symbols --dart-define-from-file=.env.json`. **Note `--split-per-abi` is not used for an AAB** — Play does the splitting itself. Telegram keeps using the APK; both can be built from the same code. |
| 2.2 | Release signing configured, fail-closed | ✅ DONE | `android/app/build.gradle.kts` reads `android/key.properties` and errors out if it is absent — no debug-signed fallback. Verified 2026-06-03 (`apksigner` shows `CN=Hekmat Fanari`). |
| 2.3 | **Play App Signing** enrolment | 🟡 OWNER ACTION | Mandatory for new apps. You upload with your **upload key** (the existing keystore) and Google holds the app signing key. Decide at first upload whether to let Google generate the app signing key or to upload your existing one. **Back up the upload keystore and its passwords in two places first** — see `docs/ops/HANDOVER.md` § 3. |
| 2.4 | `targetSdk` meets the current requirement | ✅ DONE / 🔍 VERIFY | Resolves to **API 36** (Android 16) — `android/app/build.gradle.kts` uses `flutter.targetSdkVersion`, and Flutter 3.44.8 (the toolchain this repo is on, `c751f38`) sets `targetSdkVersion = 36` and `compileSdkVersion = 36` in `FlutterExtension.kt`. That satisfies the API-36 deadline of 31 Aug 2026. Google raises the bar every August — re-check before each submission. |
| 2.5 | `minSdk` | ✅ DONE | `minSdk = 24` (Android 7.0). Reasonable coverage; nothing Play requires here. |
| 2.6 | 16 KB memory page-size support | 🔍 VERIFY | Play requires apps targeting Android 15+ to support 16 KB page sizes. Flutter has shipped 16 KB-aligned native libraries since well before 3.44, so this is very likely already fine — but confirm on the actual `.aab` before upload rather than assuming. Play Console flags it at upload if it is not. |
| 2.7 | AAB size | ✅ DONE (expected) | The arm64 APK is 37.8 MB (verified 2026-07-17); an AAB is comfortably under Play's 150 MB base limit. |
| 2.8 | Deobfuscation / symbol file uploaded | 🟡 OWNER ACTION | If you build with `--obfuscate`, upload `build/symbols` to Play Console (App bundle explorer → Downloads → upload native debug symbols) or crash reports in Play Console are unreadable. |
| 2.9 | Version code strictly increasing | ✅ DONE (process) | Currently `1.1.0+2` → versionCode `2`. Play rejects a re-used or lower version code. Bump `pubspec.yaml` every upload. |

---

## 3. Privacy policy

| # | Item | Status | Notes |
|---|---|---|---|
| 3.1 | Privacy policy written and truthful | ✅ DONE | `docs/legal/privacy-policy.md` (Arabic, authoritative) and `docs/legal/privacy-policy.en.md`. Derived from the actual schema and code, not a template. |
| 3.2 | `TODO(owner)` placeholders filled | 🟡 OWNER ACTION | Eight markers (four in each file): legal entity name, contact email, hosting jurisdiction. **Do not publish with placeholders visible.** |
| 3.3 | Hosted at a public, non-geofenced, non-editable URL | 🟡 OWNER ACTION | Play rejects PDFs, login-gated pages, and editable documents. Hosting options in `docs/legal/README.md`. |
| 3.4 | URL entered in Play Console → App content → Privacy policy | 🟡 OWNER ACTION | Mandatory field; publishing is blocked without it. |
| 3.5 | Same URL in the Store listing and the Data safety form | 🟡 OWNER ACTION | They must match. |
| 3.6 | `privacy_url` set in the app's own settings | 🟡 OWNER ACTION | Admin → Settings → `privacy_url`. Takes effect with no new build (`supabase/docs/app_settings.md`). |

---

## 4. Account deletion — **two separate requirements**

Google requires apps that let users create an account to provide **both** an
in-app deletion path **and** a way to request deletion from the web, without
installing the app. Most developers only do the first and get rejected.

| # | Item | Status | Notes |
|---|---|---|---|
| 4.1 | **In-app account deletion** | 🔧 DEV WORK — **verify before submitting** | At commit `c751f38` there is **no** account-deletion flow anywhere in `lib/` or in the Supabase migrations — an exhaustive search found no `deleteAccount`, no delete-user RPC, and no delete Edge Function. The only account exit is sign-out (`lib/features/profile/presentation/pages/profile_page.dart`). A parallel work stream is adding it; **confirm the button exists and works in the build you upload.** The privacy policy already describes it as available. |
| 4.2 | **Web-accessible deletion request page** | 🟡 OWNER ACTION | A public URL where someone can request account and data deletion without the app. It must state what is deleted, what is retained, and for how long. Can be a section of the same page that hosts the privacy policy. The URL is entered in Play Console → App content → **Data safety** → "Data deletion". |
| 4.3 | Deletion actually removes the data it claims to | 🔧 DEV WORK | Schema-wise the app is mostly ready: nearly every user-owned table uses `ON DELETE CASCADE` on `auth.users`. But three tables use `ON DELETE SET NULL` and keep their rows — `lead_events` (whose `metadata` holds the **IP address** captured at the time), `ad_impressions`, and `inquiries` (which keeps `sender_name` and the encrypted phone). The privacy policy discloses this honestly; make sure the implementation matches what it says. |

---

## 5. Data safety form

Play Console → App content → **Data safety**. This is a sworn declaration —
Google cross-checks it against the app's behaviour, and a mismatch gets the app
removed. What follows maps the form to what AlNujom **actually** does, from the
schema and code.

### 5.1 Global answers

| Question | Answer | Evidence |
|---|---|---|
| Is all data encrypted in transit? | **Yes** | `usesCleartextTraffic="false"` + `network_security_config.xml` pin the app to HTTPS and reject user-installed certificates. |
| Do you provide a way for users to request data deletion? | **Yes** | Item 4.2 — you must supply the URL. |
| Has the app had an independent security review? | **No** | The July 2026 audit was internal (`docs/qa/e2e-2026-07-16/SECURITY_AUDIT.md`). Do not claim otherwise. |
| Is any data **shared** with third parties? | **No** (see note) | Supabase, Firebase/FCM and GlitchTip act as service providers, which Play does not count as "sharing". OpenStreetMap and Overpass receive coordinates for map tiles and nearby-amenity lookups — review that against Play's current definition of sharing before answering. |
| Does the app use an advertising ID? | **No** | No `AD_ID` permission anywhere in `android/`; no ad SDK. In-app banners are served from the app's own `ads` bucket. |
| Is the app designed for children? | **No** | No age gate exists; the policy states the app is for adults. Answer the target-audience questionnaire (§7) as adults-only. |

### 5.2 Data types to declare as COLLECTED

For each: purpose is **App functionality** and **Account management** unless
noted. Nothing is collected for advertising or marketing.

| Play category → data type | Collected? | Required or optional | Evidence |
|---|---|---|---|
| Personal info → **Name** | Yes | Optional | `profiles.full_name`; plus the Vault-encrypted `legal_name` |
| Personal info → **Email address** | Yes | Optional | `profiles.email`. Note the app also derives a technical `<phone>@alnujom.local` address for the login system |
| Personal info → **Phone number** | Yes | **Required** | `profiles.phone` — it is the login identity |
| Personal info → **User IDs** | Yes | Required | `profiles.user_id`, `username` |
| Personal info → **Address** | Yes | Optional | `listings.address_text` — the property address the user types |
| Personal info → **Other info** | Yes | Optional | Vault-encrypted **national ID number**; for agencies, ID document and commercial registration numbers |
| Photos and videos → **Photos** | Yes | Optional | `listing-images` bucket, avatars, agency assets, 360° panoramas |
| Photos and videos → **Videos** | Yes | Optional | `listing-videos` bucket (Reels, listing videos) |
| Files and docs | Yes | Optional | Agency verification documents (PDF/image) in the private `agency-documents` bucket |
| Messages → **Other in-app messages** | Yes | Optional | `messages.body` — chat, plaintext; also viewing notes, reviews, inquiries |
| App activity → **App interactions** | Yes | Required | `lead_events` — phone reveals, WhatsApp taps, inquiries sent, favourites added; `ad_impressions` clicks |
| App activity → **Search history** | Yes | Optional | `saved_searches.filters` |
| App activity → **Other user-generated content** | Yes | Optional | Reviews, CRM notes, saved searches |
| App info and performance → **Crash logs** | Yes | Optional | Sentry/GlitchTip, **only if the build ships a `SENTRY_DSN`** |
| App info and performance → **Diagnostics** | Yes | Optional | Cold-start timing and screen-name breadcrumbs via the same reporter |
| Device or other IDs → **Device or other IDs** | Yes | Required | `notification_tokens.token` (FCM); plus the random per-install ID attached to crash reports |

Purposes worth ticking beyond App functionality:

- **Account management** — phone, name, user IDs.
- **Fraud prevention, security, and compliance** — app interactions and the IP
  address recorded with them.
- **Analytics** — crash logs and diagnostics.

### 5.3 The three judgment calls

**Device location — recommend declaring NOT collected.** The app requests
`ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` and reads GPS
(`lib/features/map/presentation/widgets/center_on_my_location_fab.dart`), but the
position is used only to move the map camera and is **never transmitted, stored
or logged** — the file states that invariant and the code holds to it. Play's
rules allow data processed only on-device and never sent off-device to be
declared as not collected. **However:** users see a real permission prompt, so
the permission must still be justified in the store listing, and the privacy
policy discloses the access (it does — section 2.6). Do **not** write "the app
does not use location" anywhere.

**IP address.** Six server functions record the caller's IP and User-Agent with
each interaction event — including for **signed-out** visitors
(`record_lead_event` is granted to `anon`). Play has no standalone "IP address"
data type; it matters when used to derive location, which this app does not do.
Declare the events under **App interactions** with a **Fraud prevention,
security, and compliance** purpose, and keep the privacy-policy disclosure
(section 2.5) as-is.

**Property location.** `listings.latitude/longitude` describe a *property*, not
the user's device. It is user-entered content, declared above as
**Personal info → Address**. Do not declare it under Play's **Location**
category, which is about the user's own location.

---

## 6. Content rating

| # | Item | Status | Notes |
|---|---|---|---|
| 6.1 | IARC content-rating questionnaire completed | 🟡 OWNER ACTION | Play Console → App content → Content rating. Free, takes ~10 minutes. Answer honestly. |
| 6.2 | Declare user-to-user communication | 🟡 OWNER ACTION | **Answer YES** — the app has in-app chat, inquiries, and reviews. Under-declaring this is a common cause of a wrong rating and a later enforcement action. You will also be asked whether users can share their location with each other and whether content is moderated — the answer to moderation is **yes**: every listing is reviewed by a person before it goes public. |
| 6.3 | Declare user-generated content and a reporting mechanism | ✅ DONE (feature) / 🟡 OWNER ACTION (declare) | The app has a reports queue and moderation actions — the feature exists, you just have to say so on the form. |

---

## 7. App content declarations

Play Console → **App content**. Each one blocks publishing until answered.

| # | Declaration | Expected answer | Notes |
|---|---|---|---|
| 7.1 | Privacy policy | URL | §3 |
| 7.2 | App access | **Provide credentials** | 🟡 **Important.** Most of the app is behind a login, and a seller cannot publish until an admin approves both their account **and** their publisher status. A reviewer who signs up normally sees a locked app and will reject it. Create a dedicated reviewer account, pre-approve it to publisher status, and paste the phone number and password into the "All or some functionality is restricted" form with step-by-step instructions. |
| 7.3 | Ads | **Decide** | The app shows promotional banners from its own `ads` bucket. If any banner promotes a third party (paid placement), answer **yes, the app contains ads**. If they only ever promote your own listings, answer no. Get this right — it changes the store badge. |
| 7.4 | Content rating | Questionnaire | §6 |
| 7.5 | Target audience and content | **18+ / adults** | No age gate exists. Do not select any child age band, or the app enters the Families programme with much stricter rules. |
| 7.6 | News app | **No** | |
| 7.7 | Data safety | Form | §5 |
| 7.8 | Government apps | **No** | |
| 7.9 | Financial features | **No** | The app takes no payments and handles no money. |
| 7.10 | Health apps | **No** | |
| 7.11 | Advertising ID | **Not used** | No `AD_ID` permission declared. Check the *merged* manifest of the built AAB once, in case a dependency adds it. |

---

## 8. Permissions justification

The app declares eight Android permissions
(`android/app/src/main/AndroidManifest.xml`). Play scrutinises some of these.

| Permission | Why the app needs it | Play concern |
|---|---|---|
| `INTERNET` | Everything | None |
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | The "my location" button centres the map | ✅ Foreground only. **No** `ACCESS_BACKGROUND_LOCATION` is declared — background location needs a separate written declaration and video demo, and this app avoids that entirely. |
| `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO` | Picking listing photos and videos from the gallery | 🔧 **Look at this before submitting.** Google's photo and video permissions policy requires apps declaring these to have an approved core use case and to complete a declaration form; Google pushes apps toward the Android **Photo Picker**, which needs no permission at all. The app uses `image_picker`, which on modern Android can use the Photo Picker. If it does, these two lines can likely be **removed from the manifest**, which sidesteps the declaration completely. Have a developer check which path `image_picker` actually takes on API 33+. |
| `READ_EXTERNAL_STORAGE` (`maxSdkVersion=32`) | Gallery access on Android 12 and older | Correctly capped; no concern |
| `POST_NOTIFICATIONS` | The Android 13+ notification prompt | None |
| `RECEIVE_BOOT_COMPLETED` | Re-registers scheduled CRM reminders after a reboot | None |

No `CAMERA`, no `READ_CONTACTS`, no `QUERY_ALL_PACKAGES`, no
`SCHEDULE_EXACT_ALARM`, no `MANAGE_EXTERNAL_STORAGE` — all four of which would
have triggered extra scrutiny. This manifest is clean.

---

## 9. Store listing assets

All 🟡 OWNER ACTION. Prepare in **Arabic** (the default listing language, since
the app is Arabic-first) and add English as a second language.

| Asset | Requirement |
|---|---|
| App name | ≤ 30 characters |
| Short description | ≤ 80 characters |
| Full description | ≤ 4,000 characters |
| App icon | 512 × 512 PNG, 32-bit with alpha |
| Feature graphic | 1024 × 500 |
| Phone screenshots | 2–8, at least 2 required; 16:9 or 9:16 |
| Tablet / large-screen screenshots | 🔍 VERIFY — Play increasingly requires or heavily favours these for discovery. Prepare them even if not strictly blocking. |
| Category | Real estate fits **House & Home** or **Lifestyle** |
| Contact email | Public on the listing |

The branding assets already exist — the Phase 033 "orbit" identity in
`assets/branding/` (`app_icon_orbit.png`, `icon_fg_orbit.png`,
`splash_orbit.png`) — so the icon can be derived from what is already shipping.

---

## 10. Policy risks specific to this app

Worth thinking about before submission rather than after a rejection.

| Risk | Why it matters here | What to do |
|---|---|---|
| **Unverified phone numbers** | There is no SMS verification, so anyone can register a number they do not own (documented as an accepted constraint in `SECURITY_AUDIT.md`). Play cares about impersonation and fraud in marketplace apps. | Keep the human approval step for sellers, keep the reports queue staffed, and mention moderation in the listing description. |
| **User-generated content at scale** | Photos, videos, chat and reviews from strangers. Play requires a moderation policy, a reporting mechanism, and the ability to remove content and ban users. | The app already has all three. Make sure the store listing and (ideally) a terms-of-service page say so. |
| **Real-estate location privacy** | Publishing exact home addresses of private individuals is a genuine safety issue. | The approximate-location default (~500 m offset) is a real mitigation and worth stating in the listing. |
| **Chat messages are plaintext** | Not a Play violation, but do not imply encryption anywhere in the listing or the policy. | The privacy policy states this plainly. Keep it that way. |
| **The app updates itself from Telegram** | The in-app update prompt sends users to a Telegram post to download an APK. **Play forbids an app distributing or prompting the installation of an APK from outside Play.** | 🔧 **DEV WORK before Play submission.** The Play build must disable the Telegram update prompt (Play handles updates itself). This is not optional — it is a common cause of removal. A build flag distinguishing the Play build from the Telegram build is the usual answer. |

---

## 11. Summary of what is actually blocking

| Blocking item | Type |
|---|---|
| Play Console account availability from Syria | ⛔ Settle first |
| In-app account deletion must exist in the uploaded build | 🔧 DEV WORK |
| Web-accessible deletion request URL | 🟡 OWNER ACTION |
| Privacy policy hosted, placeholders filled | 🟡 OWNER ACTION |
| Build as `.aab`, not `.apk` | 🔧 DEV WORK |
| Disable the Telegram in-app update prompt in the Play build | 🔧 DEV WORK |
| Reviewer test credentials with pre-approved publisher status | 🟡 OWNER ACTION |
| Data safety form + content rating + all App content declarations | 🟡 OWNER ACTION |
| Store listing assets in Arabic and English | 🟡 OWNER ACTION |
| Photo/video permission declaration (or remove the permissions) | 🔧 DEV WORK |

**Already in good shape:** release signing (fail-closed, verified), `targetSdk`
36, a clean permission manifest with no high-scrutiny permissions, HTTPS-only
networking, encrypted session storage, row-level security on every table, a
working moderation and reporting system, and a privacy policy that is actually
true.

---

*Companion documents: `docs/legal/README.md` (hosting the policy),
`docs/release/v1.0.0.md` (what is verified and what is open),
`docs/ops/HANDOVER.md` (running the app day to day).*
