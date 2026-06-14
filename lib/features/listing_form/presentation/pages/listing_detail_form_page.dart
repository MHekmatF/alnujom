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
import '../widgets/detail_form_sections.dart';
import '../widgets/publish_success_dialog.dart';
import '../widgets/step_media.dart';
import '../widgets/submit_failure_dialog.dart';

/// Which CREATE-flow layout the publisher last chose, persisted for the app
/// session (a process-lifetime [ValueNotifier], reset on a cold start). The
/// in-page [AppSegmentedControl] toggle on [ListingFormPage] reads + writes it;
/// `true` = the single-scroll detail view (the default), `false` = the classic
/// stepper. EDIT mode ignores this and always uses the stepper.
final ValueNotifier<bool> createFlowUsesDetailView = ValueNotifier<bool>(true);

/// Phase 031 (WS-A) — detail-style CREATE form.
///
/// A single-scroll alternative to the seven-step stepper whose sections appear
/// in the SAME visual order as the read-only listing-details page, so the
/// publisher fills in the listing the way buyers will eventually see it:
///
///   cover/media → title → purpose + property type → price → location +
///   address → key facts → amenities → description → contact + visibility.
///
/// It does NOT create its own bloc — it reads the EXISTING [ListingFormBloc]
/// already provided by [ListingFormPage] (create mode) and dispatches the
/// EXISTING [FieldChanged] / media / [SubmitRequested] events. The Submit
/// button runs the SAME validation+submit path as the stepper's Review step
/// (the bloc's [SubmitRequested] handler validates first, then calls the
/// `submit_listing` RPC, landing the listing in pending_review).
///
/// Inline field validation lives in the individual section widgets
/// (`detail_form_sections.dart`); the success / failure dialogs mirror the
/// stepper page's [BlocConsumer] listener so both flows celebrate / recover
/// identically.
class ListingDetailFormPage extends StatelessWidget {
  const ListingDetailFormPage({super.key});

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
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Preview hint — frames the whole form as a buyer-eye
                    // preview the publisher fills in top-to-bottom.
                    _PreviewHint(l10n: l10n, colors: colors, styles: styles),
                    const SizedBox(height: AppSpacing.lg),
                    // 1. Cover / media — reuses StepMedia (add affordances +
                    //    reorderable MediaPicker grid) verbatim.
                    const StepMedia(),
                    const SizedBox(height: AppSpacing.lg),
                    // 2. Title.
                    const DetailFormTitleSection(),
                    const SizedBox(height: AppSpacing.lg),
                    // 3. Purpose + property type.
                    const DetailFormClassificationSection(),
                    const SizedBox(height: AppSpacing.lg),
                    // 4. Price.
                    const DetailFormPriceSection(),
                    const SizedBox(height: AppSpacing.lg),
                    // 5. Location + address.
                    const DetailFormLocationSection(),
                    const SizedBox(height: AppSpacing.lg),
                    // 6. Key facts (rooms · bathrooms · area · floor).
                    const DetailFormFactsSection(),
                    const SizedBox(height: AppSpacing.lg),
                    // 7. Amenities.
                    const DetailFormAmenitiesSection(),
                    const SizedBox(height: AppSpacing.lg),
                    // 8. Description.
                    const DetailFormDescriptionSection(),
                    const SizedBox(height: AppSpacing.lg),
                    // 9. Contact + visibility.
                    const DetailFormContactSection(),
                  ],
                ),
              ),
            ),
            _SubmitBar(busy: busy),
          ],
        );
      },
    );
  }
}

class _PreviewHint extends StatelessWidget {
  const _PreviewHint({
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
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: appRadius(AppRadii.md),
        border: Border.all(color: colors.primary.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.eye, size: AppSpacing.lg, color: colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.formDetailPreviewHint,
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
