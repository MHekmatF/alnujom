# ADR 0001: Secrets and Per-User PII Storage

**Status**: Accepted
**Date**: 2026-04-28
**Deciders**: project lead
**Supersedes**: —
**Superseded by**: —
**Relates to**: Constitution Principles II (Source-Controlled Backend), III (Security-First Supabase), VIII (Approval Workflow & Publisher Identity), IX (Future Backend Portability)

## Context

AlNujom v1 runs on Supabase. As phases land we will need to store:

1. **Backend-side secrets** consumed by Edge Functions or SQL functions — e.g., the FCM service-account JSON used by the push-notification fan-out (Phase 22), and any future third-party API keys (Phase 21 ad networks, possible payment providers, SMS gateways).
2. **Per-user private identity fields** that Constitution Principle VIII mandates be admin-only by default — full legal name, national ID number, private contact methods (Phase 5 and onward).
3. **Private contact data on inbound inquiries** — the inquirer's phone number when they contact a publisher (Phase 16).
4. **Verification documents / ID numbers** for agencies (Phase 19).

Storing any of the above as plaintext columns in Postgres has two problems: (a) a leaked DB dump exposes them even if RLS prevents in-band access, and (b) accidental SELECT-* by a future admin tool or an audit query can expose them in logs.

The two viable options:

- **Option A — Plaintext columns with strict RLS only.** Cheap, works today, but offers no defense-in-depth against backup theft, log exposure, or misconfigured admin tooling. Constitution Principle III is satisfied "in spirit" but the bar for a real-estate marketplace handling national-ID-level data is higher.
- **Option B — Supabase Vault** (`pgsodium`-backed encrypted secret/PII store inside Postgres). Encrypts at rest with a managed root key; secrets are decrypted on-demand through a privileged view; not visible in normal SELECT or in pg_dump output. Adds a one-time backend-setup cost and a small per-row encrypt/decrypt overhead.

## Decision

**Use Supabase Vault as the canonical store for**:

1. All backend-side secrets consumed by Edge Functions or SQL functions.
2. Per-user private identity fields whose Constitution Principle VIII classification is admin-only by default — specifically: full legal name, national ID number, private contact methods.
3. Inquirer-side phone numbers attached to anonymous or semi-anonymous inquiries (Phase 16).
4. Agency verification IDs and other private agency documents (Phase 19).

Plaintext columns gated only by RLS remain acceptable for fields whose classification is *not* "admin-only private identity" — e.g., display name, public listing data, opt-in public contact methods.

The Supabase **anon key** shipped to the Flutter client is **not** a Vault candidate; it is intentionally public-ish, gated by RLS, and lives in env-injected build configuration.

The **device-side** equivalent (session tokens, refresh tokens, locale/theme preferences, etc.) uses `flutter_secure_storage` (Android Keystore-backed) — a separate concern at a different layer.

## Phase-by-phase implications

| Phase | Item | Vault use |
|---|---|---|
| 1 | Project foundation | **None.** No secrets or PII stored yet. |
| 4 | Supabase base schema + RLS scaffolding | Enable `pgsodium` extension + Vault scaffolding migration as a forward-prep step (no secrets stored yet). |
| 5 | Auth & profile | `profiles.legal_name`, `profiles.national_id`, `profiles.private_contact_methods` stored via Vault. |
| 16 | Contact, inquiries & lead events | `inquiries.inquirer_phone` stored via Vault. |
| 19 | Agencies | `agency_verification_requests.id_document_number` and any other private ID fields stored via Vault. |
| 21 | Ads & banners | Any third-party ad-network API keys stored as Vault secrets. |
| 22 | Push notifications | FCM service-account JSON stored as a single Vault secret read by the fan-out Edge Function. |

## Consequences

**Positive**:

- Defense-in-depth: a leaked DB dump or misconfigured backup still does not expose national IDs, FCM keys, etc.
- One uniform pattern across phases — fewer ad-hoc encryption schemes.
- Compatible with Constitution Principle II: Vault enablement and per-secret definitions are migration files in `supabase/migrations/`, source-controlled.
- Compatible with Constitution Principle IX (Future Backend Portability): the Flutter app never sees Vault directly — repositories return decrypted domain entities for authorized callers, encrypted columns for unauthorized ones; swapping Supabase for a custom backend means re-implementing the same encrypt/decrypt pattern in the new backend's data layer, not the domain layer.

**Negative / costs**:

- Phase 4 grows by one migration (enable extension + Vault scaffolding).
- Phases 5, 16, 19, 21, 22 each add a small "store via Vault" step that would not exist in the plaintext approach.
- Per-row encrypt/decrypt is not free; not material for the volumes AlNujom expects in v1, but worth measuring at Phase 24's release-polish performance pass.
- Vault tooling is Postgres-specific; if v2 swaps to a non-Postgres backend, the encryption pattern has to be re-done — but the Flutter side does not change.

## Alternatives considered

- **Plaintext columns + RLS only** — rejected; Constitution Principle III sets a higher bar for sensitive marketplace data, and a leaked backup is a realistic threat.
- **App-side encryption** (Flutter encrypts before insert, decrypts on read) — rejected; the encryption key would have to ship with the client, and admin tooling would need a parallel decryption path. Vault keeps the key server-side where it belongs.
- **A separate secrets manager (HashiCorp Vault, AWS Secrets Manager)** — rejected for v1; adds a second piece of infrastructure to run, monitor, and access from Edge Functions. Supabase Vault is built into the Postgres we already run.

## Verification

- Phase 4's spec MUST include a deliverable enabling `pgsodium` and Vault, with a migration file under `supabase/migrations/`.
- Phase 5, 16, 19, 21, 22 specs MUST reference this ADR in their Assumptions or a "Cross-cutting decisions" section, and MUST list which fields/secrets are Vault-stored.
- A quick `pg_dump | grep -i national_id | grep -v "encrypted"` smoke check in Phase 24 release polish confirms no plaintext leakage.

## Notes

- This ADR is in scope for **constitutional reaffirmation, not amendment**: it operationalizes Principle III without adding a new principle. If at any point a future spec needs to deviate (e.g., a field is so frequently read by hot paths that Vault overhead matters), document the deviation in that phase's spec and update this ADR's "Superseded by" header.
