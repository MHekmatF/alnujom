import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/domain/value_objects/account_status.dart';
import '../../shared/domain/value_objects/publisher_status.dart';
import '../routing/app_router.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Phase 035 — the "أضف عقار / Publish" action, now a floating Extended FAB that
/// sits above the [MainBottomNav] on every primary tab surface (matching the
/// design system §9 — a 52px blue pill with an `add_home` icon + label).
///
/// Self-gating: it renders nothing unless the signed-in user is an approved
/// publisher (account + publisher status both approved), so tab hosts can mount
/// `floatingActionButton: const PublishFab()` unconditionally. Tapping pushes
/// the create-listing flow over the current tab (it is never a nav destination).
class PublishFab extends StatelessWidget {
  const PublishFab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final isApprovedPublisher =
            authState is Authenticated &&
            authState.profile.accountStatus == AccountStatus.approved &&
            authState.profile.publisherStatus == PublisherStatus.approved;

        if (!isApprovedPublisher) return const SizedBox.shrink();

        return FloatingActionButton.extended(
          onPressed: () =>
              context.pushNamed(AppRouteNames.publisherListingsCreate),
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          icon: const Icon(Icons.add_home_rounded),
          label: Text(
            l10n.nav_publish,
            style: styles.labelLarge.copyWith(
              color: colors.onPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      },
    );
  }
}
