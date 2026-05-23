# Contract: Moderation History Page (FR-017)

**Path**: `lib/features/publisher_dashboard/presentation/pages/listing_moderation_history_page.dart`
**Route**: `/publisher/listings/:id/moderation-history`
**Implements**: FR-017, US6 acceptance 3
**Verifies**: SC-014

## Route registration

```dart
GoRoute(
  path: '/publisher/listings/:id/moderation-history',
  pageBuilder: (ctx, state) => MaterialPage(
    child: ListingModerationHistoryPage(listingId: state.pathParameters['id']!),
  ),
  redirect: (ctx, state) async {
    final user = ctx.read<AuthCubit>().state.user;
    if (user == null) return '/login';
    // Owner-only access — verified server-side via Phase 10's RLS on
    // listing_status_history (publisher_user_id = auth.uid()).
    // Frontend does not need extra gating here.
    return null;
  },
),
```

## Data source contract

```dart
Future<List<ModerationHistoryEntry>> loadModerationHistory(String listingId) async {
  final rows = await client
    .from('listing_status_history')
    .select('id, previous_status, new_status, changed_at, reason')
    .eq('listing_id', listingId)
    .order('changed_at', ascending: true);

  return rows.map((row) {
    final raw = row['reason'] as String?;
    String? preset, detail;
    if (raw != null && raw.startsWith('{')) {
      try {
        final parsed = jsonDecode(raw) as Map<String, dynamic>;
        preset = parsed['preset'] as String?;
        detail = parsed['detail'] as String?;
      } catch (_) {
        // Defensive: malformed JSON → leave preset/detail null
      }
    }
    return ModerationHistoryEntry(
      id: row['id'] as String,
      previousStatus: ListingStatusX.fromKeyOrNull(row['previous_status'] as String?),
      newStatus: ListingStatusX.fromKey(row['new_status'] as String),
      changedAt: DateTime.parse(row['changed_at'] as String),
      rejectionPreset: preset == null ? null : RejectionReason.fromKey(preset),
      rejectionDetail: detail,
    );
  }).toList();
}
```

## Page layout

```text
┌────────────────────────────────────────────────────┐
│ AppBar: "Moderation history" + back               │
├────────────────────────────────────────────────────┤
│ Entry 1 (oldest)                                   │
│ ┌────────────────────────────────────────────────┐ │
│ │ Created → Draft                                │ │
│ │ 2026-04-12 14:30 • Admin team                  │ │
│ └────────────────────────────────────────────────┘ │
│ Entry 2                                            │
│ ┌────────────────────────────────────────────────┐ │
│ │ Draft → Pending review                         │ │
│ │ 2026-04-15 09:15 • Admin team                  │ │
│ └────────────────────────────────────────────────┘ │
│ Entry 3 (rejection)                                │
│ ┌────────────────────────────────────────────────┐ │
│ │ Pending review → Rejected                      │ │
│ │ 2026-04-16 11:00 • Admin team                  │ │
│ │                                                │ │
│ │ Photos missing or low quality                  │ │
│ │ > Main photo appears to be a stock image...    │ │
│ └────────────────────────────────────────────────┘ │
│ Entry 4                                            │
│ ┌────────────────────────────────────────────────┐ │
│ │ Rejected → Pending review                      │ │
│ │ 2026-04-18 16:45 • Admin team                  │ │
│ └────────────────────────────────────────────────┘ │
│ (chronological — oldest at top, newest at bottom) │
└────────────────────────────────────────────────────┘
```

## Status-transition labels (FR-018)

The page renders previous_status → new_status arcs using localized status labels. ARB keys: `publisher.history.status.{draft,pending_review,approved,rejected,paused,sold,rented,expired,deleted}`.

When `previous_status IS NULL` (initial draft creation row from `submit_listing` — wait, actually `submit_listing` writes `draft → pending_review`; the truly initial row is on listings INSERT which is `NULL → draft`), the rendering becomes `Created → Draft` per the ARB key `publisher.history.firstEntry`.

## Admin identity suppression (FR-017 + Constitution VIII)

The data-source query intentionally does NOT join to `profiles` for the `changed_by` column. Every entry displays "Admin team" via the ARB key `publisher.history.adminTeam` — NEVER the admin's actual name. This rule applies regardless of whether the publisher themselves coincidentally has admin permissions; the page is publisher-facing.

## Empty / loading states

- Loading: a `CircularProgressIndicator` centered in the body.
- Empty: cannot happen — Phase 10's listings INSERT trigger writes at least one row per listing. Defensive: render `AppLocalizations.of(context)!.publisherHistoryEmpty` if N=0.

## Performance

Typical N ≤ 5 history rows per listing. Page load under 800 ms per plan.md performance targets. No pagination needed.
