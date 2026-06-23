import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/domain/value_objects/account_status.dart';
import '../../../../shared/domain/value_objects/publisher_status.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_state.dart';
import '../widgets/auth_status_message.dart';

/// Phase 5 publisher-approval-pending page. Phase 10 R-19 added the
/// auto-route-out BlocListener: when an admin approves the publisher mid-
/// session (SC-020), the AuthBloc.AppResumedRefresh handler re-fetches the
/// profile and emits a new Authenticated state. This page listens for that
/// transition and routes the user back to /home so the "Create listing"
/// tile becomes accessible without a sign-out cycle.
class PublisherApprovalPendingPage extends StatelessWidget {
  const PublisherApprovalPendingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (prev, curr) {
        final pp = prev is Authenticated ? prev.profile.publisherStatus : null;
        final cp = curr is Authenticated ? curr.profile.publisherStatus : null;
        return pp != cp;
      },
      listener: (context, state) {
        if (state is Authenticated &&
            state.profile.accountStatus == AccountStatus.approved &&
            state.profile.publisherStatus == PublisherStatus.approved) {
          context.go(AppRoutes.shellHome);
        }
      },
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          backgroundColor: colors.surface,
          elevation: 0,
          title: Text(l10n.publisherApprovalPendingTitle),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
            child: AuthStatusMessage(
              icon: LucideIcons.badge_check,
              title: l10n.publisherApprovalPendingTitle,
              message: l10n.publisherApprovalPendingMessage,
            ),
          ),
        ),
      ),
    );
  }
}
