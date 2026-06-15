import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/listing_form_state.dart';
import '../bloc/listing_form_bloc.dart';
import '../bloc/listing_form_event.dart';
import '../widgets/express_form_fields.dart';
import '../widgets/publish_success_dialog.dart';
import '../widgets/step_media.dart';
import '../widgets/submit_failure_dialog.dart';

/// Phase 32 — the "Express / سريع" CREATE flow: a fast single-scroll form with
/// the Al Nujom Design System add-listing aesthetic (flat big rounded fields,
/// segmented purpose pills, two-up rows). It is the third option behind the
/// create-mode toggle, alongside the detail-style form and the classic stepper.
///
/// Like the detail form, it does NOT create its own bloc — it reads the
/// EXISTING [ListingFormBloc] (create mode) and dispatches the EXISTING
/// [FieldChanged] / media / [SubmitRequested] events, so it shares the same
/// validation + `submit_listing` path (and the flush-before-submit fix).
class ListingExpressFormPage extends StatelessWidget {
  const ListingExpressFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return BlocConsumer<ListingFormBloc, ListingFormState>(
      listenWhen: (prev, curr) =>
          prev.lastSubmitFailure != curr.lastSubmitFailure ||
          prev.submitSucceeded != curr.submitSucceeded,
      listener: (context, state) {
        final failure = state.lastSubmitFailure;
        if (failure != null) {
          showDialog<void>(
            context: context,
            builder: (dialogCtx) => BlocProvider.value(
              value: context.read<ListingFormBloc>(),
              child: SubmitFailureDialog(failure: failure),
            ),
          );
        }
        if (state.submitSucceeded) {
          showPublishSuccess(context).then((_) {
            if (context.mounted) context.go(AppRoutes.shellHome);
          });
        }
      },
      builder: (context, state) {
        if (state.loadInProgress || !state.isReady) {
          return Center(child: appInlineSpinner(context));
        }
        final busy = state.submitInProgress || state.saveInProgress;
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                children: [
                  _ExpressHint(l10n: l10n, colors: colors, styles: styles),
                  const SizedBox(height: AppSpacing.lg),
                  const StepMedia(),
                  const SizedBox(height: AppSpacing.lg),
                  const ExpressTitleField(),
                  const SizedBox(height: AppSpacing.lg),
                  const ExpressClassification(),
                  const SizedBox(height: AppSpacing.lg),
                  const ExpressPriceArea(),
                  const SizedBox(height: AppSpacing.lg),
                  const ExpressLocation(),
                  const SizedBox(height: AppSpacing.lg),
                  const ExpressFactsContact(),
                ],
              ),
            ),
            _SubmitBar(busy: busy),
          ],
        );
      },
    );
  }
}

class _ExpressHint extends StatelessWidget {
  const _ExpressHint({
    required this.l10n,
    required this.colors,
    required this.styles,
  });

  final AppLocalizations l10n;
  final AppColors colors;
  final AppTextStyles styles;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: appRadius(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.zap, size: AppSpacing.lg, color: colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.createExpressHint,
              style: styles.bodyMedium.copyWith(color: colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: BorderDirectional(top: BorderSide(color: colors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: AppButton(
            label: l10n.formDetailSubmitButton,
            icon: Icons.check_circle_outline,
            expanded: true,
            loading: busy,
            onPressed: busy
                ? null
                : () => context.read<ListingFormBloc>().add(
                    const SubmitRequested(),
                  ),
          ),
        ),
      ),
    );
  }
}
