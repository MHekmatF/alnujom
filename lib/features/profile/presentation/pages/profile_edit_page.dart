import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/repositories/profile_repository.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/profile_state.dart';

class ProfileEditPage extends StatelessWidget {
  const ProfileEditPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProfileCubit>(
      create: (_) => getIt<ProfileCubit>()..load(),
      child: const _ProfileEditView(),
    );
  }
}

class _ProfileEditView extends StatefulWidget {
  const _ProfileEditView();

  @override
  State<_ProfileEditView> createState() => _ProfileEditViewState();
}

class _ProfileEditViewState extends State<_ProfileEditView> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _avatarUrlController = TextEditingController();

  bool _initialized = false;
  bool _savePending = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  void _initControllers(ProfileState state) {
    if (_initialized || state.profile == null) return;
    _initialized = true;
    final p = state.profile!;
    _fullNameController.text = p.fullName ?? '';
    _usernameController.text = p.username ?? '';
    _emailController.text = p.email ?? '';
    _avatarUrlController.text = p.avatarUrl ?? '';
    context.read<ProfileCubit>().startEdit();
  }

  Future<void> _save(AppLocalizations l10n) async {
    if (!_formKey.currentState!.validate()) return;

    final cubit = context.read<ProfileCubit>();
    setState(() => _savePending = true);
    cubit.updateDraft(
      fullName: _fullNameController.text.trim(),
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      avatarUrl: _avatarUrlController.text.trim(),
    );
    await cubit.save();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return BlocConsumer<ProfileCubit, ProfileState>(
      listener: (context, state) {
        if (state.status == ProfileStatus.loaded) {
          if (!_initialized) {
            _initControllers(state);
          } else if (_savePending) {
            _savePending = false;
            if (Navigator.canPop(context)) Navigator.pop(context);
          }
        }
      },
      builder: (context, state) {
        if (state.status == ProfileStatus.loading ||
            state.status == ProfileStatus.initial) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.profile_title)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final isSaving = state.status == ProfileStatus.saving;
        final failure = state.status == ProfileStatus.saveFailure
            ? state.failure
            : null;
        final errorText = failure == null ? null : _localizeFailure(failure, l10n);

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.profile_title),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                if (Navigator.canPop(context)) Navigator.pop(context);
              },
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _fullNameController,
                    decoration: InputDecoration(
                      labelText: l10n.profile_full_name_label,
                    ),
                    validator: (v) {
                      if (v == null) return null;
                      final t = v.trim();
                      if (t.isNotEmpty && t.length > 100) return l10n.invalid_full_name;
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: l10n.profile_username_label,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final t = v.trim().toLowerCase();
                      if (!RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(t)) {
                        return l10n.invalid_username;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l10n.profile_email_label,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) {
                        return l10n.invalid_email;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _avatarUrlController,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: l10n.profile_avatar_label,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      if (!v.trim().startsWith('https://')) {
                        return l10n.invalid_avatar_url;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  if (errorText != null) ...[
                    Text(
                      errorText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    onPressed: isSaving ? null : () => _save(l10n),
                    child: isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.profile_save_button),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () {
                            if (Navigator.canPop(context)) Navigator.pop(context);
                          },
                    child: Text(l10n.profile_cancel_button),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _localizeFailure(ProfileFailure failure, AppLocalizations l10n) {
    return switch (failure) {
      UsernameTaken() => l10n.username_taken,
      InvalidFullName() => l10n.invalid_full_name,
      InvalidUsername() => l10n.invalid_username,
      InvalidEmail() => l10n.invalid_email,
      InvalidAvatarUrl() => l10n.invalid_avatar_url,
      _ => l10n.unknown_auth_error,
    };
  }
}
