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
import '../../../../core/widgets/app_toggle.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/locale_toggle_action.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../bloc/currency_form_bloc.dart';

class CurrencyFormPage extends StatelessWidget {
  const CurrencyFormPage({required this.mode, this.code, super.key});

  final String mode;
  final String? code;

  @override
  Widget build(BuildContext context) {
    final formMode = mode == 'edit' ? FormMode.edit : FormMode.create;
    return BlocProvider<CurrencyFormBloc>(
      create: (_) =>
          getIt<CurrencyFormBloc>()..add(Initialize(formMode, code: code)),
      child: const _CurrencyFormView(),
    );
  }
}

class _CurrencyFormView extends StatefulWidget {
  const _CurrencyFormView();

  @override
  State<_CurrencyFormView> createState() => _CurrencyFormViewState();
}

class _CurrencyFormViewState extends State<_CurrencyFormView> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _symbol = TextEditingController();
  final _sortOrder = TextEditingController(text: '100');
  final _displayDecimals = TextEditingController(text: '2');
  bool _isActive = true;
  String? _lastLoadedCode;

  @override
  void dispose() {
    _code.dispose();
    _nameAr.dispose();
    _nameEn.dispose();
    _symbol.dispose();
    _sortOrder.dispose();
    _displayDecimals.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocConsumer<CurrencyFormBloc, CurrencyFormState>(
      listener: (context, state) {
        if (state.loadedCurrency != null &&
            _lastLoadedCode != state.loadedCurrency!.code) {
          _lastLoadedCode = state.loadedCurrency!.code;
          _syncControllers(state);
        }
        if (state.status == CurrencyFormStatus.saveSuccess) {
          Navigator.of(context).pop(true);
        } else if (state.status == CurrencyFormStatus.saveFailure &&
            state.failureReason != null) {
          AppToast.error(context, _errorText(l10n, state.failureReason!));
        }
      },
      builder: (context, state) {
        final isSaving = state.status == CurrencyFormStatus.saving;
        final isLoading = state.status == CurrencyFormStatus.loading;
        return DcCrownScaffold(
          title: l10n.currencyFormPageTitle,
          dense: true,
          leading: DcCrownIconButton(
            icon: Icons.arrow_forward,
            onTap: () => context.canPop()
                ? context.pop()
                : context.go(AppRoutes.shellHome),
          ),
          actions: const [LocaleToggleAction()],
          body: isLoading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppSpinner(),
                      const SizedBox(height: AppSpacing.md),
                      Text(l10n.loadingHint),
                    ],
                  ),
                )
              : AbsorbPointer(
                  absorbing: isSaving,
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                      children: [
                        TextFormField(
                          controller: _code,
                          enabled:
                              state.mode == FormMode.create ||
                              !state.isLoadedSystemRow,
                          decoration: InputDecoration(
                            labelText: l10n.currencyCodeLabel,
                          ),
                          textCapitalization: TextCapitalization.characters,
                          validator: (value) =>
                              RegExp(
                                r'^[A-Z]{3}$',
                              ).hasMatch((value ?? '').trim().toUpperCase())
                              ? null
                              : l10n.currencyCodeFormatError,
                          onChanged: (value) =>
                              _changed(context, 'code', value.toUpperCase()),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _nameAr,
                          decoration: InputDecoration(
                            labelText: l10n.currencyNameArLabel,
                          ),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? l10n.requiredField
                              : null,
                          onChanged: (value) =>
                              _changed(context, 'nameAr', value),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _nameEn,
                          decoration: InputDecoration(
                            labelText: l10n.currencyNameEnLabel,
                          ),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? l10n.requiredField
                              : null,
                          onChanged: (value) =>
                              _changed(context, 'nameEn', value),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _symbol,
                          decoration: InputDecoration(
                            labelText: l10n.currencySymbolLabel,
                          ),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? l10n.requiredField
                              : null,
                          onChanged: (value) =>
                              _changed(context, 'symbol', value),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _sortOrder,
                          decoration: InputDecoration(
                            labelText: l10n.currencySortOrderLabel,
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) => _changed(
                            context,
                            'sortOrder',
                            int.tryParse(value),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _displayDecimals,
                          decoration: InputDecoration(
                            labelText: l10n.currencyDisplayDecimalsLabel,
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            final parsed = int.tryParse(value ?? '');
                            return parsed != null && parsed >= 0 && parsed <= 8
                                ? null
                                : l10n.displayDecimalsRangeError;
                          },
                          onChanged: (value) => _changed(
                            context,
                            'displayDecimals',
                            int.tryParse(value),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _ActiveSwitchRow(
                          label: l10n.currencyIsActiveLabel,
                          value: _isActive,
                          onChanged: (value) {
                            setState(() => _isActive = value);
                            _changed(context, 'isActive', value);
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppButton(
                          label: l10n.submitButton,
                          // Batch-2: form primary CTAs are full-width in the DS
                          // (auth/create-listing); this one was content-width.
                          expanded: true,
                          loading: isSaving,
                          onPressed: isSaving ? null : () => _submit(context),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  String _errorText(AppLocalizations l10n, String reason) {
    return switch (reason) {
      'permission_denied' => l10n.errorPermissionDenied,
      'duplicate_code' => l10n.errorDuplicateCode,
      'system_immutable' => l10n.errorSystemCurrencyImmutable,
      'has_references' => l10n.errorCurrencyHasReferences,
      'rate_must_be_positive' => l10n.rateMustBePositiveError,
      'base_equals_target' => l10n.baseEqualsTargetError,
      'display_decimals_range' => l10n.displayDecimalsRangeError,
      'validation_failed' => l10n.errorValidationFailed,
      _ => l10n.errorCurrencyUnknown,
    };
  }

  void _syncControllers(CurrencyFormState state) {
    final values = state.fieldValues;
    _code.text = values['code']?.toString() ?? '';
    _nameAr.text = values['nameAr']?.toString() ?? '';
    _nameEn.text = values['nameEn']?.toString() ?? '';
    _symbol.text = values['symbol']?.toString() ?? '';
    _sortOrder.text = values['sortOrder']?.toString() ?? '100';
    _displayDecimals.text = values['displayDecimals']?.toString() ?? '2';
    _isActive = values['isActive'] == true;
  }

  void _changed(BuildContext context, String name, Object? value) {
    context.read<CurrencyFormBloc>().add(EditFieldChanged(name, value));
  }

  void _submit(BuildContext context) {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _changed(context, 'code', _code.text.trim().toUpperCase());
    _changed(context, 'nameAr', _nameAr.text.trim());
    _changed(context, 'nameEn', _nameEn.text.trim());
    _changed(context, 'symbol', _symbol.text.trim());
    _changed(context, 'sortOrder', int.tryParse(_sortOrder.text) ?? 100);
    _changed(
      context,
      'displayDecimals',
      int.tryParse(_displayDecimals.text) ?? 2,
    );
    _changed(context, 'isActive', _isActive);
    context.read<CurrencyFormBloc>().add(const SubmitPressed());
  }
}

/// Branded replacement for the stock [SwitchListTile] — tinted icon circle +
/// label on a hairline surface with a trailing [Switch]. Tapping the row
/// toggles, mirroring the original tile behavior.
class _ActiveSwitchRow extends StatelessWidget {
  const _ActiveSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return PressScale(
      child: AppSurface(
        radius: AppRadii.lg,
        onTap: () => onChanged(!value),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: AppSpacing.xxl + AppSpacing.sm,
              height: AppSpacing.xxl + AppSpacing.sm,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary.withValues(alpha: 0.12),
              ),
              child: Icon(
                LucideIcons.coins,
                color: colors.primary,
                size: AppSpacing.lg,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: styles.bodyLarge)),
            const SizedBox(width: AppSpacing.sm),
            // Batch-2: the bare Material Switch -> the DS AppToggle, so all
            // four internal toggle rows share one active-state treatment.
            AppToggle(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
