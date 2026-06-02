# Phase 0 — Research & Locked Decisions: App Settings (Phase 23)

All Technical-Context unknowns resolved. Each decision is locked with rationale + rejected alternatives (Principle XII). Decisions continue the project-wide series after Phase 22's R-181..R-196.

---

### R-197 — Per-key public/sensitive read via an `is_public` column + a single per-key SELECT policy

**Decision**: `app_settings` carries an `is_public BOOLEAN NOT NULL DEFAULT true` column. The one SELECT RLS policy is `USING (is_public OR current_user_has_permission('settings.manage'))` — so any client (incl. anonymous) reads public keys, and sensitive keys are visible only to `settings.manage` holders. The table is NOT table-wide public-read.
**Rationale**: The §6.4 matrix says "Public read for non-sensitive keys; admins for all." A per-key boolean encodes the distinction in data (Principle VII data-driven), so adding a future sensitive key is a seed change, not a policy migration. All v1 catalog keys are `is_public = true` (the client needs them at load).
**Alternatives rejected**: (a) A hardcoded key allowlist inside the policy — every new sensitive key would need a policy migration; not data-driven. (b) Two tables (public vs private settings) — needless duplication for a v1 catalog that seeds no sensitive keys.

### R-198 — No "supported currencies" setting; Phase 9 `currencies.is_active` stays the source of truth

**Decision**: The plan's eight-item list is trimmed to **seven** — `app_settings` does NOT hold a `supported_currencies` key. Which currencies the app supports is governed entirely by the Phase 9 `currencies.is_active` flag; `app_settings` stores only the **default** currency. (User-resolved 2026-06-02 — spec Clarifications.)
**Rationale**: Phase 9 already owns currency existence/activation; a second list in `app_settings` would be a competing source of truth requiring constant reconciliation.
**Alternatives rejected**: (a) A curated allow-list in settings layered over Phase 9 — two sources of truth. (b) Settings supersede `currencies.is_active` — a migration/behavior change to a shipped phase for no functional gain.

### R-199 — Writes via a `set_app_setting` SECURITY DEFINER RPC; all direct client writes REVOKEd

**Decision**: `REVOKE INSERT, UPDATE, DELETE ON app_settings FROM anon, authenticated`. The only mutation path is `set_app_setting(p_key TEXT, p_value JSONB)` SECURITY DEFINER, which re-checks `current_user_has_permission('settings.manage')` and `RAISE`s on denial before UPDATEing the (seeded) row, stamping `updated_by = auth.uid()`, `updated_at = now()`.
**Rationale**: Principle III ("sensitive mutations MUST go through Edge Functions or RPCs that re-check permissions server-side") and the established Phase 18/19/21/22 posture (REVOKE client writes; RPC-only). Settings changes are sensitive admin actions, so the definer is the permission boundary — checks-at-both-ends with the FA UI gate.
**Alternatives rejected**: (a) Direct client `UPDATE` gated by an RLS `WITH CHECK current_user_has_permission('settings.manage')` — requires `GRANT UPDATE … TO authenticated` (a wider write surface) and diverges from the project's REVOKE+RPC convention. (b) An Edge Function — unnecessary; there is no multi-step atomicity or external call, so a PL/pgSQL definer is simpler and source-controlled.

### R-200 — Audit via an AFTER-UPDATE trigger calling the existing `log_audit()`

**Decision**: `CREATE TRIGGER trg_app_settings_audit AFTER UPDATE ON app_settings FOR EACH ROW EXECUTE FUNCTION log_audit('settings.updated', 'value', 'key')` — the Phase 4 trigger function (3 trigger-args: action, watched-columns, pk-column). This is the §9.4 "App settings changes (Phase 23)" audited action. No new audit infrastructure.
**Rationale**: `log_audit()` is the project's trigger-based audit idiom (matches the Phase 5 `profile.status_changed` usage the Explore found); the actor `auth.uid()` is visible through the definer write. The trigger fires on the definer's UPDATE, so every successful `set_app_setting` is audited automatically.
**Alternatives rejected**: A manual `INSERT INTO audit_logs …` inside the RPC — duplicates what the trigger does and risks drift from the canonical audit shape.

### R-201 — Maintenance/public-settings consumption is fetch-on-app-load + foreground-resume (NOT Realtime); fetch-failure is fail-open-for-availability, fail-safe-for-maintenance

**Decision**: The client reads public settings once at app-load and re-reads on foreground resume (an `AppLifecycleState.resumed` hook), holding the snapshot in `AppSettingsCubit`. Settings are **not** delivered via Realtime. If the read fails (offline/backend error), the cubit serves **safe built-in defaults** and treats maintenance as **OFF** (a failed fetch is never maintenance-on).
**Rationale**: Reconciles the plan's "shows the maintenance screen on all clients within 1 minute (next app foreground)" — the "1 minute" is the foreground re-fetch latency budget, not a tight poll. Keeps Phase 22's locked Realtime scope (admin counters + `user_roles`) unchanged. Fail-open avoids bricking the app on a settings outage; fail-safe-for-maintenance avoids locking everyone out on a transient error.
**Alternatives rejected**: (a) A Realtime subscription on `app_settings` — outside Phase 22's locked Realtime scope, more moving parts for a low-frequency change, and the plan explicitly says "next app foreground." (b) A periodic foreground poll — unnecessary; the plan ties propagation to foreground transitions. (c) Treating an unknown maintenance state as ON — would brick the app on any backend hiccup.

