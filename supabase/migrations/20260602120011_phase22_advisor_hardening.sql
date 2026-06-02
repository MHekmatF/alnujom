-- Phase 22 (spec/022-notifications-realtime) — Migration 11/11.
-- Advisor hardening: re-assert SET search_path = '' on every NEW Phase 22 function so the
-- Supabase linter's "function_search_path_mutable" advisor stays clean even if a prior
-- create-or-replace is later re-applied without the SET clause. Both new tables already have
-- RLS ON (…001/…002) and all client writes REVOKEd, so no RLS-disabled-table advisor applies.
-- These ALTERs ONLY touch functions DEFINED by Phase 22 — the four re-based transition
-- amendments keep their ORIGINAL search_path (public / pg_catalog,public,vault / public,pg_temp)
-- as authored in …004–…007 (re-base discipline — not re-hardened here).
-- Idempotent: ALTER FUNCTION … SET is unconditional and safely re-runnable.

alter function public.enqueue_notification(uuid, text, jsonb)          set search_path = '';
alter function public.register_notification_token(text, text)          set search_path = '';
alter function public.deregister_notification_token(text)              set search_path = '';
alter function public.mark_notification_read(uuid)                     set search_path = '';
alter function public.mark_all_notifications_read()                    set search_path = '';
alter function public.unread_notification_count()                      set search_path = '';
alter function public.notify_push_dispatch()                          set search_path = '';
