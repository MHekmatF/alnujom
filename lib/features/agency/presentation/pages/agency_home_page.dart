// lib/features/agency/presentation/pages/agency_home_page.dart
//
// Phase 19 (spec/019-agencies) Sub-Phase H (T054).
// Replaces the Phase-1 stub. None → "Create agency" form; owner/member →
// management surface (status chip + links to members/listings/analytics/verify).
// Phase 2 tokens only; all strings via AppLocalizations (Constitution V/VI).
//
// Phase 28 (premium-worth pass) — purely visual retrofit: stock fields →
// AppTextField, FilledButton → AppButton, ListTiles → branded AppSurface rows
// (the profile-page _ProfileRow idiom), snackbars → AppToast. Behavior, bloc
// wiring, strings, and navigation are unchanged.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/press_scale.dart';
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
          AppToast.error(context, message);
        }
      },
      builder: (context, state) {
        return DcCrownScaffold(
          dense: true,
          leading: DcCrownIconButton(
            icon: Icons.arrow_forward,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          title: switch (state) {
            AgencyHomeNone() ||
            AgencyHomeCreating() ||
            AgencyHomeCreateFailure() => l10n.agency_create_title,
            AgencyHomeInvited() => l10n.agency_invitations_title,
            _ => l10n.agency_profile_title,
          },
          body: switch (state) {
            AgencyHomeLoading() => const AppSpinner.page(),
            AgencyHomeError() => Center(child: Text(l10n.agency_generic_error)),
            AgencyHomeNone() ||
            AgencyHomeCreating() ||
            AgencyHomeCreateFailure() => _CreateAgencyForm(
              submitting: state is AgencyHomeCreating,
            ),
            AgencyHomeInvited(:final invitations, :final responding) =>
              _InvitedView(invitations: invitations, responding: responding),
            AgencyHomeOwner(:final agency) => _ManagementSurface(
              agency: agency,
              isOwner: true,
            ),
            AgencyHomeMember(:final agency) => _ManagementSurface(
              agency: agency,
              isOwner: false,
            ),
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
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.agency_no_agency_message,
            style: styles.bodyMedium.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _nameController,
            label: l10n.agency_name_label,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _descriptionController,
            label: l10n.agency_description_label,
            helperText: l10n.agency_create_description_hint,
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _phoneController,
            label: l10n.agency_phone_label,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _whatsappController,
            label: l10n.agency_whatsapp_label,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _addressController,
            label: l10n.agency_address_label,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton.filledPrimary(
            label: l10n.agency_create_button,
            expanded: true,
            loading: widget.submitting,
            onPressed: widget.submitting ? null : _submit,
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
    final styles = AppTextStyles.of(context);
    final cubit = context.read<AgencyHomeCubit>();

    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        Text(l10n.agency_invitations_title, style: styles.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final invite in invitations)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: AppSurface(
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.agency_invitation_pending_from(invite.agencyName),
                      style: styles.bodyMedium,
                    ),
                  ),
                  AppButton(
                    label: l10n.agency_invitation_decline,
                    variant: AppButtonVariant.text,
                    size: AppButtonSize.dense,
                    onPressed: responding
                        ? null
                        : () => cubit.respondInvitation(
                            agencyId: invite.membership.agencyId,
                            accept: false,
                          ),
                  ),
                  AppButton(
                    label: l10n.agency_invitation_accept,
                    size: AppButtonSize.dense,
                    onPressed: responding
                        ? null
                        : () => cubit.respondInvitation(
                            agencyId: invite.membership.agencyId,
                            accept: true,
                          ),
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
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            Expanded(child: Text(agency.name, style: styles.headlineMedium)),
            const SizedBox(width: AppSpacing.sm),
            AgencyStatusChip(agency.status),
          ],
        ),
        if (agency.description != null &&
            agency.description!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            agency.description!,
            style: styles.bodyMedium.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _ManageTile(
          icon: LucideIcons.users,
          label: l10n.agency_manage_members,
          onTap: () => context.push(AppRoutes.agencyMembers, extra: agency),
        ),
        _ManageTile(
          icon: LucideIcons.list,
          label: l10n.agency_manage_listings,
          onTap: () => context.push(AppRoutes.agencyListings, extra: agency.id),
        ),
        _ManageTile(
          icon: LucideIcons.chart_column,
          label: l10n.agency_manage_analytics,
          onTap: () =>
              context.push(AppRoutes.agencyAnalytics, extra: agency.id),
        ),
        if (isOwner)
          _ManageTile(
            icon: LucideIcons.pencil,
            label: l10n.agency_edit_button,
            onTap: () async {
              final changed = await context.push<bool>(AppRoutes.agencyEdit);
              if (changed == true && context.mounted) {
                await context.read<AgencyHomeCubit>().load();
              }
            },
          ),
        if (isOwner)
          _ManageTile(
            icon: LucideIcons.badge_check,
            label: l10n.agency_manage_verify,
            onTap: () => context.push(AppRoutes.agencyVerify, extra: agency.id),
          ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.agency_profile_title,
          variant: AppButtonVariant.outlined,
          icon: LucideIcons.external_link,
          onPressed: () => context.push('/agency/${agency.id}'),
        ),
      ],
    );
  }
}

/// A branded management row — AppSurface card + PressScale tap feedback, a
/// leading icon in a soft primary-tinted square, and a trailing chevron
/// (mirrors the profile page's `_ProfileRow` idiom).
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
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: PressScale(
        child: AppSurface(
          onTap: onTap,
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          radius: AppRadii.lg,
          child: Row(
            children: [
              Container(
                width: AppSpacing.xxl + AppSpacing.sm,
                height: AppSpacing.xxl + AppSpacing.sm,
                alignment: AlignmentDirectional.center,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: appRadius(AppRadii.md),
                ),
                child: Icon(icon, color: colors.primary, size: AppSpacing.xl),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: styles.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                LucideIcons.chevron_right,
                size: AppSpacing.xl,
                color: colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
