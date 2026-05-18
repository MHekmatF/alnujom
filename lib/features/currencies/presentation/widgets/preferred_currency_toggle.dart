import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/repositories/currencies_repository_impl.dart'
    show CurrenciesFailure;
import '../../domain/entities/currency.dart';
import '../../domain/repositories/currencies_repository.dart';
import '../../domain/usecases/list_currencies.dart';

/// Small local-state widget approved by tasks.md T073.
///
/// It persists user_preferences.display_currency only. It deliberately does not
/// perform exchange-rate lookup or formatting; downstream listing surfaces use
/// the saved preference on their next paint.
class PreferredCurrencyToggle extends StatefulWidget {
  const PreferredCurrencyToggle({super.key});

  @override
  State<PreferredCurrencyToggle> createState() =>
      _PreferredCurrencyToggleState();
}

class _PreferredCurrencyToggleState extends State<PreferredCurrencyToggle> {
  List<Currency>? _currencies;
  String? _selectedCode;
  String? _errorCode;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final currencies = await getIt<ListCurrencies>()(activeOnly: true);
      final preferred = await getIt<CurrenciesRepository>()
          .readUserDisplayCurrency();
      final activeCodes = currencies.map((currency) => currency.code).toSet();
      final fallbackCode = currencies.isEmpty ? null : currencies.first.code;
      final selected = activeCodes.contains(preferred)
          ? preferred
          : fallbackCode;

      if (!mounted) return;
      setState(() {
        _currencies = currencies;
        _selectedCode = selected;
        _errorCode = null;
      });

      if (selected != null && selected != preferred) {
        await getIt<CurrenciesRepository>().writeUserDisplayCurrency(selected);
      }
    } on CurrenciesFailure catch (error) {
      if (!mounted) return;
      setState(() => _errorCode = error.code);
    } on Object catch (_) {
      if (!mounted) return;
      setState(() => _errorCode = 'unknown');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final currencies = _currencies;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.preferredCurrencyLabel, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.preferredCurrencyHelp,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_errorCode != null)
          Text(
            _errorText(l10n, _errorCode!),
            style: TextStyle(color: theme.colorScheme.error),
          )
        else if (currencies == null)
          const LinearProgressIndicator()
        else if (currencies.isEmpty)
          const SizedBox.shrink()
        else if (currencies.length <= 3)
          SegmentedButton<String>(
            segments: [
              for (final currency in currencies)
                ButtonSegment<String>(
                  value: currency.code,
                  label: Text(_labelFor(context, currency)),
                ),
            ],
            selected: _selectedCode == null ? <String>{} : {_selectedCode!},
            onSelectionChanged: _saving
                ? null
                : (selection) => _select(selection.first),
          )
        else
          DropdownButtonFormField<String>(
            initialValue: _selectedCode,
            items: [
              for (final currency in currencies)
                DropdownMenuItem(
                  value: currency.code,
                  child: Text(_labelFor(context, currency)),
                ),
            ],
            onChanged: _saving || currencies.isEmpty
                ? null
                : (value) {
                    if (value != null) _select(value);
                  },
          ),
        if (_saving) ...[
          const SizedBox(height: AppSpacing.sm),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }

  String _labelFor(BuildContext context, Currency currency) {
    final locale = Localizations.localeOf(context);
    return '${currency.localizedName(locale)} (${currency.symbol})';
  }

  Future<void> _select(String code) async {
    if (code == _selectedCode) return;
    final previousCode = _selectedCode;
    setState(() {
      _selectedCode = code;
      _saving = true;
      _errorCode = null;
    });
    try {
      await getIt<CurrenciesRepository>().writeUserDisplayCurrency(code);
    } on CurrenciesFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _selectedCode = previousCode;
        _errorCode = error.code;
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _selectedCode = previousCode;
        _errorCode = 'unknown';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _errorText(AppLocalizations l10n, String code) {
    return switch (code) {
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
}
