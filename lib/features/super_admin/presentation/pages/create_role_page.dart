import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/spacing.dart';
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.superAdminCreateRoleTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const CircularProgressIndicator()
            : const Icon(Icons.save),
      ),
      body: FutureBuilder<List<PermissionCatalogEntry>>(
        future: _catalogFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              TextField(
                controller: _keyController,
                decoration: InputDecoration(
                  labelText: l10n.roleKeyLabel,
                  errorText: _keyError,
                ),
                onChanged: (_) => setState(() => _keyError = null),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _arController,
                decoration: InputDecoration(
                  labelText: l10n.roleDisplayNameLabelAr,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _enController,
                decoration: InputDecoration(
                  labelText: l10n.roleDisplayNameLabelEn,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: l10n.roleDescriptionLabel,
                ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorRoleDisplayNameRequired)),
      );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
