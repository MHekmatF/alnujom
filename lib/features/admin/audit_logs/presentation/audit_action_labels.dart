// Plan A33 — the audit log speaks the reader's language.
//
// `audit_logs.action` is a machine id, entity-dot-verb (`listing.approved`,
// `user_role.granted`), and `target_type` is a table name. The viewer used to
// print both raw on an Arabic-first admin screen. Every entity and verb the
// triggers can write has a label here; anything new falls back to the raw id
// rather than hiding, so a fresh trigger is visible before it is translated.
import '../../../../l10n/app_localizations.dart';

/// "entity: verb" (localized) for a known action id; the raw id otherwise.
String localizedAuditAction(AppLocalizations l10n, String action) {
  final dot = action.indexOf('.');
  if (dot <= 0 || dot == action.length - 1) return action;
  final entity = _entityLabel(l10n, action.substring(0, dot));
  final verb = _verbLabel(l10n, action.substring(dot + 1));
  if (entity == null || verb == null) return action;
  return '$entity: $verb';
}

/// A table name (`listings`, `user_roles`) as the thing it holds.
String localizedAuditTarget(AppLocalizations l10n, String targetType) {
  final entity = _entityLabel(l10n, _entityOfTable[targetType] ?? targetType);
  return entity ?? targetType;
}

const Map<String, String> _entityOfTable = {
  'account_approval_requests': 'account_approval',
  'ads': 'ad',
  'agencies': 'agency',
  'agency_members': 'agency_member',
  'agency_verification_requests': 'agency_verification',
  'app_settings': 'settings',
  'areas': 'area',
  'cities': 'city',
  'currencies': 'currency',
  'exchange_rates': 'exchange_rate',
  'governorates': 'governorate',
  'listing_media': 'listing_media',
  'listing_revisions': 'listing_revision',
  'listings': 'listing',
  'profiles': 'profile',
  'reports': 'report',
  'role_permissions': 'role_permission',
  'roles': 'role',
  'user_roles': 'user_role',
};

String? _entityLabel(AppLocalizations l10n, String entity) {
  return switch (entity) {
    'account_approval' => l10n.auditEntity_account_approval,
    'ad' => l10n.auditEntity_ad,
    'agency_member' => l10n.auditEntity_agency_member,
    'agency_verification' => l10n.auditEntity_agency_verification,
    'agency' => l10n.auditEntity_agency,
    'area' => l10n.auditEntity_area,
    'city' => l10n.auditEntity_city,
    'currency' => l10n.auditEntity_currency,
    'exchange_rate' => l10n.auditEntity_exchange_rate,
    'governorate' => l10n.auditEntity_governorate,
    'listing_media' => l10n.auditEntity_listing_media,
    'listing_revision' => l10n.auditEntity_listing_revision,
    'listing' => l10n.auditEntity_listing,
    'profile' => l10n.auditEntity_profile,
    'report' => l10n.auditEntity_report,
    'role_permission' => l10n.auditEntity_role_permission,
    'role' => l10n.auditEntity_role,
    'settings' => l10n.auditEntity_settings,
    'user_role' => l10n.auditEntity_user_role,
    _ => null,
  };
}

String? _verbLabel(AppLocalizations l10n, String verb) {
  return switch (verb) {
    'status_changed' => l10n.auditVerb_status_changed,
    'created' => l10n.auditVerb_created,
    'changed' => l10n.auditVerb_changed,
    'decided' => l10n.auditVerb_decided,
    'deleted' => l10n.auditVerb_deleted,
    'updated' => l10n.auditVerb_updated,
    'applied' => l10n.auditVerb_applied,
    'withdrawn' => l10n.auditVerb_withdrawn,
    'approved' => l10n.auditVerb_approved,
    'paused' => l10n.auditVerb_paused,
    'rejected' => l10n.auditVerb_rejected,
    'submitted' => l10n.auditVerb_submitted,
    'resolved' => l10n.auditVerb_resolved,
    'granted' => l10n.auditVerb_granted,
    'revoked' => l10n.auditVerb_revoked,
    'sold' => l10n.auditVerb_sold,
    'rented' => l10n.auditVerb_rented,
    'expired' => l10n.auditVerb_expired,
    _ => null,
  };
}
