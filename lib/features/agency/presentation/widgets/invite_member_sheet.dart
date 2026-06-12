// lib/features/agency/presentation/widgets/invite_member_sheet.dart
//
// Phase 19 (spec/019-agencies) Sub-Phase H (T051).
// Modal bottom sheet: phone + role; dispatches AgencyMembersInviteRequested on
// the ambient AgencyMembersBloc and surfaces user_not_found / already_member.
// Mirrors report_sheet.dart. Phase 2 tokens only; no inline hex/font/padding.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/agency_member_role.dart';
import '../bloc/agency_members_bloc.dart';

/// Shows the invite-member sheet. [bloc] is the page's [AgencyMembersBloc] so
/// the sheet shares its state (the page rebuilds its roster on success).
Future<void> showInviteMemberSheet(
  BuildContext context, {
  required AgencyMembersBloc bloc,
  required String agencyId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => BlocProvider<AgencyMembersBloc>.value(
      value: bloc,
      child: _InviteMemberSheet(agencyId: agencyId),
    ),
  );
}

class _InviteMemberSheet extends StatefulWidget {
  const _InviteMemberSheet({required this.agencyId});

  final String agencyId;

  @override
  State<_InviteMemberSheet> createState() => _InviteMemberSheetState();
}

class _InviteMemberSheetState extends State<_InviteMemberSheet> {
  final _phoneController = TextEditingController();
  AgencyMemberRole _role = AgencyMemberRole.agent;
  bool _submitted = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final styles = AppTextStyles.of(context);

    return BlocConsumer<AgencyMembersBloc, AgencyMembersState>(
      listener: (context, state) {
        if (!_submitted) return;
        if (state is AgencyMembersLoaded && !state.actionInProgress) {
          if (state.actionError == null) {
            // Success — close the sheet.
            Navigator.of(context).pop();
          } else {
            _submitted = false;
            final message = switch (state.actionError) {
              'user_not_found' => l10n.agency_invite_user_not_found,
              'already_member' ||
              'already_owns_agency' => l10n.agency_invite_already_member,
              _ => l10n.agency_action_failed,
            };
            AppToast.error(context, message);
          }
        }
      },
      builder: (context, state) {
        final submitting =
            state is AgencyMembersLoaded && state.actionInProgress;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.lg,
              bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.agency_invite_button, style: styles.titleLarge),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  label: l10n.agency_invite_phone_label,
                ),
                const SizedBox(height: AppSpacing.md),
                AppDropdown<AgencyMemberRole>(
                  label: l10n.agency_invite_role_label,
                  value: _role,
                  items: [
                    DropdownMenuItem(
                      value: AgencyMemberRole.agent,
                      child: Text(l10n.agency_role_agent),
                    ),
                    DropdownMenuItem(
                      value: AgencyMemberRole.admin,
                      child: Text(l10n.agency_role_admin),
                    ),
                  ],
                  enabled: !submitting,
                  onChanged: (v) =>
                      setState(() => _role = v ?? AgencyMemberRole.agent),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: l10n.agency_cancel_button,
                        variant: AppButtonVariant.outlined,
                        expanded: true,
                        onPressed: submitting
                            ? null
                            : () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppButton.filledPrimary(
                        label: l10n.agency_invite_button,
                        expanded: true,
                        loading: submitting,
                        onPressed: submitting ? null : _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _submit() {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;
    _submitted = true;
    context.read<AgencyMembersBloc>().add(
      AgencyMembersInviteRequested(
        agencyId: widget.agencyId,
        phone: phone,
        role: _role.wireValue,
      ),
    );
  }
}
