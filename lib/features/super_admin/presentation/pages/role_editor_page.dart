import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/security/permission_checker.dart';
import '../../../../core/security/permission_keys.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../bloc/role_editor_bloc.dart';
import '../widgets/permission_checklist.dart';

class RoleEditorPage extends StatelessWidget {
  const RoleEditorPage({required this.roleId, super.key});

  final String roleId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RoleEditorBloc>(
      create: (_) => getIt<RoleEditorBloc>()..add(OpenRole(roleId)),
      child: const _RoleEditorView(),
    );
  }
}

class _RoleEditorView extends StatelessWidget {
  const _RoleEditorView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocListener<RoleEditorBloc, RoleEditorState>(
      listener: (context, state) {
        if (state is RoleEditorSaveSucceeded) {
          context.pop();
        } else if (state is RoleEditorSaveConflict) {
          final message = switch (state.reason) {
            RoleSaveConflictReason.concurrentEdit => l10n.errorRoleEditConflict,
            RoleSaveConflictReason.superAdminImmutable =>
              l10n.errorSuperAdminPermissionsImmutable,
            RoleSaveConflictReason.systemRoleProtected =>
              l10n.errorSystemRoleImmutable,
          };
          AppToast.show(
            context,
            message,
            variant: AppToastVariant.warning,
            action: state.reason == RoleSaveConflictReason.concurrentEdit
                ? SnackBarAction(
                    label: l10n.actionReload,
                    onPressed: () => context.read<RoleEditorBloc>().add(
                      const ReloadAfterConflict(),
                    ),
                  )
                : null,
          );
        } else if (state is RoleEditorSaveError) {
          AppToast.error(
            context,
            l10n.errorRoleSaveFailed(state.failure.message),
          );
        }
      },
      child: BlocBuilder<RoleEditorBloc, RoleEditorState>(
        builder: (context, state) {
          final canUpdate = getIt<PermissionChecker>().has(
            PermissionKeys.rolesUpdate,
          );
          final canManagePermissions = getIt<PermissionChecker>().has(
            PermissionKeys.permissionsManage,
          );
          return Scaffold(
            appBar: AppBar(title: Text(l10n.superAdminRoleEditorTitle)),
            floatingActionButton: state is RoleEditorEditing
                ? FloatingActionButton(
                    onPressed:
                        state.dirty &&
                            !state.saving &&
                            canUpdate &&
                            (!state.permissionSetChanged ||
                                canManagePermissions)
                        ? () => context.read<RoleEditorBloc>().add(
                            const SaveRole(),
                          )
                        : null,
                    child: state.saving
                        ? const AppSpinner()
                        : const Icon(LucideIcons.save),
                  )
                : null,
            body: switch (state) {
              RoleEditorInitial() ||
              RoleEditorLoading() => const AppSpinner.page(),
              RoleEditorLoadFailure(:final failure) => Center(
                child: Text(failure.message, textAlign: TextAlign.center),
              ),
              RoleEditorSaveSucceeded() ||
              RoleEditorSaveConflict() ||
              RoleEditorSaveError() => const AppSpinner.page(),
              RoleEditorEditing() => _RoleEditorForm(
                state: state,
                permissionReadOnly:
                    state.isSuperAdminRow || !canManagePermissions,
              ),
            },
          );
        },
      ),
    );
  }
}

class _RoleEditorForm extends StatefulWidget {
  const _RoleEditorForm({
    required this.state,
    required this.permissionReadOnly,
  });

  final RoleEditorEditing state;
  final bool permissionReadOnly;

  @override
  State<_RoleEditorForm> createState() => _RoleEditorFormState();
}

class _RoleEditorFormState extends State<_RoleEditorForm> {
  late final TextEditingController _arController;
  late final TextEditingController _enController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _arController = TextEditingController(
      text: widget.state.current.displayName['ar'] ?? '',
    );
    _enController = TextEditingController(
      text: widget.state.current.displayName['en'] ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.state.current.description ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _RoleEditorForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.expectedUpdatedAt != widget.state.expectedUpdatedAt) {
      _arController.text = widget.state.current.displayName['ar'] ?? '';
      _enController.text = widget.state.current.displayName['en'] ?? '';
      _descriptionController.text = widget.state.current.description ?? '';
    }
  }

  @override
  void dispose() {
    _arController.dispose();
    _enController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        AppTextField(
          label: l10n.roleDisplayNameLabelAr,
          controller: _arController,
          onChanged: (value) => context.read<RoleEditorBloc>().add(
            UpdateDisplayName('ar', value),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: l10n.roleDisplayNameLabelEn,
          controller: _enController,
          onChanged: (value) => context.read<RoleEditorBloc>().add(
            UpdateDisplayName('en', value),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: l10n.roleDescriptionLabel,
          controller: _descriptionController,
          maxLines: 3,
          onChanged: (value) =>
              context.read<RoleEditorBloc>().add(UpdateDescription(value)),
        ),
        const SizedBox(height: AppSpacing.xl),
        PermissionChecklist(
          catalog: widget.state.catalog,
          selectedKeys: widget.state.current.permissionKeys.toSet(),
          onToggle: (key) =>
              context.read<RoleEditorBloc>().add(TogglePermission(key)),
          isReadOnly: widget.permissionReadOnly,
        ),
      ],
    );
  }
}
