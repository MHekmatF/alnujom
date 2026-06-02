# Contract: `set_app_setting` RPC + audit trigger

**Phase 23 · migration `20260602120015_create_set_app_setting_rpc.sql`**

## Signature

```sql
public.set_app_setting(p_key TEXT, p_value JSONB) RETURNS public.app_settings
```

- `LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, auth`.
- **Permission**: re-checks `public.current_user_has_permission('settings.manage')`; raises if absent (checks-at-both-ends with the FA UI gate — Principle III).
- **Effect**: `UPDATE app_settings SET value = p_value, updated_by = auth.uid(), updated_at = now() WHERE key = p_key`; returns the updated row.
- **Grants**: `REVOKE EXECUTE FROM anon, PUBLIC; GRANT EXECUTE TO authenticated` — the function is the permission boundary.

## Error codes

| Condition | ERRCODE | Meaning |
|---|---|---|
| caller lacks `settings.manage` | `42501` | permission denied |
| `p_key` not a seeded catalog key | `P0002` | unknown app setting key (no row updated) |

The client maps these to a `Failure` (permission vs not-found) — no partial write occurs (single-statement UPDATE).

## Audit trigger

```sql
CREATE TRIGGER trg_app_settings_audit
  AFTER UPDATE ON public.app_settings
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('settings.updated', 'value', 'key');
```

- Reuses the Phase 4 `log_audit()` trigger function (args: action, watched-columns, pk-column).
- Writes one `audit_logs` row per successful change: `actor_user_id = auth.uid()`, `action = 'settings.updated'`, `target_type = 'app_settings'`, `target_id = key`, before/after `value`.
- This is the §9.4 "App settings changes (Phase 23)" audited action — **no new audit infrastructure**.

## Invariants

- Every successful write is audited (the trigger fires on the definer's UPDATE).
- A denied call writes nothing and audits nothing (the exception aborts before UPDATE).

## Consumed by

- FD `SupabaseAppSettingsDatasource.updateSetting()` — `_client.rpc('set_app_setting', params: {'p_key': key.wire, 'p_value': value})`.
