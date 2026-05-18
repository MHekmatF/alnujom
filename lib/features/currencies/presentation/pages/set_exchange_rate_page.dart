import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/spacing.dart';
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_errorText(l10n, state.failureReason!))),
          );
        }
      },
      builder: (context, state) {
        return FutureBuilder<List<Currency>>(
          future: _currenciesFuture,
          builder: (context, snapshot) {
            final currencies = snapshot.data ?? const <Currency>[];
            final locale = Localizations.localeOf(context);
            final isSaving = state.status == SetRateStatus.saving;

            return Scaffold(
              appBar: AppBar(
                title: Text(l10n.setExchangeRatePageTitle),
                actions: const [LocaleToggleAction()],
              ),
              body: snapshot.connectionState != ConnectionState.done
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
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
                                  '${currency.code} · ${currency.localizedName(locale)}',
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
                                  '${currency.code} · ${currency.localizedName(locale)}',
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
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.effectiveAtLabel),
                          subtitle: Text(
                            state.effectiveAt.toLocal().toString(),
                          ),
                          trailing: const Icon(Icons.event),
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
                        FilledButton(
                          onPressed: isSaving
                              ? null
                              : () => context.read<SetExchangeRateBloc>().add(
                                  const SetRateSubmitPressed(),
                                ),
                          child: isSaving
                              ? const CircularProgressIndicator()
                              : Text(l10n.submitButton),
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
