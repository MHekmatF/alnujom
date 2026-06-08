// lib/features/agency/presentation/pages/agency_members_page.dart
//
// Phase 19 (spec/019-agencies) Sub-Phase H (T056).
// Roster (AgencyMembersBloc) + invite sheet + pending-invitations strip
// (AgencyInvitationsCubit) + role-toggle/remove. The owner row is protected.
// Phase 2 tokens only; all strings via AppLocalizations.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/deep_link_aware_back_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/agency.dart';
import '../../domain/entities/agency_member.dart';
import '../bloc/agency_invitations_cubit.dart';
import '../bloc/agency_members_bloc.dart';
import '../widgets/agency_member_tile.dart';
import '../widgets/invite_member_sheet.dart';

class AgencyMembersPage extends StatelessWidget {
  const AgencyMembersPage({super.key, required this.agency});

  final Agency agency;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AgencyMembersBloc>(
          create: (_) => getIt<AgencyMembersBloc>()
            ..add(AgencyMembersOpened(agency.id)),
        ),
        BlocProvider<AgencyInvitationsCubit>(
          create: (_) => getIt<AgencyInvitationsCubit>()..load(),
        ),
      ],
      child: _AgencyMembersView(agency: agency),
    );
  }
}

class _AgencyMembersView extends StatelessWidget {
  const _AgencyMembersView({required this.agency});

  final Agency agency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: const DeepLinkAwareBackButton(),
        title: Text(l10n.agency_members_title),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showInviteMemberSheet(
          context,
          bloc: context.read<AgencyMembersBloc>(),
          agencyId: agency.id,
        ),
        icon: const Icon(Icons.person_add_outlined),
        label: Text(l10n.agency_invite_button),
      ),
      body: BlocBuilder<AgencyMembersBloc, AgencyMembersState>(
        builder: (context, state) {
          return switch (state) {
            AgencyMembersLoading() =>
              const Center(child: CircularProgressIndicator()),
            AgencyMembersError() =>
              Center(child: Text(l10n.agency_generic_error)),
            AgencyMembersLoaded(:final members) => _Roster(
                agency: agency,
                members: members,
              ),
          };
        },
      ),
    );
  }
}

class _Roster extends StatelessWidget {
  const _Roster({required this.agency, required this.members});

  final Agency agency;
  final List<AgencyMember> members;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsetsDirectional.only(
        bottom: AppSpacing.xxxl + AppSpacing.xxxl,
      ),
      children: [
        // Pending invitations the CURRENT user received (across agencies).
        const _PendingInvitations(),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Text(
            l10n.agency_members_title,
            style: theme.textTheme.titleMedium,
          ),
        ),
        if (members.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              l10n.agency_members_empty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final member in members)
            AgencyMemberTile(
              member: member,
              isOwner: member.userId == agency.ownerUserId,
              canManage: true,
              onRoleToggle: (role) => context.read<AgencyMembersBloc>().add(
                    AgencyMembersRoleChangeRequested(
                      agencyId: agency.id,
                      userId: member.userId,
                      role: role,
                    ),
                  ),
              onRemove: () => _confirmRemove(context, agency.id, member.userId),
            ),
      ],
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    String agencyId,
    String userId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final bloc = context.read<AgencyMembersBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.agency_member_remove),
        content: Text(l10n.agency_member_remove_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.agency_cancel_button),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.agency_member_remove),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      bloc.add(
        AgencyMembersRemoveRequested(agencyId: agencyId, userId: userId),
      );
    }
  }
}

class _PendingInvitations extends StatelessWidget {
  const _PendingInvitations();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return BlocBuilder<AgencyInvitationsCubit, AgencyInvitationsState>(
      builder: (context, state) {
        if (state is! AgencyInvitationsLoaded || state.invitations.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                l10n.agency_invitations_title,
                style: theme.textTheme.titleMedium,
              ),
            ),
            for (final invite in state.invitations)
              Card(
                margin: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.agency_invitation_pending_from(invite.agencyName),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: state.responding
                            ? null
                            : () => context.read<AgencyInvitationsCubit>().respond(
                                  agencyId: invite.membership.agencyId,
                                  accept: false,
                                ),
                        child: Text(l10n.agency_invitation_decline),
                      ),
                      FilledButton(
                        onPressed: state.responding
                            ? null
                            : () => context.read<AgencyInvitationsCubit>().respond(
                                  agencyId: invite.membership.agencyId,
                                  accept: true,
                                ),
                        child: Text(l10n.agency_invitation_accept),
                      ),
                    ],
                  ),
                ),
              ),
            const Divider(height: AppSpacing.xl),
          ],
        );
      },
    );
  }
}
