import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/elevation.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/listing_form_state.dart';
import '../bloc/listing_form_bloc.dart';
import '../bloc/listing_form_event.dart';
import '../widgets/step_basics.dart';
import '../widgets/step_details.dart';
import '../widgets/step_location.dart';
import '../widgets/step_media.dart';
import '../widgets/step_prices.dart';
import '../widgets/step_progress_indicator.dart';
import '../widgets/step_review.dart';
import '../widgets/publish_success_dialog.dart';
import '../widgets/step_visibility.dart';
import '../widgets/submit_failure_dialog.dart';

class ListingFormPage extends StatelessWidget {
  const ListingFormPage({super.key, required this.mode, this.listingId});

  final ListingFormMode mode;
  final String? listingId;

  @override
  Widget build(BuildContext context) {
    final authState = getIt<AuthBloc>().state;
    final publisherUserId = authState is Authenticated
        ? authState.profile.userId
        : null;

    return BlocProvider<ListingFormBloc>(
      create: (_) {
        final bloc = getIt<ListingFormBloc>();
        if (publisherUserId != null) {
          bloc.attachContext(publisherUserId: publisherUserId, mode: mode);
          bloc.add(LoadOrCreateDraftRequested(listingId: listingId));
        }
        return bloc;
      },
      child: const _ListingFormBody(),
    );
  }
}

class _ListingFormBody extends StatelessWidget {
  const _ListingFormBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocConsumer<ListingFormBloc, ListingFormState>(
      listenWhen: (prev, curr) =>
          prev.lastSubmitFailure != curr.lastSubmitFailure ||
          prev.submitSucceeded != curr.submitSucceeded ||
          prev.savedAndExited != curr.savedAndExited,
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
          // Celebrate the publish (confetti + animated check), then return home.
          showPublishSuccess(context).then((_) {
            if (context.mounted) context.go(AppRoutes.shellHome);
          });
        }
        if (state.savedAndExited) {
          context.go(AppRoutes.shellHome);
        }
      },
      builder: (context, state) {
        final colors = AppColors.of(context);
        final styles = AppTextStyles.of(context);
        return Scaffold(
          backgroundColor: colors.surface,
          appBar: AppBar(
            title: Text(
              _titleForStep(state.currentStep, l10n),
              style: styles.titleLarge.copyWith(color: colors.onSurface),
            ),
            leading: AppButton.iconButton(
              icon: Icons.arrow_back,
              label: l10n.listingFormBackButton,
              onPressed: state.currentStep.previous == null
                  ? () => context.go(AppRoutes.shellHome)
                  : () => context.read<ListingFormBloc>().add(
                      JumpToStep(state.currentStep.previous!),
                    ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                child: AppButton(
                  label: l10n.listingFormSaveAndExitButton,
                  variant: AppButtonVariant.text,
                  size: AppButtonSize.dense,
                  onPressed: state.saveInProgress
                      ? null
                      : () => context.read<ListingFormBloc>().add(
                          const SaveStepAndExit(),
                        ),
                ),
              ),
            ],
          ),
          body: state.loadInProgress
              ? Center(child: appInlineSpinner(context))
              : !state.isReady
              ? Padding(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
                  child: Center(
                    child: Text(
                      state.lastSaveError ?? l10n.listingFormLoadingMessage,
                      textAlign: TextAlign.center,
                      style: styles.bodyLarge.copyWith(color: colors.textMuted),
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: StepProgressIndicator(
                        currentStep: state.currentStep,
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          AppSpacing.xl,
                        ),
                        child: _renderStep(state.currentStep),
                      ),
                    ),
                    _BottomNav(state: state),
                  ],
                ),
        );
      },
    );
  }

  Widget _renderStep(ListingFormStep step) {
    switch (step) {
      case ListingFormStep.basics:
        return const StepBasics();
      case ListingFormStep.location:
        return const StepLocation();
      case ListingFormStep.details:
        return const StepDetails();
      case ListingFormStep.prices:
        return const StepPrices();
      case ListingFormStep.visibility:
        return const StepVisibility();
      case ListingFormStep.media:
        return const StepMedia();
      case ListingFormStep.review:
        return const StepReview();
    }
  }

  String _titleForStep(ListingFormStep step, AppLocalizations l10n) {
    switch (step) {
      case ListingFormStep.basics:
        return l10n.listingFormStepBasicsTitle;
      case ListingFormStep.location:
        return l10n.listingFormStepLocationTitle;
      case ListingFormStep.details:
        return l10n.listingFormStepDetailsTitle;
      case ListingFormStep.prices:
        return l10n.listingFormStepPricesTitle;
      case ListingFormStep.visibility:
        return l10n.listingFormStepVisibilityTitle;
      case ListingFormStep.media:
        return l10n.listingFormStepMediaTitle;
      case ListingFormStep.review:
        return l10n.listingFormStepReviewTitle;
    }
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.state});

  final ListingFormState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final elevation = AppElevation.of(context);
    final isLastStep = state.currentStep == ListingFormStep.review;
    final canGoBack = state.currentStep.previous != null;
    final busy = state.saveInProgress || state.submitInProgress;

    final bar = Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: BorderDirectional(
          top: BorderSide(color: colors.outline),
        ),
        boxShadow: elevation.level1,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Row(
            children: [
              if (canGoBack) ...[
                Expanded(
                  child: AppButton(
                    label: l10n.listingFormBackButton,
                    variant: AppButtonVariant.outlined,
                    expanded: true,
                    onPressed: () => context.read<ListingFormBloc>().add(
                      JumpToStep(state.currentStep.previous!),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                flex: 2,
                child: AppButton(
                  label: isLastStep
                      ? l10n.listingFormSubmitButton
                      : l10n.listingFormContinueButton,
                  icon: isLastStep ? Icons.check_circle_outline : null,
                  expanded: true,
                  loading: busy,
                  onPressed: busy
                      ? null
                      : () {
                          if (isLastStep) {
                            context.read<ListingFormBloc>().add(
                              const SubmitRequested(),
                            );
                          } else {
                            context.read<ListingFormBloc>().add(
                              const SaveStepAndContinue(),
                            );
                          }
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return bar;
  }
}
