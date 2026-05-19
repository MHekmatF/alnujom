import 'package:flutter/material.dart';

import '../../domain/entities/listing_form_state.dart';

class StepProgressIndicator extends StatelessWidget {
  const StepProgressIndicator({super.key, required this.currentStep});

  final ListingFormStep currentStep;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentIndex = currentStep.index0;
    return Row(
      children: List<Widget>.generate(ListingFormStep.values.length, (i) {
        final Color color;
        if (i < currentIndex) {
          color = scheme.primary;
        } else if (i == currentIndex) {
          color = scheme.primary;
        } else {
          color = scheme.outlineVariant;
        }
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      }),
    );
  }
}
