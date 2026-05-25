# Contract — Admin inquiry oversight overlay

**Owner**: Sub-Phase F (`lib/features/inquiries/presentation/pages/admin_inquiry_oversight_page.dart`).

**Consumers**: the route `/admin/inquiries` registered in Sub-Phase A; future Phase 20 admin dashboard tile.

## Reuse pattern (R-106)

The admin oversight page is a thin wrapper around `InquiryInboxPage`. It does NOT introduce a separate page tree, separate BLoC class, or separate data path. It differs from the publisher inbox in three ways:

1. The route guard requires `inquiries.view_all` permission (Sub-Phase A's `redirect`).
2. The `InquiryInboxBloc` is constructed with a `tier: AdminTier()` parameter that causes its data path to bypass the publisher-ownership filter (the RLS `inquiries_select_admin` policy unlocks cross-publisher reads).
3. A `AdminTierBanner` widget renders at the top of the body, visually distinguishing this view from the publisher inbox.
4. An additional `PublisherFilterDropdown` appears in the AppBar actions slot, allowing the admin to filter by a specific publisher.

## Widget composition

```text
Scaffold
├── AppBar
│   ├── leading: DeepLinkAwareBackButton
│   ├── title: l10n.admin_inquiries_app_bar_title
│   └── actions: [
│         StatusFilterDropdown (reused),
│         ListingFilterDropdown (reused),
│         PublisherFilterDropdown (admin-only),
│       ]
└── body: Column
        ├── AdminTierBanner (l10n.admin_inquiries_tier_banner)
        └── [the existing inbox body widget tree from InquiryInboxPage]
```

## Route guard

```dart
GoRoute(
  path: AppRoutes.adminInquiries,
  builder: (_, __) => const AdminInquiryOversightPage(),
  redirect: (context, state) async {
    final canView = await getIt<PermissionChecker>().has('inquiries.view_all');
    return canView ? null : AppRoutes.home;
  },
),
```

Per Constitution Principle VII: no hardcoded role check; the gate is the permission key.

## Data path

`InquiryInboxBloc(tier: AdminTier())` → `LoadInquiryInbox(tier: AdminTier(), ...)` → `InquiryRepositoryImpl.loadInbox(...)` → the same `v_inquiries_inbox` view query, but RLS unlocks cross-publisher rows because the caller satisfies `inquiries_select_admin`.

## Pre-conditions

- Caller is signed-in.
- Caller holds the `inquiries.view_all` permission (per the Phase 6 default-mapping: any role in the `admin` family).

## Post-conditions

- Authorized admin sees every inquiry across every publisher with the decrypted callback phone visible.
- Unauthorized user is redirected to home before the page even mounts.
- Manual SQL UPDATE attempts from this page are still subject to the `inquiries_update_publisher` RLS policy — admins cannot UPDATE an inquiry's status (only the publisher can per FR-024); Phase 16 ships no admin-side status-mutation UX.

## Stability surface

**Frozen**: the permission-gate predicate (`inquiries.view_all`); the read-only nature of the admin view.

**Allowed**: adding admin-side write paths in a future moderation phase (e.g., Phase 18 may add a `spam_mark_admin` policy + UX) — provided the publisher's UPDATE pathway is preserved.
