import 'package:flutter/material.dart';

import '../theme/spacing.dart';
import '../theme/typography.dart';

class PriceTag extends StatelessWidget {
  const PriceTag({
    required this.amount,
    required this.currency,
    this.altText,
    super.key,
  });

  final String amount;
  final String currency;
  final String? altText;

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyles.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$amount $currency',
          textDirection: TextDirection.ltr,
          style: styles.priceLarge,
        ),
        if (altText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(altText!, style: styles.bodyMedium),
        ],
      ],
    );
  }
}
