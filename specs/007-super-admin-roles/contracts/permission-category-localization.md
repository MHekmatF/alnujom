# Contract: Permission-Category Localization

**Owner**: Phase 7 (`lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb`, `lib/features/super_admin/presentation/widgets/permission_category_header.dart`).
**Consumers**: `RoleEditorPage`, `CreateRolePage`, anywhere the permission catalog is grouped for display.
**Stability**: ARB key scheme is stable for v1; new keys append for future categories.

---

## Purpose

Defines the localization scheme for the permission-category headings used by the Phase 7 permission checklist. Per Clarifications Q6 / R-09, the headings are ARB-keyed app-side; the `permissions.category TEXT` column from Phase 6 stays unchanged.

## ARB key scheme

For each value of `permissions.category` (a stable TEXT identifier), the corresponding ARB key follows the transform:

```
permissionCategory<Capitalized>(category)
```

where `<Capitalized>(category)` is the first letter capitalized form (e.g., `users` → `Users`, `audit` → `Audit`).

## Inventory (12 keys)

| `permissions.category` value | ARB key | `ar` value | `en` value |
|---|---|---|---|
| `users` | `permissionCategoryUsers` | المستخدمون | Users |
| `listings` | `permissionCategoryListings` | العقارات | Listings |
| `roles` | `permissionCategoryRoles` | الأدوار | Roles |
| `locations` | `permissionCategoryLocations` | المواقع | Locations |
| `currencies` | `permissionCategoryCurrencies` | العملات | Currencies |
| `ads` | `permissionCategoryAds` | الإعلانات | Ads |
| `reports` | `permissionCategoryReports` | البلاغات | Reports |
| `agencies` | `permissionCategoryAgencies` | الوكالات | Agencies |
| `settings` | `permissionCategorySettings` | الإعدادات | Settings |
| `audit` | `permissionCategoryAudit` | سجل التدقيق | Audit log |
| `inquiries` | `permissionCategoryInquiries` | الاستفسارات | Inquiries |
| `permissions` | `permissionCategoryPermissions` | الصلاحيات | Permissions |

Both ARB files MUST contain all 12 keys with non-empty values; missing entries are caught by the Phase 3 lint guard at PR review.

## Widget implementation

`lib/features/super_admin/presentation/widgets/permission_category_header.dart`:

```dart
class PermissionCategoryHeader extends StatelessWidget {
  final String category;  // e.g., 'users'

  String _resolveLocalized(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (category) {
      case 'users': return l10n.permissionCategoryUsers;
      case 'listings': return l10n.permissionCategoryListings;
      case 'roles': return l10n.permissionCategoryRoles;
      case 'locations': return l10n.permissionCategoryLocations;
      case 'currencies': return l10n.permissionCategoryCurrencies;
      case 'ads': return l10n.permissionCategoryAds;
      case 'reports': return l10n.permissionCategoryReports;
      case 'agencies': return l10n.permissionCategoryAgencies;
      case 'settings': return l10n.permissionCategorySettings;
      case 'audit': return l10n.permissionCategoryAudit;
      case 'inquiries': return l10n.permissionCategoryInquiries;
      case 'permissions': return l10n.permissionCategoryPermissions;
      default: return category;  // fallback for unknown future category (lint guard catches missing ARB)
    }
  }
  ...
}
```

The widget consumes Phase 2 typography tokens (`Theme.of(context).textTheme.titleMedium` or equivalent) for the heading style. No inline `TextStyle` literals.

## Fallback rule

If `permissions.category` has a value not handled by the switch (e.g., a future migration adds a new category but Phase 7's widget hasn't been updated), the widget renders the raw `category` string. This is a graceful degradation — the user sees the unlocalized label instead of a blank or a crash. The Phase 3 lint guard catches the missing ARB entry at PR review (the new category MUST be added to `permission_keys.dart` AND to `permission_category_header.dart`'s switch AND to both ARB files in the same PR).

## Future-extensibility

When a future spec adds a new permission category (e.g., Phase 19 adds `agencies.assign_member` whose category is `agencies` — already handled — but a hypothetical future `payments` category would be new):

1. Add `permissionCategoryPayments` to both `app_ar.arb` and `app_en.arb`.
2. Add the `case 'payments':` branch to `_resolveLocalized()`.
3. The same PR includes the migration that INSERTs the new permission keys into `permissions` with the new category.

The Phase 3 lint guard ensures the ARB keys exist; PR review ensures the switch branch was added.

## Why not store the localized labels in the DB?

Considered (R-09 Option B); rejected because:

- Requires a schema migration on `permissions` (adds a JSONB column or per-row text columns).
- Couples translation workflow to DB seed updates (a translator can't update a label without a migration).
- Misses the Phase 3 translation pipeline (translators only see ARB files).

The Phase 7 stance (Option A — ARB keys) keeps the Phase 6 catalog schema clean.

## Verification

```bash
# 1. Both ARB files contain all 12 keys
grep -c "permissionCategory" lib/l10n/app_ar.arb lib/l10n/app_en.arb
# Expected: each file shows 12 matches.

# 2. The switch in permission_category_header.dart covers all 12 values
grep "case '" lib/features/super_admin/presentation/widgets/permission_category_header.dart | wc -l
# Expected: 12.
```

Manual UI walk:

1. Open `RoleEditorPage` for the `admin` role.
2. Confirm each category heading is rendered in Arabic (default device locale).
3. Toggle device locale to English. Confirm headings re-render in English.
4. Confirm there are exactly 12 distinct headings (one per category present in `admin`'s permissions; in admin's case all 11 of users/listings/locations/currencies/ads/reports/agencies/audit/inquiries categories are present; the editor also shows empty categories that admin doesn't have, depending on the implementation choice — the recommended choice is to show ONLY categories that have at least one permission visible to the active role).

## Forward references

- The Phase 6 `permission_keys.dart` is the source of truth for the 24 permission KEYS. The 12 category headings are the source of truth for category LABELS. The two are independent; a permission key like `currencies.manage` carries `category = 'currencies'`; its label comes from `permissionCategoryCurrencies`.
- If translation workflow needs to be opened up to non-developers in a future phase, consider a Crowdin-style integration on the ARB files; the contract here stays the same.
