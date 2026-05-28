# Contract — Home AppBar inbox action widget

**Owner**: Sub-Phase H (`lib/features/home/presentation/widgets/inquiries_app_bar_action.dart` + the home page edit in `lib/features/home/presentation/pages/home_page.dart`).

**Consumers**: the home page's `AppBar.actions:` slot.

## Placement

The action is inserted into `AppBar.actions:` between the existing `LocaleToggleAction` (currently `actions[0]`) and the existing sign-in/profile `IconButton` (currently `actions[1]`). After Phase 16: `actions[0]` = LocaleToggleAction; `actions[1]` = InquiriesAppBarAction; `actions[2]` = sign-in/profile.

## Widget composition

```dart
class InquiriesAppBarAction extends StatelessWidget {
  const InquiriesAppBarAction({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InquiriesUnreadCubit, InquiriesUnreadState>(
      builder: (context, state) {
        if (!state.canShowEntry) return const SizedBox.shrink();
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              tooltip: l10n.home_inquiries_action_tooltip,
              icon: Icon(state.count > 0
                ? Icons.mark_email_unread_outlined
                : Icons.inbox_outlined),
              onPressed: () => context.push(AppRoutes.inquiries),
            ),
            if (state.count > 0)
              Positioned(
                top: AppSpacing.xs,
                end: AppSpacing.xs,
                child: UnreadCountBadge(count: state.count),
              ),
          ],
        );
      },
    );
  }
}
```

## Visibility gate

`InquiriesUnreadState.canShowEntry` is true only when the signed-in user owns ≥ 1 approved listing. Computed by `InquiriesUnreadCubit` on construction via a one-time `SELECT COUNT(*) FROM listings WHERE publisher_user_id = auth.uid() AND status = 'approved'` (or by piggy-backing on the existing `MyListingsPage` query result if already cached). Anonymous users and zero-approved-listing users see `SizedBox.shrink()` per FR-019.

## Lifecycle refresh

`HomePage`'s `State.initState` registers an `AppLifecycleListener` that calls `getIt<InquiriesUnreadCubit>().refresh()` on `AppLifecycleState.resumed` per FR-019a. The cubit's `refresh()` re-fetches both `canShowEntry` and `count`.

## Real-time decrement

The `InquiryDetailBloc` emits a side-effect call to `InquiriesUnreadCubit.decrement()` immediately after a successful `new → seen` transition; the badge updates in real-time on the home AppBar (which is still alive in the navigation stack underneath the detail page).

## Pre-conditions

- `InquiriesUnreadCubit` is registered as `@lazySingleton` so the home action and the detail bloc share the same instance.
- `AppRoutes.inquiries` exists (Sub-Phase A).
- `get_inbox_unread_count` RPC exists (Sub-Phase D).

## Post-conditions

- For users with ≥ 1 approved listing AND ≥ 1 new inquiry: the icon renders with the unread-mail variant + badge showing count.
- For users with ≥ 1 approved listing AND zero new inquiries: the icon renders with the inbox variant + NO badge.
- For users with zero approved listings: no icon renders at all (the home page chrome looks unchanged from Phase 15 for non-publishers).

## Stability surface

**Frozen**: the visibility-gate predicate (≥ 1 approved listing); the badge-decrement-on-`new→seen` rule.

**Allowed**: visual treatment changes (icon choice, badge color, placement within the AppBar actions list).
