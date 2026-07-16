import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
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
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _avatarUrlController = TextEditingController();

  // Field-level validation errors (same rules as the original Form
  // validators — surfaced through AppTextField.errorText on Save).
  String? _fullNameError;
  String? _usernameError;
  String? _emailError;
  String? _avatarUrlError;

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

  /// Validation rules preserved 1:1 from the original `TextFormField`
  /// validators; errors render via each field's `errorText`.
  bool _validate(AppLocalizations l10n) {
    String? fullNameError;
    final fullName = _fullNameController.text.trim();
    if (fullName.isNotEmpty && fullName.length > 100) {
      fullNameError = l10n.invalid_full_name;
    }

    String? usernameError;
    final username = _usernameController.text.trim().toLowerCase();
    if (username.isNotEmpty &&
        !RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(username)) {
      usernameError = l10n.invalid_username;
    }

    String? emailError;
    final email = _emailController.text.trim();
    if (email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      emailError = l10n.invalid_email;
    }

    String? avatarUrlError;
    final avatarUrl = _avatarUrlController.text.trim();
    if (avatarUrl.isNotEmpty && !avatarUrl.startsWith('https://')) {
      avatarUrlError = l10n.invalid_avatar_url;
    }

    setState(() {
      _fullNameError = fullNameError;
      _usernameError = usernameError;
      _emailError = emailError;
      _avatarUrlError = avatarUrlError;
    });
    return fullNameError == null &&
        usernameError == null &&
        emailError == null &&
        avatarUrlError == null;
  }

  Future<void> _save(AppLocalizations l10n) async {
    if (!_validate(l10n)) return;

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
          return DcCrownScaffold(
            title: l10n.profile_title,
            dense: true,
            body: const AppSpinner.page(),
          );
        }

        final colors = AppColors.of(context);
        final styles = AppTextStyles.of(context);
        final isSaving = state.status == ProfileStatus.saving;
        final failure = state.status == ProfileStatus.saveFailure
            ? state.failure
            : null;
        final errorText = failure == null
            ? null
            : _localizeFailure(failure, l10n);

        return DcCrownScaffold(
          title: l10n.profile_title,
          dense: true,
          leading: DcCrownIconButton(
            icon: Icons.arrow_forward,
            onTap: () {
              if (Navigator.canPop(context)) Navigator.pop(context);
            },
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: l10n.profile_full_name_label,
                  controller: _fullNameController,
                  errorText: _fullNameError,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: l10n.profile_username_label,
                  controller: _usernameController,
                  errorText: _usernameError,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: l10n.profile_email_label,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  errorText: _emailError,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: l10n.profile_avatar_label,
                  controller: _avatarUrlController,
                  keyboardType: TextInputType.url,
                  errorText: _avatarUrlError,
                ),
                const SizedBox(height: AppSpacing.xl),
                if (errorText != null) ...[
                  Text(
                    errorText,
                    style: styles.bodyMedium.copyWith(color: colors.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppButton.filledPrimary(
                  label: l10n.profile_save_button,
                  expanded: true,
                  loading: isSaving,
                  onPressed: isSaving ? null : () => _save(l10n),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: l10n.profile_cancel_button,
                  variant: AppButtonVariant.text,
                  onPressed: isSaving
                      ? null
                      : () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                        },
                ),
              ],
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