### R-202 — Maintenance bypass = `settings.manage` holders only

**Decision**: When maintenance is ON, the router gate sends every client to `MaintenanceScreen` EXCEPT users for whom `getIt<PermissionChecker>().has(PermissionKeys.settingsManage)` is true. Other admins/moderators and anonymous visitors see the screen. (User-resolved 2026-06-02 — spec FR-010, resolves the plan's §16 open question.)
**Rationale**: The operator who can toggle maintenance (the `settings.manage` holder) must reach the editor to turn it off — minimal bypass prevents a total operator lockout while keeping the blackout near-total.
**Alternatives rejected**: (a) All admin roles bypass — broader than needed; not what the user chose. (b) No bypass — lockout risk; maintenance could only be cleared via direct SQL.

### R-203 — New-user default seeding is client-side at registration

**Decision**: At registration the client reads `LoadPublicSettings()` and seeds the new user's `locale` (from `default_language`) via `ProfileRepository.updateLocale` and `display_currency` (from `default_currency`) via the Phase 9 `CurrenciesRepository.writeUserDisplayCurrency` — amending the post-sign-in `updateLocale(deviceLocale)` block in `auth_repository_impl.dart` (~L94). Forward-only: existing users are never re-defaulted. (User-resolved 2026-06-02 — spec FR-007.)
**Rationale**: The user chose the client-side mechanism; it reuses the existing registration preferences write and needs no server trigger reading `app_settings`.
**Alternatives rejected**: A server-side trigger seeding `user_preferences` from `app_settings` at profile creation — not chosen by the user; would couple the auth trigger to the settings table.
**Note**: the admin-set default language now wins over the raw device locale for a new account (per FR-007). If device-locale preference is later desired, that is a separate future tweak (recorded so the change to the existing `updateLocale(deviceLocale)` call is intentional, not accidental — Principle XII).

### R-204 — `support_contact` is one structured key `{phone, whatsapp, email}`; the maintenance message is bilingual `{ar, en}`

**Decision**: `support_contact` is a single `app_settings` key whose JSONB value is `{"phone": …|null, "whatsapp": …|null, "email": …|null}` (each channel optional, surfaced only when set). The maintenance message lives inside the `maintenance_mode` value as `{"on": bool, "message": {"ar": …|null, "en": …|null}}`; the client renders the active-locale variant, falling back to the built-in localized copy. (User-resolved 2026-06-02 — spec FR-001/FR-011/FR-013.)
**Rationale**: A JSONB `value` column holds structured values natively, keeping the catalog small and each setting atomic; multi-channel support matches the app's phone+WhatsApp idiom and adds email; bilingual message honors Principle V on the one admin-authored copy surface.
**Alternatives rejected**: (a) Three separate `support_*` keys — inflates the catalog and loses atomic update. (b) A single free-text support string — can't distinguish call/chat/mail affordances. (c) A single-language maintenance message — breaks Arabic-first for non-matching viewers.

### R-205 — JSONB scalar/object `value` with typed Dart getters + per-type editor validation

**Decision**: Each catalog key's `value` is a documented JSONB scalar or object (see data-model). The Dart `AppSettings` aggregate exposes typed getters that parse the JSONB; the FA editor validates each control to its type/domain before calling `set_app_setting` — `default_currency` is constrained to **active** Phase 9 currencies (`ListCurrencies(activeOnly: true)`), `default_language` to `ar`/`en`, URLs to a URL shape, the visibility defaults to their enum domains.
**Rationale**: The plan's §6.2 schema is `value JSONB`; one extensible key/value table avoids a per-setting column migration when the catalog grows. Validation at the editor + the DB's typed seed keeps malformed values out.
**Alternatives rejected**: A wide typed-column table (one column per setting) — every new setting is a destructive-ish migration; loses the generic key/value extensibility the plan intends.

---

## Reconciliations with `docs/IMPLEMENTATION_PLAN.md`

- **Plan §"Phase 23" lists eight settings incl. "supported currencies"** → trimmed to seven; Phase 9 `currencies.is_active` owns supported currencies (R-198, user-resolved). Recorded in spec Clarifications + Assumptions.
- **Plan §16 open question "Maintenance-mode bypass for super-admin?"** → resolved: `settings.manage` holders only (R-202, user-resolved).
- **Plan acceptance "within 1 minute (next app foreground)"** → implemented as fetch-on-load + foreground-resume, not Realtime; "1 minute" is the re-fetch latency budget (R-201).
- **Plan §6.2 `app_settings(key, value, description, updated_by, updated_at)`** → adopted verbatim + one added `is_public` column for the per-key read classification (R-197); no other deviation.
- **Plan §9.4 "App settings changes (Phase 23)"** → satisfied by the `trg_app_settings_audit` trigger calling `log_audit('settings.updated', …)` (R-200).

*Research version: 1.0 | Phase 0 complete | All NEEDS CLARIFICATION resolved*
