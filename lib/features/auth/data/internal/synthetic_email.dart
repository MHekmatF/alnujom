// Phase 5 FR-015 — synthetic email helper.
// Package-private: NOT exported from any barrel file. Only the auth feature's
// data layer (and the Edge Function's TS counterpart) construct synthetic emails.
//
// Format: `<E.164 phone>@alnujom.local` — the Dart and TS implementations agree.

import '../../../../shared/domain/value_objects/phone_number.dart';

const String _syntheticEmailDomain = 'alnujom.local';

String syntheticEmailFor(PhoneNumber phone) =>
    '${phone.e164}@$_syntheticEmailDomain';
