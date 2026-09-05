// Plan A36 — the tail of a paged list.
//
// A spinner while the next page is in flight, an outlined button otherwise.
// It also asks for the page the moment it is built, so scrolling to the end is
// enough on its own; the button is the retry after a failed page. The cubit
// behind it must ignore a second call while one is in flight, which every
// caller in this codebase does.
import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../theme/spacing.dart';
import 'app_button.dart';
import 'app_spinner.dart';

class LoadMoreRow extends StatelessWidget {
  const LoadMoreRow({required this.loading, required this.onLoad, super.key});

  final bool loading;
  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context) {
    if (!loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onLoad());
    }
    final loc = AppStrings.of(context).loc;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: loading
            ? const AppSpinner()
            : AppButton(
                label: loc.listLoadMore,
                variant: AppButtonVariant.outlined,
                size: AppButtonSize.dense,
                onPressed: onLoad,
              ),
      ),
    );
  }
}
