# Quickstart — App Settings (Phase 23) manual verification

End-to-end recipe a reviewer/agent runs to validate Phase 23 against the Success Criteria. No new automated tests (project MVP convention). Two sessions/devices: **A** = a super-admin (holds `settings.manage`); **B** = a regular user (and an anonymous/logged-out state). Reference device Infinix Note 8 + a 412 dp Pixel 8 Pro AVD. Always run with `--dart-define-from-file=.env.json` (memory `project_dart_defines`).

## 0. Apply backend (PB)

1. Apply migrations in order via Supabase MCP (`project_supabase_apply_via_mcp`): `20260602120014` → `…015` → `…016` → `…017`.
2. `get_advisors` → expect no new SECURITY DEFINER / RLS findings.
3. `SELECT key, is_public FROM app_settings ORDER BY key;` → exactly 8 public keys, **no `supported_currencies`** (SC-010 partial).

## 1. Build & launch

4. `flutter analyze` clean; full verify suite (format / design-tokens / l10n-parity / l10n-literals / SDK-boundary — `project_wave_run_full_verify_suite`) green; launch on A and B.

## 2. Admin editor — persistence + audit (SC-001)

5. On A (super-admin) → Dashboard → **Settings** tile (now active, not "coming soon") → editor opens. Confirm each control type renders: toggle (maintenance), pickers (language, currency [only active currencies offered], visibility defaults), validated text (support phone/WhatsApp/email, terms/privacy URLs, bilingual maintenance message).
6. Enter an **invalid** URL / unknown currency → save blocked with a localized validation message (FR-004 negative).
7. Change `default_currency` + a `support_contact.phone` to valid values → save. Restart A → values persist. `SELECT * FROM audit_logs WHERE action='settings.updated' ORDER BY created_at DESC LIMIT 2;` → rows with actor = A, before/after.

## 3. Maintenance mode — two-device + bypass matrix (SC-002, SC-003)

8. With B in normal use, on A toggle **maintenance ON** (optionally set ar + en messages). Foreground B (or wait its resume) → within ~1 min B shows the **MaintenanceScreen** with the active-locale message, the support contact, and a **retry** button.
9. Confirm the **bypass matrix**: A (settings.manage) still has full access incl. the editor; B (regular) is blocked; log B out → the **anonymous** state is blocked too; (if available) a **moderator without settings.manage** is blocked.
10. On A toggle **maintenance OFF** → B's retry / next foreground restores normal access.

## 4. Forward-only defaults (SC-004, SC-005)

11. Note B's current display currency. On A change `default_currency` to a different active currency → B's existing preference is **unchanged**. Register a **brand-new** account → its `user_preferences` is seeded with the new default currency + default language (`SELECT locale, display_currency FROM user_preferences WHERE user_id = '<new>'`).
12. On A set new publisher-name + location visibility defaults → start a **new** listing as a publisher → those fields are **pre-selected** to the new defaults; an **existing** listing's visibility is unchanged.

## 5. Security wire-level (SC-006)

13. From B's session (no `settings.manage`): `rpc('set_app_setting', {p_key:'maintenance_mode', p_value:'{"on":true}'})` → **denied** (`42501`). Direct `UPDATE app_settings …` as `authenticated` → **denied**.
14. Anonymous `select` on `app_settings` → returns the 8 **public** keys (reads succeed). Seed a temporary `is_public=false` test key → confirm anon/B cannot read it → delete it.

## 6. Resilience — fetch failure (SC-007)

15. Put the device **offline** and cold-launch → the app **opens on safe defaults**, does **NOT** show the maintenance screen because of the failed fetch, and does **not crash**. Restore network → foreground re-fetch picks up real settings.

## 7. Localization & theming (SC-008)

16. Open the **editor** and the **MaintenanceScreen** and cycle the four combinations — (light, ar), (dark, ar), (light, en), (dark, en) — on the Infinix Note 8 + 412 dp AVD. All strings localized (no raw literals; `_DebugAppLocalizations` override gate passes), layout direction-correct, styling from Phase 2 tokens.

## 8. Surfaced settings (SC-009)

17. With `support_contact` + `terms_url` set on A, open the about/support surface on B → the channels + links render (tappable call/chat/mail + links). Unset a channel → it disappears (no broken affordance). Change a value on A → B reflects it on next load.

## 9. Structural / scope gate (SC-010)

18. Grep/inspect:
    - one new table `app_settings`; one new RPC `set_app_setting`; one audit trigger; **no new permission key** (reuses `PermissionKeys.settingsManage` / `settings.manage`); **no `supported_currencies`** key.
    - no `package:supabase_flutter` import under `lib/features/settings/domain/` (Principle IX).
    - no iOS/Web code; **no new dependency** added to `pubspec.yaml` (diff vs `main`).
    - no change to any existing table beyond the new `app_settings` (FR-018).

*Quickstart version: 1.0 | Phase 1 | Verifies SC-001..SC-010*
