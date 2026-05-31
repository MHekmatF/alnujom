// lib/features/agency/presentation/pages/agency_home_page.dart
//
// Phase 19 (spec/019-agencies) Sub-Phase H (T054).
// Replaces the Phase-1 stub. None → "Create agency" form; owner/member →
// management surface (status chip + links to members/listings/analytics/verify).
// Phase 2 tokens only; all strings via AppLocalizations (Constitution V/VI).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/agency.dart';
import '../bloc/agency_home_cubit.dart';
import '../bloc/agency_invitations_cubit.dart' show AgencyInvitation;
import '../widgets/agency_status_chip.dart';

class AgencyHomePage extends StatelessWidget {
  const AgencyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AgencyHomeCubit>(
      create: (_) => getIt<AgencyHomeCubit>()..load(),
      child: const _AgencyHomeView(),
    );
  }
}

class _AgencyHomeView extends StatelessWidget {
  const _AgencyHomeView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocConsumer<AgencyHomeCubit, AgencyHomeState>(
      listenWhen: (prev, curr) => curr is AgencyHomeCreateFailure,
      listener: (context, state) {
        if (state is AgencyHomeCreateFailure) {
          final message = switch (state.messageKey) {
            'not_a_publisher' => l10n.agency_create_not_publisher,
            'already_owns_agency' => l10n.agency_already_owns,
            _ => l10n.agency_action_failed,
          };
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(switch (state) {
              AgencyHomeNone() ||
              AgencyHomeCreating() ||
              AgencyHomeCreateFailure() =>
                l10n.agency_create_title,
              AgencyHomeInvited() => l10n.agency_invitations_title,
              _ => l10n.agency_profile_title,
            }),
          ),
          body: switch (state) {
            AgencyHomeLoading() =>
              const Center(child: CircularProgressIndicator()),
            AgencyHomeError() => Center(child: Text(l10n.agency_generic_error)),
            AgencyHomeNone() ||
            AgencyHomeCreating() ||
            AgencyHomeCreateFailure() =>
              _CreateAgencyForm(submitting: state is AgencyHomeCreating),
            AgencyHomeInvited(:final invitations, :final responding) =>
              _InvitedView(invitations: invitations, responding: responding),
            AgencyHomeOwner(:final agency) =>
              _ManagementSurface(agency: agency, isOwner: true),
            AgencyHomeMember(:final agency) =>
              _ManagementSurface(agency: agency, isOwner: false),
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Create-agency form (no agency yet)
// ---------------------------------------------------------------------------

class _CreateAgencyForm extends StatefulWidget {
  const _CreateAgencyForm({required this.submitting});

  final bool submitting;

  @override
  State<_CreateAgencyForm> createState() => _CreateAgencyFormState();
}

class _CreateAgencyFormState extends State<_CreateAgencyForm> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.agency_no_agency_message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Field(controller: _nameController, label: l10n.agency_name_label),
          const SizedBox(height: AppSpacing.md),
          _Field(
            controller: _descriptionController,
            label: l10n.agency_description_label,
            hint: l10n.agency_create_description_hint,
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.md),
          _Field(
            controller: _phoneController,
            label: l10n.agency_phone_label,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSpacing.md),
          _Field(
            controller: _whatsappController,
            label: l10n.agency_whatsapp_label,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSpacing.md),
          _Field(controller: _addressController, label: l10n.agency_address_label),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: widget.submitting ? null : _submit,
            child: widget.submitting
                ? const SizedBox(
                    width: AppSpacing.lg,
                    height: AppSpacing.lg,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.agency_create_button),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    String? trimmedOrNull(TextEditingController c) {
      final v = c.text.trim();
      return v.isEmpty ? null : v;
    }

    context.read<AgencyHomeCubit>().create(
          name: name,
          description: trimmedOrNull(_descriptionController),
          phone: trimmedOrNull(_phoneController),
          whatsapp: trimmedOrNull(_whatsappController),
          address: trimmedOrNull(_addressController),
        );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Invited view (pending invitation(s), not yet a member) — B-4 fix
// ---------------------------------------------------------------------------

class _InvitedView extends StatelessWidget {
  const _InvitedView({required this.invitations, required this.responding});

  final List<AgencyInvitation> invitations;
  final bool responding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cubit = context.read<AgencyHomeCubit>();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(l10n.agency_invitations_title, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final invite in invitations)
          Card(
            margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
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
                    onPressed: responding
                        ? null
                        : () => cubit.respondInvitation(
                              agencyId: invite.membership.agencyId,
                              accept: false,
                            ),
                    child: Text(l10n.agency_invitation_decline),
                  ),
                  FilledButton(
                    onPressed: responding
                        ? null
                        : () => cubit.respondInvitation(
                              agencyId: invite.membership.agencyId,
                              accept: true,
                            ),
                    child: Text(l10n.agency_invitation_accept),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Management surface (owner / member)
// ---------------------------------------------------------------------------

class _ManagementSurface extends StatelessWidget {
  const _ManagementSurface({required this.agency, required this.isOwner});

  final Agency agency;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(agency.name, style: theme.textTheme.headlineSmall),
            ),
            const SizedBox(width: AppSpacing.sm),
            AgencyStatusChip(agency.status),
          ],
        ),
        if (agency.description != null &&
            agency.description!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            agency.description!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _ManageTile(
          icon: Icons.group_outlined,
          label: l10n.agency_manage_members,
          onTap: () => context.push(
            AppRoutes.agencyMembers,
            extra: agency,
          ),
        ),
        _ManageTile(
          icon: Icons.list_alt_outlined,
          label: l10n.agency_manage_listings,
          onTap: () => context.push(
            AppRoutes.agencyListings,
            extra: agency.id,
          ),
        ),
        _ManageTile(
          icon: Icons.bar_chart_outlined,
          label: l10n.agency_manage_analytics,
          onTap: () => context.push(
            AppRoutes.agencyAnalytics,
            extra: agency.id,
          ),
        ),
        if (isOwner)
          _ManageTile(
            icon: Icons.edit_outlined,
            label: l10n.agency_edit_button,
            onTap: () async {
              final changed =
                  await context.push<bool>(AppRoutes.agencyEdit);
              if (changed == true && context.mounted) {
                await context.read<AgencyHomeCubit>().load();
              }
            },
          ),
        if (isOwner)
          _ManageTile(
            icon: Icons.verified_outlined,
            label: l10n.agency_manage_verify,
            onTap: () => context.push(
              AppRoutes.agencyVerify,
              extra: agency.id,
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: Text(l10n.agency_profile_title),
          onPressed: () => context.push('/agency/${agency.id}'),
        ),
      ],
    );
  }
}

class _ManageTile extends StatelessWidget {
  const _ManageTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
