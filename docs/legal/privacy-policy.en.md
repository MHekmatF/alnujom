# Privacy Policy — AlNujom

**Last updated:** 2026-09-03
**Applies to:** the **AlNujom** Android app (`com.alnujom.app`) — a real-estate marketplace for Syria.
**Arabic version:** [privacy-policy.md](privacy-policy.md). The Arabic version is authoritative if the two differ.

---

## 1. Who we are

**Al Nujoom for Real Estate Marketing** (النجوم للتسويق العقاري) — a real-estate office in the Syrian Arab Republic, which owns and operates the AlNujom app.

We operate AlNujom, an app that lets property owners and real-estate agencies list properties, and lets buyers browse listings and contact the people behind them.

This policy explains, in plain language, what the app actually collects, why, who can see it, and how you delete it.

---

## 2. What we collect

### 2.1 Information you give us when you create an account

| Data | Required? | Why |
|---|---|---|
| **Phone number** | Yes | It is your identity in the app and how you sign in. Internally it is used to build a technical email address of the form `<your-number>@alnujom.local` that cannot receive mail and exists only so the login system works. |
| **Password** | Yes | Stored as a one-way bcrypt hash. We never see it and cannot recover it. |
| Full name | Optional | Shown with your listings and messages, depending on your settings. |
| Username | Optional | An in-app identifier. |
| Real email address | Optional | Used only for password recovery, if you add one. |
| Profile photo | Optional | Shown on your profile. |

### 2.2 Extra sensitive information (optional, and encrypted)

If you choose to fill these in from the "private information" screen, we store them **encrypted** in the `Supabase Vault`:

- **Legal name**
- **National ID number**
- **Private contact methods**: WhatsApp, Telegram, Signal, private email, secondary phone

These fields are **not stored as plain text in the database**. Only **you** or an **administrator** with the relevant permission can decrypt them. They are never shown to other users and never appear in search.

**For agencies** we additionally collect — encrypted the same way — the **ID document number** and the **commercial registration number**, plus **verification documents** uploaded to a **private, non-public** storage area reachable only by authorised administrators, for the purpose of verifying the agency.

> The app has no SMS identity verification. Phone numbers are **not automatically verified**; they are checked manually where it matters.

### 2.3 Information about the properties you list

- The property's **address as text**, plus city and area.
- **Map coordinates** (latitude and longitude).
- **Photos** (up to 10 per listing), **videos** (up to 2), and **360° photos** if you upload them.
- Property details: price, size, deed type, finish condition, amenities, description.

**About location precision:** when you publish a listing you choose how precisely to show its location — **hidden**, **approximate**, **exact**, or **admins only**. The default is **approximate**: the map pin is shifted by a fixed offset of roughly **500 metres** (capped at about 2.2 km from the area centre), so a visitor sees the neighbourhood but not your front door. The offset is fixed per listing, so reopening the listing cannot reveal the true point.

Listing photos and videos are kept in **public** storage: anyone with the direct link can open the file. Do not put anything in a listing photo you would not want seen — documents, personal papers, photographs of people.

### 2.4 Content you write inside the app

- **Chat messages** between you and the other party (up to 2,000 characters each).
- **Viewing requests** and their notes.
- **Reviews and comments** you write about another user.
- **Inquiries** you send through the contact form: your name, your message, and your **phone number, encrypted**.
- **Saved searches**: the search criteria you chose to save for alerts.
- **CRM notes** a publisher keeps about people interested in their properties: a display name, a follow-up stage, free-text notes, and reminders.

**Chat messages are stored as plain text in the database.** The app does **not** use end-to-end encryption. Database access rules stop any other user from reading your conversation, but someone with administrative access to the database itself could technically read it. Do not send anything through chat that you are not comfortable with on that basis.

### 2.5 Information collected automatically

- **Notification token (FCM token)**: an identifier for the app installed on your device, stored so we can send you a notification. It is removed when you sign out, and tokens Google reports as invalid are pruned.
- **Interaction events**: we record specific actions — **phone number revealed**, **WhatsApp tapped**, **inquiry sent**, **added to favourites** — linked to the listing, and to your account if you are signed in.
- **With each of those events we record your IP address and your app/device identifier (User-Agent).** The same happens when you send an inquiry, favourite a property, report a listing, or tap a promotional banner — **even if you are not signed in**.
- **Promotional banner statistics**: clicks on banners.
- **Audit log**: every administrative action (approval, rejection, permission change, settings change) is recorded with who did it and when.

