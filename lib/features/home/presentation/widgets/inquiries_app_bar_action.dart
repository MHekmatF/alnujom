// lib/features/home/presentation/widgets/inquiries_app_bar_action.dart
//
// Phase 16 Sub-Phase H (T079) — Home AppBar inbox action widget.
// Renders a badge-overlaid inbox icon for publishers with unread inquiries.
// Visibility is gated by [InquiriesUnreadState.canShowEntry] per FR-019.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../inquiries/presentation/bloc/inquiries_unread_cubit.dart';
import '../../../inquiries/presentation/widgets/unread_count_badge.dart';

/// AppBar action widget for the inquiries inbox.
///
/// - Hidden (`SizedBox.shrink`) when `!state.canShowEntry` — zero-approved-listing
///   publishers and anonymous users see nothing, matching Phase 15's home chrome.
/// - Shows `Icons.mark_email_unread_outlined` with a [UnreadCountBadge] when
///   `state.count > 0`; falls back to `Icons.inbox_outlined` when count is zero.
/// - Tapping navigates to [AppRoutes.inquiries].
///
/// The cubit is consumed via `getIt<InquiriesUnreadCubit>()` (lazySingleton)
/// rather than `context.read` so the same instance is shared with the
/// InquiryDetailBloc's decrement() side-effect path.
class InquiriesAppBarAction extends StatelessWidget {
  const InquiriesAppBarAction({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InquiriesUnreadCubit, InquiriesUnreadState>(
      bloc: getIt<InquiriesUnreadCubit>(),
      builder: (context, state) {
        if (!state.canShowEntry) return const SizedBox.shrink();

        final l10n = AppLocalizations.of(context)!;

        return Stack(
          alignment: AlignmentDirectional.center,
          children: [
            IconButton(
              tooltip: l10n.home_inquiries_action_tooltip,
              icon: Icon(
                state.count > 0
                    ? Icons.mark_email_unread_outlined
                    : Icons.inbox_outlined,
              ),
              onPressed: () => context.push(AppRoutes.inquiries),
            ),
            if (state.count > 0)
              Positioned(
                // Visual tuning: offset places badge in the upper-end corner of
                // the icon button's hit area (AppSpacing.xs = 4 dp).
                top: AppSpacing.xs,
                right: AppSpacing.xs,
                child: UnreadCountBadge(count: state.count),
              ),
          ],
        );
      },
    );
  }
}
