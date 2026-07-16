import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/validators/price_validator.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../currencies/domain/entities/currency.dart';
import '../../../currencies/domain/usecases/list_currencies.dart';
import '../../domain/entities/listing_form_state.dart';
import '../bloc/listing_form_bloc.dart';
import '../bloc/listing_form_event.dart';
import 'express_form_fields.dart' show expressDecoration;
import 'price_preview_subline.dart';
import 'step_section.dart';

class StepPrices extends StatefulWidget {
  const StepPrices({super.key});

  @override
  State<StepPrices> createState() => _StepPricesState();
}

class _StepPricesState extends State<StepPrices> {
  final TextEditingController _amountController = TextEditingController();
  Future<List<Currency>>? _currenciesFuture;
  bool _seeded = false;
  bool _currencyAutoSelected = false;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _currenciesFuture = getIt<ListCurrencies>().call(activeOnly: true);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<ListingFormBloc, ListingFormState>(
      builder: (context, state) {
        final price = state.draftPrice;
        if (!_seeded && price != null) {
          _amountController.text = price.amount.toString();
          _seeded = true;
        }
        return FutureBuilder<List<Currency>>(
          future: _currenciesFuture,
          builder: (context, snap) {
            if (!snap.hasData) {
              return Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: AppSpacing.xl,
                ),
                child: Center(child: appInlineSpinner(context)),
              );
            }
            final currencies = snap.data!;
            final selected = currencies.firstWhere(
              (c) => c.code == price?.currencyCode,
              orElse: () => currencies.first,
            );
            // Sync the dropdown's visible default into BLoC state once
            // currencies have loaded, so the amount field always has a
            // currency to attach to (avoids the priceAmount-before-currency
            // race in the BLoC handler).
            if (!_currencyAutoSelected && price == null) {
              _currencyAutoSelected = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                context.read<ListingFormBloc>().add(
                  FieldChanged.priceCurrencyCode(selected.code),
                );
              });
            }
            // Q3 single-currency lock — NO "Add another" button, NO multi-row.
            return StepSection(
              icon: Icons.payments_outlined,
              title: l10n.listingFormStepPricesTitle,
              subtitle: l10n.listingFormStepPricesSubtitle,
              children: [
                FieldLabel(label: l10n.fieldLabelCurrency, required: true),
                DropdownButtonFormField<String>(
                  initialValue: price?.currencyCode ?? selected.code,
                  isExpanded: true,
                  decoration: expressDecoration(context),
                  items: currencies
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.code,
                          child: Text(
                            l10n.currencyDropdownOption(c.code, c.symbol),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      context.read<ListingFormBloc>().add(
                        FieldChanged.priceCurrencyCode(v),
                      );
                    }
                  },
                ),
                const FieldGap(),
                FieldLabel(label: l10n.fieldLabelPrice, required: true),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  // Phase 029 (F3 #5) — keyboard polish: keep the amount field
                  // above the keyboard and dismiss it on submit (last input on
                  // the step).
                  scrollPadding: const EdgeInsets.all(AppSpacing.xxxl),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: expressDecoration(context, error: _amountError),
                  onChanged: (v) {
                    final parsed = Decimal.tryParse(v);
                    final activeCurrency = currencies.firstWhere(
                      (c) => c.code == (price?.currencyCode ?? selected.code),
                      orElse: () => selected,
                    );
                    final error = PriceValidator.validate(
                      parsed,
                      activeCurrency,
                      l10n,
                    );
                    setState(() => _amountError = error);
                    if (parsed != null) {
                      context.read<ListingFormBloc>().add(
                        FieldChanged.priceAmount(parsed),
                      );
                    }
                  },
                ),
                if (price != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  PricePreviewSubline(
                    amount: price.amount,
                    currency: currencies.firstWhere(
                      (c) => c.code == price.currencyCode,
                      orElse: () => selected,
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
