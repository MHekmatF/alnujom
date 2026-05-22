import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/listing_form_state.dart';
import '../bloc/listing_form_bloc.dart';
import '../bloc/listing_form_event.dart';
import '../widgets/step_basics.dart';
import '../widgets/step_details.dart';
import '../widgets/step_location.dart';
import '../widgets/step_media_placeholder.dart';
import '../widgets/step_prices.dart';
import '../widgets/step_progress_indicator.dart';
import '../widgets/step_review.dart';
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.listingFormSubmitSuccess)),
          );
          // Return to home; T100 wires the my-listings tile separately.
          context.go(AppRoutes.shellHome);
        }
        if (state.savedAndExited) {
          context.go(AppRoutes.shellHome);
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_titleForStep(state.currentStep, l10n)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: state.currentStep.previous == null
                  ? () => context.go(AppRoutes.shellHome)
                  : () => context.read<ListingFormBloc>().add(
                      JumpToStep(state.currentStep.previous!),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: state.saveInProgress
                    ? null
                    : () => context.read<ListingFormBloc>().add(
                        const SaveStepAndExit(),
                      ),
                child: Text(l10n.listingFormSaveAndExitButton),
              ),
            ],
          ),
          body: state.loadInProgress
              ? const Center(child: CircularProgressIndicator())
              : !state.isReady
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                    child: Text(
                      state.lastSaveError ?? l10n.listingFormLoadingMessage,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: StepProgressIndicator(
                        currentStep: state.currentStep,
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: _renderStep(state.currentStep),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: _BottomNav(state: state),
                      ),
                    ),
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
        return const StepMediaPlaceholder();
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
    final isLastStep = state.currentStep == ListingFormStep.review;
    final canGoBack = state.currentStep.previous != null;
    return Row(
      children: [
        if (canGoBack)
          Expanded(
            child: OutlinedButton(
              onPressed: () => context.read<ListingFormBloc>().add(
                JumpToStep(state.currentStep.previous!),
              ),
              child: Text(l10n.listingFormBackButton),
            ),
          ),
        if (canGoBack) const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: state.saveInProgress || state.submitInProgress
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
            child: state.saveInProgress || state.submitInProgress
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    isLastStep
                        ? l10n.listingFormSubmitButton
                        : l10n.listingFormContinueButton,
                  ),
          ),
        ),
      ],
    );
  }
}
