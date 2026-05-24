// lib/features/search/presentation/widgets/price_range_input.dart
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

class PriceRangeInput extends StatelessWidget {
  const PriceRangeInput({
    super.key,
    required this.minController,
    required this.maxController,
    required this.formKey,
  });

  final TextEditingController minController;
  final TextEditingController maxController;
  final GlobalKey<FormState> formKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: TextFormField(
              controller: minController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                hintText: l10n.search_filter_price_min_hint,
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 8),
            child: TextFormField(
              controller: maxController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                hintText: l10n.search_filter_price_max_hint,
              ),
              validator: (text) {
                if (minController.text.isNotEmpty &&
                    text != null &&
                    text.isNotEmpty) {
                  final minVal = double.tryParse(minController.text);
                  final maxVal = double.tryParse(text);
                  if (minVal != null && maxVal != null && minVal > maxVal) {
                    return l10n.search_filter_price_min_max_error;
                  }
                }
                return null;
              },
            ),
          ),
        ),
      ],
    );
  }
}
