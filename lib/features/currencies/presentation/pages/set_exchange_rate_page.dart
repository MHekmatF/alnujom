import 'package:decimal/decimal.dart';
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
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/locale_toggle_action.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/presentation/rate_formatter.dart';
import '../../domain/entities/currency.dart';
import '../../domain/usecases/list_currencies.dart';
import '../bloc/set_exchange_rate_bloc.dart';
import '../widgets/unusual_timing_confirmation_dialog.dart';

class SetExchangeRatePage extends StatelessWidget {
  const SetExchangeRatePage({this.initialBaseCurrencyCode, super.key});

  final String? initialBaseCurrencyCode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SetExchangeRateBloc>(
      create: (_) {
        final bloc = getIt<SetExchangeRateBloc>();
        if (initialBaseCurrencyCode != null) {
          bloc.add(BaseChanged(initialBaseCurrencyCode));
        }
        return bloc;
      },
      child: const _SetExchangeRateView(),
    );
  }
}

class _SetExchangeRateView extends StatefulWidget {
  const _SetExchangeRateView();

  @override
  State<_SetExchangeRateView> createState() => _SetExchangeRateViewState();
}

class _SetExchangeRateViewState extends State<_SetExchangeRateView> {
  late final Future<List<Currency>> _currenciesFuture;
  final _rate = TextEditingController();
  final _source = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currenciesFuture = getIt<ListCurrencies>()(activeOnly: true);
  }

  @override
  void dispose() {
    _rate.dispose();
    _source.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocConsumer<SetExchangeRateBloc, SetExchangeRateState>(
      listener: (context, state) async {
        if (state.status == SetRateStatus.unusualTimingPending) {
          final delta = state.effectiveAt.difference(DateTime.now());
          final confirmed = await showUnusualTimingConfirmationDialog(
            context,
            direction: delta.isNegative
                ? UnusualTimingDirection.backdate
                : UnusualTimingDirection.future,
            magnitude: formatUnusualTimingMagnitude(delta, l10n),
          );
          if (!context.mounted) return;
          context.read<SetExchangeRateBloc>().add(
            confirmed
                ? const UnusualTimingConfirmed()
                : const UnusualTimingCancelled(),
          );
        } else if (state.status == SetRateStatus.saveSuccess) {
          Navigator.of(context).pop(true);
        } else if (state.status == SetRateStatus.saveFailure &&
            state.failureReason != null) {
          AppToast.error(context, _errorText(l10n, state.failureReason!));
        }
      },
      builder: (context, state) {
        return FutureBuilder<List<Currency>>(
          future: _currenciesFuture,
          builder: (context, snapshot) {
            final currencies = snapshot.data ?? const <Currency>[];
            final locale = Localizations.localeOf(context);
            final isSaving = state.status == SetRateStatus.saving;

            return DcCrownScaffold(
              title: l10n.setExchangeRatePageTitle,
              dense: true,
              leading: DcCrownIconButton(
                icon: Icons.arrow_forward,
                onTap: () => context.canPop()
                    ? context.pop()
                    : context.go(AppRoutes.shellHome),
              ),
              actions: const [LocaleToggleAction()],
              body: snapshot.connectionState != ConnectionState.done
                  ? const AppSpinner.page()
                  : ListView(
                      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: state.baseCurrency,
                          decoration: InputDecoration(
                            labelText: l10n.baseCurrencyLabel,
                          ),
                          items: [
                            for (final currency in currencies)
                              DropdownMenuItem(
                                value: currency.code,
                                child: Text(
                                  l10n.currencyOptionLabel(
                                    currency.code,
                                    currency.localizedName(locale),
                                  ),
                                ),
                              ),
                          ],
                          onChanged: isSaving
                              ? null
                              : (value) => context
                                    .read<SetExchangeRateBloc>()
                                    .add(BaseChanged(value)),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        DropdownButtonFormField<String>(
                          initialValue: state.targetCurrency,
                          decoration: InputDecoration(
                            labelText: l10n.targetCurrencyLabel,
                          ),
                          items: [
                            for (final currency in currencies)
                              DropdownMenuItem(
                                value: currency.code,
                                child: Text(
                                  l10n.currencyOptionLabel(
                                    currency.code,
                                    currency.localizedName(locale),
                                  ),
                                ),
                              ),
                          ],
                          onChanged: isSaving
                              ? null
                              : (value) => context
                                    .read<SetExchangeRateBloc>()
                                    .add(TargetChanged(value)),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: _rate,
                          enabled: !isSaving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.rateAmountLabel,
                          ),
                          onChanged: (value) => context
                              .read<SetExchangeRateBloc>()
                              .add(RateChanged(Decimal.tryParse(value.trim()))),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (state.derivedRatePreview != null &&
                            state.baseCurrency != null &&
                            state.targetCurrency != null)
                          Text(
                            // Derived inverse: "1 {target} = {preview} {base}".
                            // Uses RateFormatter (not MoneyFormatter) so small
                            // values like 0.000063 don't collapse to $0.00
                            // under USD's display_decimals=2.
                            l10n.latestRateLineTemplate(
                              state.targetCurrency!,
                              '${RateFormatter.format(state.derivedRatePreview!, locale)} ${state.baseCurrency!}',
                            ),
                          ),
                        const SizedBox(height: AppSpacing.md),
                        _EffectiveAtRow(
                          label: l10n.effectiveAtLabel,
                          value: state.effectiveAt.toLocal().toString(),
                          onTap: isSaving
                              ? null
                              : () => _pickEffectiveAt(context, state),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: _source,
                          enabled: !isSaving,
                          maxLength: 500,
                          decoration: InputDecoration(
                            labelText: l10n.sourceLabel,
                          ),
                          onChanged: (value) => context
                              .read<SetExchangeRateBloc>()
                              .add(SourceChanged(value)),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppButton(
                          label: l10n.submitButton,
                          loading: isSaving,
                          onPressed: isSaving
                              ? null
                              : () => context.read<SetExchangeRateBloc>().add(
                                  const SetRateSubmitPressed(),
                                ),
                        ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickEffectiveAt(
    BuildContext context,
    SetExchangeRateState state,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: state.effectiveAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(state.effectiveAt),
    );
    if (time == null || !context.mounted) return;
    context.read<SetExchangeRateBloc>().add(
      EffectiveAtChanged(
        DateTime(date.year, date.month, date.day, time.hour, time.minute),
      ),
    );
  }

  String _errorText(AppLocalizations l10n, String reason) {
    return switch (reason) {
      'permission_denied' => l10n.errorPermissionDenied,
      'rate_must_be_positive' => l10n.rateMustBePositiveError,
      'base_equals_target' => l10n.baseEqualsTargetError,
      'system_immutable' => l10n.errorSystemCurrencyImmutable,
      'duplicate_code' => l10n.errorDuplicateCode,
      'has_references' => l10n.errorCurrencyHasReferences,
      'display_decimals_range' => l10n.displayDecimalsRangeError,
      'validation_failed' => l10n.errorValidationFailed,
      _ => l10n.errorCurrencyUnknown,
    };
  }
}

/// Branded "effective at" picker row — tinted calendar glyph, label,
/// current value, and a tap target opening the date/time pickers
/// (replaces the stock [ListTile]).
class _EffectiveAtRow extends StatelessWidget {
  const _EffectiveAtRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return AppSurface(
      radius: AppRadii.lg,
      onTap: onTap,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: AppSpacing.xxl + AppSpacing.lg,
            height: AppSpacing.xxl + AppSpacing.lg,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primary.withValues(alpha: 0.12),
            ),
            child: Icon(
              LucideIcons.calendar,
              color: colors.primary,
              size: AppSpacing.xl,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: styles.bodyLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  value,
                  style: styles.bodyMedium.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? LucideIcons.chevron_left
                : LucideIcons.chevron_right,
            size: AppSpacing.xl,
            color: colors.textMuted,
          ),
        ],
      ),
    );
  }
}
