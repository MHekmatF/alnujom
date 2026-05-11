# AlNujom — Project Runbook

Records manual, one-time configuration applied to the remote Supabase project that cannot be captured in migrations or source files.

---

## Phase 5 Dashboard Configuration (spec/005-auth-profile)

These three settings were applied to the Supabase dashboard for project **AlNujom** (`hczsgceagommznjaohyk`, region `us-east-2`) as part of Phase 5 Setup (tasks T002, T003, T004).

### T002 — Password Minimum Length

| Field | Value |
|---|---|
| Dashboard path | **Authentication → Settings → Password → Minimum length** |
| Required value | **8** |
| Configured on | 2026-05-10 |

Mirrors `auth.minimum_password_length = 8` in `supabase/config.toml`. Source: FR-001, R-08 (8 chars, no complexity requirement).

### T003 — Email Confirmation Disabled

| Field | Value |
|---|---|
| Dashboard path | **Authentication → Providers → Email → Confirm email** |
| Required value | **Unchecked (disabled)** |
| Configured on | 2026-05-10 |

The project registers users via synthetic email addresses (`<E.164>@alnujom.local`). These mailboxes cannot receive real mail, so email confirmation is inherently broken and must be disabled. Source: `spec.md` Assumptions §3.

### T004 — Site URL and Redirect URLs (Password Reset)

| Field | Value |
|---|---|
| Dashboard path | **Authentication → URL Configuration → Site URL / Redirect URLs** |
| Required value | Include the app's password-reset deep-link (see below) |
| Configured on | 2026-05-10 |

The `request_password_reset` Edge Function calls `auth.admin.generateLink({ type: 'recovery', email })` without an explicit `redirectTo`; Supabase falls back to the project-configured Site URL. The Flutter deep-link URI scheme for the reset-password callback is finalised in Phase 7.

**Placeholder configured**: `https://hczsgceagommznjaohyk.supabase.co` (Supabase default).  
**Phase 7 action**: update Site URL and Redirect URLs to include `alnujom://auth/reset-password` (or the scheme confirmed during Phase 7 release-polish) and update this entry.

---

## Phase 4 Baseline (spec/004-supabase-foundation)

No manual dashboard changes were required in Phase 4; all configuration is in migrations.