A publisher sees only **aggregate counts** for their listings (how many times a number was revealed, for example). **IP address and device identifier are not shown to publishers** — only administrators can reach them.

### 2.6 Your device's location

The app requests **precise location** permission (`ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`) for exactly one purpose: the **"my location"** button on the map, which moves the map camera to where you are.

**Your device location is never sent to our servers, never stored, and never logged.** It is used on the device, in that moment, only. You can decline the permission; that button simply will not work and the rest of the app is unaffected.

### 2.7 What we do not collect

- **We do not use the camera** — the app never requests camera permission; photos come from your device gallery.
- **We do not read your contacts**, messages, or files beyond what you pick to upload.
- **We do not track your location in the background.**
- **We do not sell your data, and we do not run third-party ad networks.** Banners inside the app are managed directly by the app's operators.

---

## 3. Why we collect it

| Purpose | What we use |
|---|---|
| Running your account and signing you in | Phone number, password |
| Showing and searching listings | Property details, photos, location |
| Connecting you with a property owner | Name, the contact methods you chose to show, chat |
| Reviewing accounts and listings before they go live | Account details, agency verification documents |
| Preventing fraud, abuse and spam | Event log, IP address, audit log |
| Telling you about things you care about | Notification token, saved searches |
| Fixing crashes | Crash reports (section 7) |

---

## 4. Who can see your information

| Data | Who sees it |
|---|---|
| Your listing once approved (photos, description, price, location at your chosen precision) | **Everyone**, including signed-out visitors |
| Your name on a listing | Depends on that listing's "show publisher name" setting |
| Your phone number on a listing | Anyone who taps "reveal number" (and we log that event) |
| Your full profile | **You only**, plus administrators |
| Legal name, national ID, private contact methods | **You only**, plus administrators — encrypted |
| Your chats | **The two people in the conversation only** |
| Your phone number in an inquiry you sent | The listing's publisher, you, and an authorised administrator — encrypted, with restricted decryption |
| Agency verification documents | **Authorised administrators only** (private storage) |
| Your IP address and device identifier | **Administrators only** |
| A listing not yet approved | **You and administrators only** |

These are not merely hidden in the interface: every database table is protected by server-side **Row Level Security** policies, so modifying the app is not enough to bypass them.

---

## 5. Third-party services the app talks to

| Service | What reaches it | Why |
|---|---|---|
| **Supabase** | All app data (database, files, accounts) | Our hosting and server provider |
| **Google Firebase (FCM)** | Your device's notification token, and a generic notification body containing identifiers, not personal details | Delivering notifications to your phone |
| **OpenStreetMap** | The coordinates of the map area you are viewing, plus your IP address as a consequence of connecting | Map tiles |
| **Overpass API** | The coordinates of the **property** you open (within a 1.5 km radius) | Showing nearby amenities (schools, pharmacies, …) |
| **GlitchTip** (Sentry-compatible) | Crash reports (section 7) | Fixing bugs |
| **WhatsApp / Telegram / your phone dialler** | Whatever you choose to send | Tapping a contact button leaves the app; that app's own policy then applies |

All network traffic is restricted to **HTTPS**; the app refuses unencrypted connections and rejects manually installed device certificates.

---

## 6. Encrypted data

- **Legal name, national ID, private contact methods, agency ID and commercial registration numbers** — encrypted in **Supabase Vault**, per user, readable only through server functions that verify who is asking.
- **The phone number of someone sending an inquiry** — encrypted in the database (pgsodium), decryptable only by the listing's publisher, the sender themselves, or an authorised administrator.
- **Your login session on your device** — stored in the **encrypted Android Keystore**, not in plain text. Someone with file-level access to the device cannot lift your session.

---

## 7. Crash reports

When the app hits an error, a technical report may be sent to **GlitchTip** (our own Sentry-protocol-compatible server) so a developer can find the cause.

