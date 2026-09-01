// Phase 25 premium uplift v2 — role-aware dashboard entry.
//
// A thin routing surface behind the `/dashboard` route + the Profile-menu
// "Dashboard" entry. It decides — based on the cached permission set and the
// loaded profile's publisher status — which concrete dashboard to show:
//
//   • holds any admin-category permission           → admin console (/admin)
//   • else publisher_status == approved             → publisher dashboard
//   • else                                          → a gentle "no dashboard"
//                                                     empty state
//
// The decision is read from already-available session state (PermissionChecker
// is populated at sign-in; the profile via the shared ProfileCubit), so this
// adds no new datasource. Behaviour-preserving: it only redirects to existing
// surfaces.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/security/permission_checker.dart';
import '../../../../core/security/permission_keys.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/domain/value_objects/publisher_status.dart';
import '../../../admin/presentation/pages/admin_home_page.dart';
import '../../../profile/presentation/cubit/profile_cubit.dart';
import '../../../profile/presentation/cubit/profile_state.dart';
import '../../../publisher_dashboard/presentation/pages/publisher_dashboard_page.dart';

class DashboardEntryPage extends StatelessWidget {
  const DashboardEntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final checker = getIt<PermissionChecker>();

    // Admins resolve immediately from the cached permission set — no profile
    // round-trip needed.
    if (checker.any(PermissionKeys.adminCategoryKeys)) {
      return const AdminHomePage();
    }

    // Publishers need the loaded profile to read publisher_status.
    return BlocProvider<ProfileCubit>(
      create: (_) => getIt<ProfileCubit>()..load(),
      child: const _PublisherOrEmpty(),
    );
  }
}

class _PublisherOrEmpty extends StatelessWidget {
  const _PublisherOrEmpty();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Batch-2: this was the only internal surface still on a bare
    // Scaffold+AppBar, so it landed on a plain white bar between two blue-crown
    // screens (the admin console it forwards to, and the profile drawer it is
    // opened from). Both branches now use the DS DcCrownScaffold with the same
    // back affordance AdminHomePage uses.
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        if (state.status == ProfileStatus.loading ||
            state.status == ProfileStatus.initial) {
          return DcCrownScaffold(
            title: l10n.dashboardEntryTitle,
            dense: true,
            leading: DcCrownIconButton(
              icon: Icons.arrow_forward,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            body: const AppSpinner.page(),
          );
        }

        final isApprovedPublisher =
            state.profile?.publisherStatus == PublisherStatus.approved;
        if (isApprovedPublisher) {
          return const PublisherDashboardPage();
        }

        return DcCrownScaffold(
          title: l10n.dashboardEntryTitle,
          dense: true,
          leading: DcCrownIconButton(
            icon: Icons.arrow_forward,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          body: EmptyState(
            icon: LucideIcons.layout_dashboard,
            headline: l10n.dashboardEntryEmptyTitle,
            body: l10n.dashboardEntryEmptyBody,
          ),
        );
      },
    );
  }
}
