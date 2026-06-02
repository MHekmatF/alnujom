-- Phase 22 (spec/022-notifications-realtime) — Migration 8/11.
-- Registers the three Phase 22 push secrets in Supabase Vault FROM ENV/GUC (R-186, ADR-0001):
--   fcm_service_account  — FCM HTTP v1 service-account JSON (read only by dispatch_push)
--   push_dispatch_url    — the dispatch Edge Function URL the trigger posts to
--   push_dispatch_token  — shared bearer the trigger uses to authorize dispatch_push
-- NO plaintext key material lives in this file (FR-018). Each value is read at apply-time
-- from a session GUC (app.settings.<name>) the operator sets via env before applying:
--   set_config('app.settings.fcm_service_account', '<json>', false)  (or postgres GUC).
-- Idempotent: skip if the env GUC is unset/empty OR the secret already exists. When the env
-- is unset (e.g. a CI run with no Firebase), NO secret is created → notify_push_dispatch
-- skips → degraded in-app-only mode (FR-013). Secrets are read server-side via
-- app_vault_secret(name) (Phase 4) only.

do $$
declare
  v_name  text;
  v_value text;
  v_desc  text;
  v_specs constant text[][] := array[
    array['fcm_service_account',
          'FCM HTTP v1 service-account JSON (Phase 22 push) — read only by dispatch_push'],
    array['push_dispatch_url',
          'Phase 22 dispatch_push Edge Function URL — read by notify_push_dispatch trigger'],
    array['push_dispatch_token',
          'Phase 22 shared bearer authorizing the dispatch_push Edge Function — read by notify_push_dispatch']
  ];
  i int;
begin
  for i in 1 .. array_length(v_specs, 1) loop
    v_name  := v_specs[i][1];
    v_desc  := v_specs[i][2];
    v_value := current_setting('app.settings.' || v_name, true);   -- missing_ok = true → null if unset
    if v_value is not null and length(v_value) > 0
       and not exists (select 1 from vault.secrets where name = v_name) then
      perform vault.create_secret(v_value, v_name, v_desc);
    end if;
  end loop;
end $$;
