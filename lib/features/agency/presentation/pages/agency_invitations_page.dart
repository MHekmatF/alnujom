// lib/features/agency/presentation/pages/agency_invitations_page.dart
//
// Spec 019 B-4 / spec 022 §6 — the agency-invitation deep-link target.
//
// The `agency_invitation` notification used to route to the `/agency` hub,
// whose DEFAULT branch is the "create an agency" form: any read that came back
// empty — most often because the deep link fired before the Supabase session
// had been restored on a cold start — dropped the invitee on the create form
// with no path to Accept. This screen only ever renders invitations, so that
// dead-end cannot recur, and it re-loads once auth settles.
//
// Backed entirely by existing plumbing: AgencyInvitationsCubit →
// LoadMyAgencyInvitations / RespondAgencyInvitation → `agency_members` +
// `respond_agency_invitation` RPC. No new SQL.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../bloc/agency_invitations_cubit.dart';

class AgencyInvitationsPage extends StatelessWidget {
  const AgencyInvitationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AgencyInvitationsCubit>(
      create: (_) => getIt<AgencyInvitationsCubit>()..load(),
      child: const _AgencyInvitationsView(),
    );
  }
}

class _AgencyInvitationsView extends StatelessWidget {
  const _AgencyInvitationsView();

  /// Answers one invitation and reacts to the OUTCOME (the RPC result used to
  /// be discarded): a failure shows an error instead of silently re-rendering
  /// the same card, and a successful Accept hands the user to the agency hub —
  /// they are an ACTIVE member now, so it resolves to the management surface.
  ///
  /// Lives HERE rather than on the list widget because answering the last
  /// invitation swaps the list for the empty state: the list's element is then
  /// unmounted and `context.mounted` would be false, silently skipping both the
  /// toast and the navigation. This element outlives every cubit state change.
  Future<void> _respond(
    BuildContext context,
    AgencyInvitation invite, {
    required bool accept,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await context.read<AgencyInvitationsCubit>().respond(
      agencyId: invite.membership.agencyId,
      accept: accept,
    );
    if (!context.mounted) return;
    if (result is FailureResult<void>) {
      AppToast.error(context, l10n.agency_action_failed);
      return;
    }
    if (accept) context.go(AppRoutes.agency);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Cold-start deep link: the push listener navigates from a post-frame
    // callback, which can beat Supabase's session restore. The first load()
    // then reads as anonymous and returns an empty list. Re-load the moment
    // AuthBloc leaves [Authenticating] so the invitation self-heals into view
    // instead of leaving a permanent "no invitations" screen.
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (prev, curr) =>
          prev is Authenticating && curr is! Authenticating,
      listener: (context, _) => context.read<AgencyInvitationsCubit>().load(),
      child: BlocBuilder<AgencyInvitationsCubit, AgencyInvitationsState>(
        builder: (context, state) {
          return DcCrownScaffold(
            dense: true,
            title: l10n.agency_invitations_title,
            leading: DcCrownIconButton(
              icon: Icons.arrow_forward,
              onTap: () =>
                  context.canPop() ? context.pop() : context.go(AppRoutes.home),
            ),
            body: switch (state) {
              AgencyInvitationsLoading() => const AppSpinner.page(),
              AgencyInvitationsError() => EmptyState(
                icon: LucideIcons.circle_alert,
                headline: l10n.agency_generic_error,
                ctaLabel: l10n.action_retry,
                onCtaPressed: () =>
                    context.read<AgencyInvitationsCubit>().load(),
              ),
              AgencyInvitationsLoaded(:final invitations)
                  when invitations.isEmpty =>
                EmptyState(
                  icon: LucideIcons.mail_open,
                  headline: l10n.agency_invitations_empty,
                  ctaLabel: l10n.agency_profile_title,
                  onCtaPressed: () => context.go(AppRoutes.agency),
                ),
              AgencyInvitationsLoaded(:final invitations, :final responding) =>
                _InvitationList(
                  invitations: invitations,
                  responding: responding,
                  onRespond: (invite, accept) =>
                      _respond(context, invite, accept: accept),
                ),
            },
          );
        },
      ),
    );
  }
}

class _InvitationList extends StatelessWidget {
  const _InvitationList({
    required this.invitations,
    required this.responding,
    required this.onRespond,
  });

  final List<AgencyInvitation> invitations;
  final bool responding;

  /// `(invitation, accept)` — owned by the page so it survives this list being
  /// swapped for the empty state when the last invitation is answered.
  final void Function(AgencyInvitation invite, bool accept) onRespond;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        Text(
          l10n.agency_invitations_page_intro,
          style: styles.bodyMedium.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final invite in invitations)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: AppSurface(
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.agency_invitation_pending_from(
                      // Never show the raw agency UUID: `v_agencies` hides a
                      // not-yet-approved agency from a PENDING invitee.
                      invite.agencyName ??
                          l10n.agency_invitation_unnamed_agency,
                    ),
                    style: styles.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AppButton(
                        label: l10n.agency_invitation_decline,
                        variant: AppButtonVariant.text,
                        size: AppButtonSize.dense,
                        onPressed: responding
                            ? null
                            : () => onRespond(invite, false),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppButton(
                        label: l10n.agency_invitation_accept,
                        size: AppButtonSize.dense,
                        onPressed: responding
                            ? null
                            : () => onRespond(invite, true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
