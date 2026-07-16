import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/permission_catalog_entry.dart';
import '../../domain/entities/role_mutation_result.dart';
import '../../domain/failures.dart';
import '../../domain/usecases/load_permission_catalog.dart';
import '../../domain/usecases/mutate_role.dart';
import '../widgets/permission_checklist.dart';

class CreateRolePage extends StatefulWidget {
  const CreateRolePage({super.key});

  @override
  State<CreateRolePage> createState() => _CreateRolePageState();
}

class _CreateRolePageState extends State<CreateRolePage> {
  final _keyController = TextEditingController();
  final _arController = TextEditingController();
  final _enController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _selectedKeys = <String>{};
  late final Future<List<PermissionCatalogEntry>> _catalogFuture;
  bool _saving = false;
  String? _keyError;

  @override
  void initState() {
    super.initState();
    _catalogFuture = getIt<LoadPermissionCatalog>()();
  }

  @override
  void dispose() {
    _keyController.dispose();
    _arController.dispose();
    _enController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DcCrownScaffold(
      title: l10n.superAdminCreateRoleTitle,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.shellHome),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _saving ? null : _save,
        child: _saving ? const AppSpinner() : const Icon(LucideIcons.save),
      ),
      body: FutureBuilder<List<PermissionCatalogEntry>>(
        future: _catalogFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const AppSpinner.page();
          }
          return ListView(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            children: [
              AppTextField(
                label: l10n.roleKeyLabel,
                controller: _keyController,
                errorText: _keyError,
                onChanged: (_) => setState(() => _keyError = null),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: l10n.roleDisplayNameLabelAr,
                controller: _arController,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: l10n.roleDisplayNameLabelEn,
                controller: _enController,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: l10n.roleDescriptionLabel,
                controller: _descriptionController,
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.xl),
              PermissionChecklist(
                catalog: snapshot.data!,
                selectedKeys: _selectedKeys,
                onToggle: (key) => setState(() {
                  if (!_selectedKeys.add(key)) _selectedKeys.remove(key);
                }),
                isReadOnly: false,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final roleKey = _keyController.text.trim();
    final formatValid = RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(roleKey);
    if (!formatValid) {
      setState(() => _keyError = l10n.errorRoleKeyInvalid);
      return;
    }
    if (roleKey == 'super_admin') {
      setState(() => _keyError = l10n.errorRoleKeyDuplicate);
      return;
    }
    if (_arController.text.trim().isEmpty &&
        _enController.text.trim().isEmpty) {
      AppToast.warning(context, l10n.errorRoleDisplayNameRequired);
      return;
    }
    setState(() => _saving = true);
    try {
      await getIt<MutateRole>()(
        CreateRoleParams(
          roleKey: roleKey,
          displayName: {
            'ar': _arController.text.trim(),
            'en': _enController.text.trim(),
          },
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          permissionKeys: _selectedKeys.toList()..sort(),
        ),
      );
      if (mounted) context.pop(true);
    } on RoleKeyDuplicateFailure {
      if (mounted) setState(() => _keyError = l10n.errorRoleKeyDuplicate);
    } on SuperAdminFailure catch (failure) {
      if (mounted) {
        AppToast.error(context, failure.message);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
