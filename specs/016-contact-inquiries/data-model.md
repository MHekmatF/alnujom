# Phase 16 — Data Model

This document specifies the full SQL migration bodies, the Dart domain entity definitions, and the FR/SC verification map for Phase 16.

---

## 1. Vault key one-time setup

Before applying any Phase 16 migration, a Vault key for inquirer-phone encryption must be created on the live Supabase project. This is a one-time setup step, documented here and in `quickstart.md`:

```sql
-- Run once, idempotently, on the live project. Phase 4's vault scaffolding
-- (20260506120006_enable_vault.sql) is the prerequisite.
SELECT vault.create_secret(
  'app_inquirer_phone_key',
  'app-inquirer-phone-key',  -- name used by the encrypt/decrypt calls
  'Symmetric key for inquirer_phone column encryption in public.inquiries (Phase 16, ADR-0001)'
);
-- The returned UUID is stored as the project-wide `inquirer_phone_key_id`.
-- Phase 16's `submit_inquiry` and `decrypt_inquirer_phone` functions read this
-- key by name via `vault.decrypted_secrets WHERE name = 'app-inquirer-phone-key'`.
```

The key name `'app-inquirer-phone-key'` is the convention; rotating the key (a manual `vault.update_secret(...)` call) re-keys future writes without touching existing ciphertexts (those remain decryptable with the prior key version via Vault's key-history). Rotation is documented in `supabase/docs/inquiries.md`.

---

## 2. SQL migrations

### 2.1 `20260527120001_create_inquiries_table.sql`

```sql
-- Phase 16: inquiries table (publisher-targeted written submissions).
-- ADR-0001: inquirer_phone stored via Supabase Vault.
-- Q4=C: ON DELETE RESTRICT on listing_id (listings use soft-delete via status='deleted').
-- Q7=B: message capped at 2000 chars.

CREATE TABLE IF NOT EXISTS public.inquiries (
  id                          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id                  UUID         NOT NULL REFERENCES public.listings(id) ON DELETE RESTRICT,
  sender_user_id              UUID         NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  sender_name                 TEXT         NOT NULL CHECK (length(trim(sender_name)) BETWEEN 1 AND 100),
  inquirer_phone_encrypted    BYTEA        NULL,
  inquirer_phone_key_name     TEXT         NOT NULL DEFAULT 'app-inquirer-phone-key',
  message                     TEXT         NOT NULL CHECK (length(trim(message)) BETWEEN 1 AND 2000),
  status                      TEXT         NOT NULL DEFAULT 'new'
                                CHECK (status IN ('new','seen','responded','closed','spam')),
  created_at                  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at                  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

ALTER TABLE public.inquiries ENABLE ROW LEVEL SECURITY;

DROP TRIGGER IF EXISTS trg_inquiries_set_updated_at ON public.inquiries;
CREATE TRIGGER trg_inquiries_set_updated_at
  BEFORE UPDATE ON public.inquiries
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE INDEX IF NOT EXISTS idx_inquiries_listing_created
  ON public.inquiries (listing_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_inquiries_listing_status
  ON public.inquiries (listing_id, status, created_at DESC)
  WHERE status IN ('new','seen','responded');
CREATE INDEX IF NOT EXISTS idx_inquiries_sender
  ON public.inquiries (sender_user_id)
  WHERE sender_user_id IS NOT NULL;
```

### 2.2 `20260527120002_create_lead_events_table.sql`

```sql
-- Phase 16: lead_events table (high-volume engagement signal stream).
-- Q4=C: ON DELETE RESTRICT on listing_id (consistent with inquiries).
-- Q5=B: metadata column carries {ip, user_agent} populated by record_lead_event RPC.
-- favorite_added event type reserved for Phase 17; no Phase 16 write path.

CREATE TABLE IF NOT EXISTS public.lead_events (
  id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id          UUID         NOT NULL REFERENCES public.listings(id) ON DELETE RESTRICT,
  user_id             UUID         NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  event_type          TEXT         NOT NULL
                        CHECK (event_type IN ('phone_revealed','whatsapp_clicked','inquiry_sent','favorite_added')),
  metadata            JSONB        NULL,
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT now()
);

ALTER TABLE public.lead_events ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_lead_events_listing_created
  ON public.lead_events (listing_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_lead_events_listing_type
  ON public.lead_events (listing_id, event_type, created_at DESC);
```

### 2.3 `20260527120003_create_inquiries_policies.sql`

```sql
-- Phase 16: inquiries RLS policies — three-tier visibility per FR-022, FR-023, FR-024.

-- Defense-in-depth: ensure inquiries.view_all permission is seeded (Phase 6 should have done it).
INSERT INTO public.permissions (key, description_ar, description_en, category)
VALUES (
  'inquiries.view_all',
  'الإطلاع على جميع الاستفسارات عبر الناشرين',
  'View all inquiries across publishers',
  'inquiries'
)
ON CONFLICT (key) DO NOTHING;

-- SELECT: three-tier rule (publisher / sender / admin)
DROP POLICY IF EXISTS inquiries_select_publisher ON public.inquiries;
CREATE POLICY inquiries_select_publisher ON public.inquiries
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.listings l
      WHERE l.id = inquiries.listing_id
        AND l.publisher_user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS inquiries_select_sender ON public.inquiries;
CREATE POLICY inquiries_select_sender ON public.inquiries
  FOR SELECT TO authenticated
  USING (sender_user_id = auth.uid() AND sender_user_id IS NOT NULL);

DROP POLICY IF EXISTS inquiries_select_admin ON public.inquiries;
CREATE POLICY inquiries_select_admin ON public.inquiries
  FOR SELECT TO authenticated
  USING (public.current_user_has_permission('inquiries.view_all'));

-- UPDATE: publisher only, transition trigger validates the new status
DROP POLICY IF EXISTS inquiries_update_publisher ON public.inquiries;
CREATE POLICY inquiries_update_publisher ON public.inquiries
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.listings l
      WHERE l.id = inquiries.listing_id
        AND l.publisher_user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.listings l
      WHERE l.id = inquiries.listing_id
        AND l.publisher_user_id = auth.uid()
    )
  );

-- INSERT: blocked at the table level (writes go through submit_inquiry RPC)
REVOKE INSERT ON public.inquiries FROM authenticated, anon;

-- DELETE: blocked entirely (no policy; RLS default-deny applies)
```

### 2.4 `20260527120004_create_lead_events_policies.sql`

```sql
-- Phase 16: lead_events RLS policies — publisher + admin tiers per FR-014b.

DROP POLICY IF EXISTS lead_events_select_publisher ON public.lead_events;
CREATE POLICY lead_events_select_publisher ON public.lead_events
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.listings l
      WHERE l.id = lead_events.listing_id
        AND l.publisher_user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS lead_events_select_admin ON public.lead_events;
CREATE POLICY lead_events_select_admin ON public.lead_events
  FOR SELECT TO authenticated
  USING (public.current_user_has_permission('inquiries.view_all'));

-- INSERT/UPDATE/DELETE: all blocked at the table level
REVOKE INSERT, UPDATE, DELETE ON public.lead_events FROM authenticated, anon;
```

### 2.5 `20260527120005_create_enforce_inquiry_transition_trigger.sql`

```sql
-- Phase 16: BEFORE UPDATE trigger enforcing the transition allowlist per FR-021a + Q2=B.
-- Q2=B: soft-terminal closed-reopen to seen/responded; closed→new forbidden.
-- Q3=B: spam reachable from any non-spam state (for forward admin moderation).

CREATE OR REPLACE FUNCTION public.enforce_inquiry_transition()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  -- No-op: status unchanged
  IF OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;

  -- Allowed transitions (forward + closed-reopen + any-to-spam)
  IF (OLD.status, NEW.status) IN (
    ('new', 'seen'),
    ('seen', 'responded'),
    ('seen', 'closed'),
    ('responded', 'closed'),
    ('responded', 'seen'),
    ('closed', 'seen'),
    ('closed', 'responded')
  ) THEN
    RETURN NEW;
  END IF;

  -- Any non-spam state -> spam is allowed (admin moderation, future phase)
  IF NEW.status = 'spam' AND OLD.status <> 'spam' THEN
    RETURN NEW;
  END IF;

  -- Everything else: reject
  RAISE EXCEPTION
    'invalid_inquiry_transition: % -> %', OLD.status, NEW.status
    USING ERRCODE = '23514';
END;
$$;

DROP TRIGGER IF EXISTS trg_inquiries_enforce_transition ON public.inquiries;
CREATE TRIGGER trg_inquiries_enforce_transition
  BEFORE UPDATE OF status ON public.inquiries
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_inquiry_transition();
```

### 2.6 `20260527120006_create_decrypt_inquirer_phone_fn.sql`

```sql
-- Phase 16: SECURITY DEFINER decrypt function with three-tier visibility check.
-- ADR-0001 + Q5=B + FR-023: only publisher / signed-in sender / admin decrypt.

CREATE OR REPLACE FUNCTION public.decrypt_inquirer_phone(p_inquiry_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, vault
STABLE
AS $$
DECLARE
  v_listing_id        UUID;
  v_sender_user_id    UUID;
  v_encrypted         BYTEA;
  v_key_name          TEXT;
  v_authorized        BOOLEAN := FALSE;
  v_decrypted         TEXT;
BEGIN
  -- Load the inquiry row (bypassing RLS via SECURITY DEFINER)
  SELECT i.listing_id, i.sender_user_id, i.inquirer_phone_encrypted, i.inquirer_phone_key_name
    INTO v_listing_id, v_sender_user_id, v_encrypted, v_key_name
    FROM public.inquiries i
    WHERE i.id = p_inquiry_id;

  IF NOT FOUND OR v_encrypted IS NULL THEN
    RETURN NULL;
  END IF;

  -- Three-tier visibility check
  IF v_sender_user_id IS NOT NULL AND v_sender_user_id = auth.uid() THEN
    v_authorized := TRUE;
  ELSIF EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = v_listing_id AND l.publisher_user_id = auth.uid()
  ) THEN
    v_authorized := TRUE;
  ELSIF public.current_user_has_permission('inquiries.view_all') THEN
    v_authorized := TRUE;
  END IF;

  IF NOT v_authorized THEN
    RETURN NULL;
  END IF;

  -- Decrypt (catch errors; return NULL on failure per FR-026)
  BEGIN
    SELECT decrypted_secret INTO v_decrypted
      FROM vault.decrypted_secrets
      WHERE name = v_key_name;

    -- Decrypt the ciphertext with the key
    v_decrypted := convert_from(
      pgsodium.crypto_aead_det_decrypt(
        v_encrypted,
        convert_to(p_inquiry_id::text, 'utf8'),  -- context (inquiry id as AAD)
        v_decrypted::uuid                          -- key id
      ),
      'utf8'
    );
    RETURN v_decrypted;
  EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
  END;
END;
$$;

REVOKE ALL ON FUNCTION public.decrypt_inquirer_phone(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.decrypt_inquirer_phone(UUID) TO authenticated;
```

> **Implementation note**: The exact Vault/`pgsodium` API surface depends on the project's installed `pgsodium` + `vault` version. Phase 5's `20260510120004_profiles_vault_pii_helpers.sql` is the reference implementation for this project — Phase 16's `submit_inquiry` and `decrypt_inquirer_phone` MUST follow the same key-id + `crypto_aead_det_encrypt` / `crypto_aead_det_decrypt` pattern as Phase 5. The above is the canonical shape; the precise API calls are reconciled with Phase 5's helpers at implementation time.

### 2.7 `20260527120007_create_v_inquiries_inbox_view.sql`

```sql
-- Phase 16: inbox view with inlined decrypt-per-row.

CREATE OR REPLACE VIEW public.v_inquiries_inbox AS
SELECT
  i.id,
  i.listing_id,
  l.title             AS listing_title,
  l.status            AS listing_status,
  i.sender_user_id,
  i.sender_name,
  i.message,
  i.status,
  i.created_at,
  i.updated_at,
  public.decrypt_inquirer_phone(i.id) AS inquirer_phone_decrypted
FROM public.inquiries i
JOIN public.listings  l ON l.id = i.listing_id;

GRANT SELECT ON public.v_inquiries_inbox TO authenticated;
-- NOT granted to anon.
```

### 2.8 `20260527120008_create_v_lead_events_views.sql`

```sql
-- Phase 16: per-tier lead_events views with column-level metadata masking.

-- Publisher tier: metadata column omitted from projection per FR-014b.
CREATE OR REPLACE VIEW public.v_lead_events_publisher AS
SELECT
  le.id,
  le.listing_id,
  le.user_id,
  le.event_type,
  le.created_at
FROM public.lead_events le;

GRANT SELECT ON public.v_lead_events_publisher TO authenticated;

-- Admin tier: every column INCLUDING metadata. Self-gated by permission check
-- inside the view body so even direct selects fail closed for non-admins.
CREATE OR REPLACE VIEW public.v_lead_events_admin AS
SELECT
  le.id,
  le.listing_id,
  le.user_id,
  le.event_type,
  le.metadata,
  le.created_at
FROM public.lead_events le
WHERE public.current_user_has_permission('inquiries.view_all');

GRANT SELECT ON public.v_lead_events_admin TO authenticated;
```

### 2.9 `20260527120009_create_submit_inquiry_rpc.sql`

```sql
-- Phase 16: atomic inquiry submission per FR-009 + FR-017.

CREATE OR REPLACE FUNCTION public.submit_inquiry(
  p_listing_id      UUID,
  p_sender_name     TEXT,
  p_inquirer_phone  TEXT,
  p_message         TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, vault
AS $$
DECLARE
  v_listing_status       TEXT;
  v_publisher_user_id    UUID;
  v_inquiry_id           UUID;
  v_phone_normalized     TEXT;
  v_key_id               UUID;
  v_encrypted            BYTEA;
  v_ip                   INET;
  v_user_agent           TEXT;
BEGIN
  -- Validate p_sender_name
  IF length(trim(p_sender_name)) < 1 OR length(trim(p_sender_name)) > 100 THEN
    RAISE EXCEPTION 'invalid_sender_name' USING ERRCODE = '23514';
  END IF;

  -- Validate p_inquirer_phone E.164
  IF NOT (p_inquirer_phone ~ '^\+[1-9]\d{6,14}$') THEN
    RAISE EXCEPTION 'invalid_phone' USING ERRCODE = '23514';
  END IF;
  v_phone_normalized := p_inquirer_phone;

  -- Validate p_message
  IF length(trim(p_message)) < 1 OR length(trim(p_message)) > 2000 THEN
    RAISE EXCEPTION 'invalid_message_length' USING ERRCODE = '23514';
  END IF;

  -- Validate p_listing_id references an approved listing, not self
  SELECT l.status, l.publisher_user_id
    INTO v_listing_status, v_publisher_user_id
    FROM public.listings l
    WHERE l.id = p_listing_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'listing_not_found' USING ERRCODE = '23503';
  END IF;
  IF v_listing_status <> 'approved' THEN
    RAISE EXCEPTION 'listing_not_approved' USING ERRCODE = '23514';
  END IF;
  IF v_publisher_user_id = auth.uid() THEN
    RAISE EXCEPTION 'self_contact_blocked' USING ERRCODE = '23514';
  END IF;

  -- Fetch the Vault key for inquirer_phone
  SELECT decrypted_secret::uuid INTO v_key_id
    FROM vault.decrypted_secrets
    WHERE name = 'app-inquirer-phone-key';

  -- Encrypt the phone (deterministic AEAD; inquiry id will be the AAD —
  -- we pre-generate the id so we can pass it as context)
  v_inquiry_id := gen_random_uuid();
  v_encrypted := pgsodium.crypto_aead_det_encrypt(
    convert_to(v_phone_normalized, 'utf8'),
    convert_to(v_inquiry_id::text, 'utf8'),
    v_key_id
  );

  -- Capture IP + UA from server-side request context per Q5=B
  v_ip := inet_client_addr();
  BEGIN
    v_user_agent := current_setting('request.headers', true)::jsonb->>'user-agent';
  EXCEPTION WHEN OTHERS THEN
    v_user_agent := NULL;
  END;

  -- INSERT both rows atomically (single transaction by virtue of being in one function body)
  INSERT INTO public.inquiries (
    id, listing_id, sender_user_id, sender_name,
    inquirer_phone_encrypted, inquirer_phone_key_name,
    message, status, created_at, updated_at
  ) VALUES (
    v_inquiry_id, p_listing_id, auth.uid(), trim(p_sender_name),
    v_encrypted, 'app-inquirer-phone-key',
    trim(p_message), 'new', now(), now()
  );

  INSERT INTO public.lead_events (
    listing_id, user_id, event_type, metadata, created_at
  ) VALUES (
    p_listing_id, auth.uid(), 'inquiry_sent',
    jsonb_build_object('ip', v_ip::text, 'user_agent', v_user_agent),
    now()
  );

  RETURN v_inquiry_id;
END;
$$;

REVOKE ALL ON FUNCTION public.submit_inquiry(UUID, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_inquiry(UUID, TEXT, TEXT, TEXT) TO authenticated, anon;
```

### 2.10 `20260527120010_create_record_lead_event_rpc.sql`

```sql
-- Phase 16: lightweight lead-event capture for phone-reveal + WhatsApp-click taps.

CREATE OR REPLACE FUNCTION public.record_lead_event(
  p_listing_id  UUID,
  p_event_type  TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_status        TEXT;
  v_phone         TEXT;
  v_whatsapp      TEXT;
  v_event_id      UUID;
  v_ip            INET;
  v_user_agent    TEXT;
BEGIN
  -- Phase 16 only handles tap-event types; inquiry_sent goes through submit_inquiry;
  -- favorite_added is reserved for Phase 17.
  IF p_event_type NOT IN ('phone_revealed', 'whatsapp_clicked') THEN
    RAISE EXCEPTION 'invalid_event_type' USING ERRCODE = '23514';
  END IF;

  SELECT l.status, l.phone, l.whatsapp
    INTO v_status, v_phone, v_whatsapp
    FROM public.listings l
    WHERE l.id = p_listing_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'listing_not_found' USING ERRCODE = '23503';
  END IF;
  IF v_status <> 'approved' THEN
    RAISE EXCEPTION 'listing_not_approved' USING ERRCODE = '23514';
  END IF;
  IF p_event_type = 'phone_revealed' AND (v_phone IS NULL OR trim(v_phone) = '') THEN
    RAISE EXCEPTION 'phone_not_set' USING ERRCODE = '23514';
  END IF;
  IF p_event_type = 'whatsapp_clicked' AND (v_whatsapp IS NULL OR trim(v_whatsapp) = '') THEN
    RAISE EXCEPTION 'whatsapp_not_set' USING ERRCODE = '23514';
  END IF;

  v_ip := inet_client_addr();
  BEGIN
    v_user_agent := current_setting('request.headers', true)::jsonb->>'user-agent';
  EXCEPTION WHEN OTHERS THEN
    v_user_agent := NULL;
  END;

  v_event_id := gen_random_uuid();
  INSERT INTO public.lead_events (
    id, listing_id, user_id, event_type, metadata, created_at
  ) VALUES (
    v_event_id, p_listing_id, auth.uid(), p_event_type,
    jsonb_build_object('ip', v_ip::text, 'user_agent', v_user_agent),
    now()
  );

  RETURN v_event_id;
END;
$$;

REVOKE ALL ON FUNCTION public.record_lead_event(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_lead_event(UUID, TEXT) TO authenticated, anon;
```

### 2.11 `20260527120011_create_get_inbox_unread_count_rpc.sql`

```sql
-- Phase 16: cheap scalar read for the home AppBar badge.

CREATE OR REPLACE FUNCTION public.get_inbox_unread_count()
RETURNS INTEGER
LANGUAGE sql
SECURITY DEFINER
SET search_path = pg_catalog, public
STABLE
AS $$
  SELECT COUNT(*)::INTEGER
  FROM public.inquiries i
  JOIN public.listings  l ON l.id = i.listing_id
  WHERE l.publisher_user_id = auth.uid()
    AND i.status = 'new';
$$;

REVOKE ALL ON FUNCTION public.get_inbox_unread_count() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_inbox_unread_count() TO authenticated;
-- NOT granted to anon.
```

### 2.12 `20260527120012_phase16_advisor_hardening.sql`

```sql
-- Phase 16: safety-net hardening matching Phase 9/10/11/14/15 advisor recommendations.

-- Re-assert search_path on every new function (defense-in-depth against schema injection)
ALTER FUNCTION public.enforce_inquiry_transition()       SET search_path = pg_catalog, public;
ALTER FUNCTION public.decrypt_inquirer_phone(UUID)       SET search_path = pg_catalog, public, vault;
ALTER FUNCTION public.submit_inquiry(UUID, TEXT, TEXT, TEXT) SET search_path = pg_catalog, public, vault;
ALTER FUNCTION public.record_lead_event(UUID, TEXT)      SET search_path = pg_catalog, public;
ALTER FUNCTION public.get_inbox_unread_count()           SET search_path = pg_catalog, public;

-- Table-level: deny all by default, then allow only via views
REVOKE ALL ON TABLE public.inquiries  FROM PUBLIC, authenticated, anon;
REVOKE ALL ON TABLE public.lead_events FROM PUBLIC, authenticated, anon;

GRANT SELECT, UPDATE (status) ON TABLE public.inquiries TO authenticated;
-- Note: UPDATE on `status` only — never on inquirer_phone_encrypted, message, sender_user_id, etc.
-- The UPDATE RLS policy (inquiries_update_publisher) AND the transition trigger jointly enforce
-- which status values the publisher may set.

GRANT SELECT ON public.v_inquiries_inbox       TO authenticated;
GRANT SELECT ON public.v_lead_events_publisher TO authenticated;
GRANT SELECT ON public.v_lead_events_admin     TO authenticated;
```

---

## 3. Dart domain entities

All entities live under `lib/features/inquiries/domain/entities/`. Each is `@immutable` + `Equatable` per project convention.

### 3.1 `inquiry_status.dart`

```dart
import 'package:equatable/equatable.dart';

/// FR-013, FR-021a, Q2=B, Q3=B
enum InquiryStatus {
  /// Newly submitted; no publisher action yet.
  new_,
  /// Publisher has opened it (auto-transition on detail-page read).
  seen,
  /// Publisher has called/WhatsApp'd or otherwise replied out-of-band.
  responded,
  /// Resolution complete (deal closed, lost, or otherwise no longer actionable).
  closed,
  /// Admin-flagged (Phase 16 has no publisher-side write path per Q3=B).
  spam;

  /// Per Q2=B + Q3=B: forward + closed-reopen + any-to-spam.
  static const Map<InquiryStatus, Set<InquiryStatus>> _allowed = {
    InquiryStatus.new_:      { InquiryStatus.seen, InquiryStatus.spam },
    InquiryStatus.seen:      { InquiryStatus.responded, InquiryStatus.closed, InquiryStatus.spam },
    InquiryStatus.responded: { InquiryStatus.closed, InquiryStatus.seen, InquiryStatus.spam },
    InquiryStatus.closed:    { InquiryStatus.seen, InquiryStatus.responded, InquiryStatus.spam },
    InquiryStatus.spam:      <InquiryStatus>{},  // terminal — no publisher-side path out
  };

  /// Returns the set of statuses this status can transition to.
  Set<InquiryStatus> get allowedTransitions => _allowed[this]!;

  /// Wire-format mapping used by DTO serialization.
  String get wireValue => switch (this) {
    InquiryStatus.new_       => 'new',
    InquiryStatus.seen       => 'seen',
    InquiryStatus.responded  => 'responded',
    InquiryStatus.closed     => 'closed',
    InquiryStatus.spam       => 'spam',
  };

  static InquiryStatus fromWire(String s) => switch (s) {
    'new'       => InquiryStatus.new_,
    'seen'      => InquiryStatus.seen,
    'responded' => InquiryStatus.responded,
    'closed'    => InquiryStatus.closed,
    'spam'      => InquiryStatus.spam,
    _           => throw ArgumentError('Unknown inquiry status: $s'),
  };
}
```

### 3.2 `lead_event_type.dart`

```dart
/// FR-014; favoriteAdded reserved for Phase 17.
enum LeadEventType {
  phoneRevealed,
  whatsappClicked,
  inquirySent,
  /// Reserved for Phase 17. Phase 16 has no write path to this event.
  favoriteAdded;

  String get wireValue => switch (this) {
    LeadEventType.phoneRevealed   => 'phone_revealed',
    LeadEventType.whatsappClicked => 'whatsapp_clicked',
    LeadEventType.inquirySent     => 'inquiry_sent',
    LeadEventType.favoriteAdded   => 'favorite_added',
  };

  static LeadEventType fromWire(String s) => switch (s) {
    'phone_revealed'  => LeadEventType.phoneRevealed,
    'whatsapp_clicked' => LeadEventType.whatsappClicked,
    'inquiry_sent'    => LeadEventType.inquirySent,
    'favorite_added'  => LeadEventType.favoriteAdded,
    _                 => throw ArgumentError('Unknown lead event type: $s'),
  };
}
```

### 3.3 `inquiry.dart`

```dart
import 'package:equatable/equatable.dart';

import '../../../listing_form/domain/entities/listing.dart' show ListingStatus;
import 'inquiry_status.dart';

class Inquiry extends Equatable {
  const Inquiry({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.listingStatus,
    required this.senderUserId,
    required this.senderName,
    required this.decryptedPhone,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String listingId;
  final String listingTitle;
  final ListingStatus listingStatus;
  final String? senderUserId;
  final String senderName;
  /// Null when the caller is not authorized OR when Vault decrypt failed
  /// (FR-026 — render the "Phone unavailable" placeholder).
  final String? decryptedPhone;
  final String message;
  final InquiryStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Inquiry copyWith({InquiryStatus? status}) => Inquiry(
    id: id,
    listingId: listingId,
    listingTitle: listingTitle,
    listingStatus: listingStatus,
    senderUserId: senderUserId,
    senderName: senderName,
    decryptedPhone: decryptedPhone,
    message: message,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  @override
  List<Object?> get props => [
    id, listingId, listingTitle, listingStatus, senderUserId, senderName,
    decryptedPhone, message, status, createdAt, updatedAt,
  ];
}
```

### 3.4 `lead_event.dart`

```dart
import 'package:equatable/equatable.dart';

import 'lead_event_type.dart';

class LeadEvent extends Equatable {
  const LeadEvent({
    required this.id,
    required this.listingId,
    required this.userId,
    required this.eventType,
    required this.metadata,
    required this.createdAt,
  });

  final String id;
  final String listingId;
  final String? userId;
  final LeadEventType eventType;
  /// Null for the publisher tier per FR-014b. Populated for admin tier.
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, listingId, userId, eventType, metadata, createdAt];
}
```

### 3.5 `inquiry_submission.dart`

```dart
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../shared/domain/value_objects/phone_number.dart';

class InquirySubmission extends Equatable {
  const InquirySubmission._({
    required this.listingId,
    required this.senderName,
    required this.phone,
    required this.message,
  });

  final String listingId;
  final String senderName;
  final String phone;   // E.164 validated
  final String message;

  static Result<InquirySubmission, Failure> validate({
    required String listingId,
    required String senderName,
    required String phone,
    required String message,
  }) {
    final trimmedName = senderName.trim();
    if (trimmedName.isEmpty || trimmedName.length > 100) {
      return const Result.failure(Failure.validation('invalid_sender_name'));
    }
    final phoneE164 = PhoneNumber.tryParse(phone);
    if (phoneE164 == null) {
      return const Result.failure(Failure.validation('invalid_phone'));
    }
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty || trimmedMessage.length > 2000) {
      return const Result.failure(Failure.validation('invalid_message_length'));
    }
    return Result.success(InquirySubmission._(
      listingId: listingId,
      senderName: trimmedName,
      phone: phoneE164.toE164(),
      message: trimmedMessage,
    ));
  }

  @override
  List<Object?> get props => [listingId, senderName, phone, message];
}
```

### 3.6 Repository interfaces

`inquiry_repository.dart`:

```dart
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import 'inquiry.dart';
import 'inquiry_status.dart';
import 'inquiry_submission.dart';

abstract class InquiryRepository {
  Future<Result<String, Failure>> submitInquiry(InquirySubmission submission);

  Future<Result<List<Inquiry>, Failure>> loadInbox({
    InquiryStatus? statusFilter,
    String? listingIdFilter,
    String? cursor,
    int limit = 30,
  });

  Future<Result<Inquiry, Failure>> loadDetail(String inquiryId);

  Future<Result<void, Failure>> updateStatus(String inquiryId, InquiryStatus newStatus);

  Future<Result<int, Failure>> loadUnreadCount();
}
```

`lead_event_repository.dart`:

```dart
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import 'lead_event.dart';
import 'lead_event_type.dart';

abstract class LeadEventRepository {
  Future<Result<String, Failure>> recordEvent({
    required String listingId,
    required LeadEventType eventType,
  });

  /// Admin-only path. Returns [Failure.permissionDenied] for non-admin callers
  /// per RLS (the view's permission predicate enforces this).
  Future<Result<List<LeadEvent>, Failure>> loadByListing(
    String listingId, {
    DateTime? since,
  });
}
```

---

## 4. FR / SC verification map

| FR | Verification path |
|----|-------------------|
| FR-001 | Manual UI inspection: `ContactBlock` in `lib/features/listing_details/presentation/widgets/contact_block.dart` retains its three-button layout; the snackbar handlers are replaced (grep for `_showComingSoon` → must return zero matches). |
| FR-001a | SQL: `SELECT phone FROM listings WHERE status='approved' AND (phone IS NULL OR trim(phone) = '')`; render Call CTA hidden in UI. |
| FR-001b | Same as FR-001a for `whatsapp`; render WhatsApp CTA disabled (not hidden). |
| FR-001c | UI: form CTA always visible on approved listings regardless of `phone`/`whatsapp`. |
| FR-001d | UI: signed-in publisher viewing own listing sees `SizedBox.shrink()` in place of CTAs. SQL: `submit_inquiry` RPC rejects when `auth.uid() = listing.publisher_user_id`. |
| FR-002 | Wire-level: after Call tap, `SELECT COUNT(*) FROM lead_events WHERE event_type='phone_revealed' AND listing_id=$1 AND created_at > now() - interval '5 seconds'` returns ≥ 1. |
| FR-003 | Manual: dialer opens with the publisher's phone pre-populated. |
| FR-004 | Wire-level: same as FR-002 but `whatsapp_clicked`. |
| FR-005 | Manual: WhatsApp opens (or `wa.me/` URL opens in browser). |
| FR-006 | UI: form rejects empty name/phone/message; rejects phone not matching E.164 regex; rejects message > 2000 chars. |
| FR-007 | UI: signed-in user opens form → name + phone pre-populated from `profiles.full_name` + `profiles.phone`. |
| FR-008 | UI: anonymous user opens form → fields empty, submission succeeds with `sender_user_id = NULL`. |
| FR-009 | SQL: simulate a failure mid-`submit_inquiry` body (e.g., `RAISE EXCEPTION` after the first INSERT) — verify zero rows in both tables. |
| FR-010 | SQL: `SELECT inquirer_phone_encrypted FROM inquiries LIMIT 1` returns BYTEA ciphertext; `pg_dump | grep -E '\+963[0-9]{9}'` returns zero matches. |
| FR-011 | UI: submit success → localized snackbar appears; navigation pops to listing details page. No in-app "my inquiries" entry visible to inquirer. |
| FR-012 | UI: invalid form inputs trigger field-level error labels; SELECT after attempted submit returns 0 rows. |
| FR-013 | SQL: `\d+ public.inquiries` shows all columns with correct constraints + indexes. |
| FR-014 | SQL: `\d+ public.lead_events` shows all columns with correct CHECK constraint. |
| FR-014a | Wire-level: after a `record_lead_event` call, `SELECT metadata FROM lead_events WHERE id = $1 [as admin]` returns `{ip: ..., user_agent: ...}` with non-null values. |
| FR-014b | Wire-level: publisher session `SELECT * FROM v_lead_events_publisher LIMIT 1` returns NO `metadata` column; admin session `SELECT metadata FROM v_lead_events_admin LIMIT 1` returns the IP+UA object. |
| FR-015 | SQL `EXPLAIN ANALYZE` on inbox + lead-events queries uses the partial indexes; query time < 50ms at 10k-row scale. |
| FR-016 | Manual: `submit_inquiry` invocations from the Flutter client INSERT both rows in one transaction; intercepting the second insert leaves the first uncommitted. |
| FR-017 | Same as FR-009. |
| FR-018 | SQL: `submit_inquiry` rejects when listing.status != 'approved'; `record_lead_event` rejects when listing.phone empty for `phone_revealed`. |
| FR-019 | UI: home AppBar action visible only when user has ≥ 1 approved listing. SQL: `SELECT COUNT(*) FROM listings WHERE publisher_user_id = auth.uid() AND status = 'approved'` matches the `canShowEntry` predicate. |
| FR-019a | UI: badge count matches `get_inbox_unread_count()` value; decrementing on `new → seen` is observed in real time. |
| FR-020 | UI: inbox row shows all required columns. |
| FR-021 | UI: opening detail page for `new`-status inquiry triggers `new → seen`; SELECT confirms persistence. |
| FR-021a | SQL: UPDATE attempting `closed → new` raises SQLSTATE 23514. |
| FR-021b | UI grep: no "Mark as spam" button in `inquiry_detail_page.dart` source. |
| FR-022 | Wire-level: cross-tenant SELECT returns 0 rows per the wire capture in `quickstart.md`. |
| FR-023 | Wire-level: non-authorized SELECT of `inquirer_phone_decrypted` via the view returns NULL. |
| FR-024 | SQL: UPDATE attempted from sender's session or anonymous session is rejected by RLS. |
| FR-024a | Manual: two-device race produces last-write-wins persisted state. |
| FR-025 | UI: status filter dropdown + per-listing filter dropdown both function. |
| FR-026 | SQL: corrupt the `inquirer_phone_encrypted` column for one row; UI renders that row with "Phone unavailable" without crashing. |
| FR-027..030 | Grep gates in `quickstart.md` for inline string literals + design-token violations. |
| FR-031 | `grep -RE 'flutter_phone_direct_caller|whatsapp_unilink' pubspec.yaml` returns zero matches. |
| FR-032 | `grep -RE 'firebase_messaging|fcm|amplitude|mixpanel' pubspec.yaml` returns zero matches. |
| FR-033 | `pg_dump | grep -i "<test phone>"` returns zero matches. |
| FR-034 | `grep -RE "user\\.role == 'admin'" lib/` returns zero matches. |
| FR-035 | `git diff` on `lib/features/listing_details/presentation/widgets/per_listing_action_block.dart` returns no changes. |

| SC | Verification path |
|----|-------------------|
| SC-001 | Stopwatch: Call CTA tap → dialer hand-off ≤ 1s; lead event row exists within ≤ 1s. |
| SC-002 | Same for WhatsApp. |
| SC-003 | Stopwatch: submit → success snackbar ≤ 2s; SQL fixture confirms exactly 1 inquiry + 1 lead_event row. |
| SC-004 | Wire-level capture (browser DevTools or a `curl` against the REST endpoint) of cross-tenant SELECT returns 0 rows for non-authorized readers. |
| SC-005 | `pg_dump --no-owner --no-acl postgres | grep -E '\+[1-9][0-9]{6,14}'` returns zero matches for any submitted test phone. |
| SC-006 | Two-publisher fixture wire-level test. |
| SC-007 | Direct `psql` as anon role → SELECT denied. |
| SC-008 | Admin session SELECT returns all publishers' inquiries with decrypted phone visible. |
| SC-009 | Manual: status change → kill app → relaunch → status persists. |
| SC-010 | Grep `pubspec.yaml` for `flutter_phone_direct_caller|firebase_messaging|amplitude|mixpanel|fcm|sentry` → zero matches. |
| SC-011 | Grep `lib/` for hardcoded role checks → zero matches. |
| SC-012 | Manual: empty-state copy renders in localized form. |
| SC-013 | Manual: 4-combination matrix (light/dark × ar/en) on Infinix Note 8 + Pixel 8 Pro AVD. |
| SC-014 | Manual: corrupt one ciphertext → inbox renders that row with "Phone unavailable" placeholder. |
| SC-015 | Direct SQL UPDATE from another publisher's session → 0 rows affected, RLS error. |
| SC-016 | Wire-level: publisher SELECT vs admin SELECT on `v_lead_events_publisher` / `v_lead_events_admin` returns different columns. |
| SC-017 | Manual: badge count matches `get_inbox_unread_count()` value; entry hidden for zero-approved-listing users. |