- `sendDefaultPii = false` — the library does **not** send your email, IP address, or identity automatically.
- `tracesSampleRate = 0` — we collect no performance or tracing data.
- Every report passes through a **mandatory scrubber** that strips passwords, tokens (JWTs), email addresses, and phone-like digit sequences from the error text and all its fields. If scrubbing fails for any reason, **the report is dropped entirely** rather than sent.
- The only identifier attached is a **random per-installation number**, not your account ID.
- Reports carry technical breadcrumbs including the **names of screens you opened** and generic events (such as cold-start time), to give the crash context.

Crash reporting **only works if it was enabled when the app build was made**. If the build ships without a reporting address, nothing leaves your device at all.

---

## 8. Where data is stored, and for how long

**Where:** on **Supabase** infrastructure. Per the project record, the project is provisioned in the `us-east-2` region (US East), meaning your data is processed and stored outside Syria.

**The party responsible for your data** is Al Nujoom for Real Estate Marketing, in the Syrian Arab Republic. This policy, and anything arising from it, is governed by Syrian law — even though the data itself is stored on Supabase infrastructure in the United States, as described above.

**How long:**

- **Your account data and content** (profile, listings, photos, chats, favourites, saved searches) is kept for as long as your account exists.
- **Deleted listings** are not immediately erased from the database; they are marked "deleted" and disappear for everyone.
- **Expired listings** disappear for visitors but remain stored.
- **Technical activity logs** (interaction events with IP address, audit log) are kept for security and abuse prevention. **There is currently no scheduled automatic deletion of those logs** — we state that plainly rather than claim otherwise.

---

## 9. Deleting your account

**From inside the app:** open **Settings → Delete my account**, or use **Delete my account** at the bottom of your **Profile**. You are shown a page explaining what will be deleted and what may remain, then you confirm twice. This is the primary route and does not require contacting us.

**What is deleted:** your account and profile, your Vault-encrypted data (legal name, national ID, private contact methods), your listings, your photos and videos, your chats, favourites, saved searches, preferences, notification tokens, viewing requests, reviews, and the CRM records tied to you.

**What may remain:**

- **Technical activity logs after being unlinked from your account** (interaction events and banner clicks). They are no longer tied to you, but their technical fields may include the IP address recorded at the time of the event.
- **Inquiries you sent to publishers** remain with that publisher after being unlinked from your account, along with the name and encrypted phone number you entered when sending — because they are also a record of contact belonging to the other party.
- **The administrative audit log**, if you were an administrator, because it is an accountability record.
- Backups may retain your data for a short period until they are rotated out.

**Alternative — if you cannot reach the app** (forgotten password, app removed from your device): write to the address in section 14 from the phone number registered on the account and explicitly ask for deletion. We verify that you own the account and then carry out the same deletion manually.

**Deletion is permanent and cannot be undone.**

---

## 10. Your rights

- **Access** the information we hold about you.
- **Correction** — most of your data is editable directly from the profile screen.
- **Deletion** — section 9.
- **Object** to a particular use of your data.
- **Turn off notifications** from the app's settings or from Android's settings.
- **Withdraw the location permission** in Android settings at any time.

To exercise any of these, write to the address in section 14. We respond within a reasonable time.

---

## 11. Security

- Every table is protected by server-side **Row Level Security** policies.
- **HTTPS only**, with manually installed certificates rejected.
- **The login session is encrypted** in Android's secure store.
- Sensitive data is encrypted in **Vault** (section 6).
- **Android app backup is disabled**, so your data is not automatically copied to a Google account.
- Publishing is reviewed: no listing reaches the public before an administrator approves it.

No system is perfectly secure. We make reasonable efforts, and we cannot guarantee absolute security.

---

## 12. Children

The app is intended for adults (18 and over) and we do not knowingly collect data from anyone younger. **The app has no age verification.** If you become aware that a minor has created an account, contact us and we will delete it.

---

## 13. Changes to this policy

We may update this policy. The last-updated date is at the top of the page, and the version published at the public URL is always the authoritative one. We will announce material changes inside the app.

---

## 14. How to contact us

**Email:** m.hekmatfanari@gmail.com

**Legal entity:** Al Nujoom for Real Estate Marketing — Syrian Arab Republic.

For privacy questions or complaints, or to request deletion of your account when you cannot reach the app, write to the address above.
