import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/radii.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../core/widgets/_widget_support.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_spinner.dart';
import '../../../../../core/widgets/app_toast.dart';
import '../../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/presentation/widgets/listing_display/listing_gallery.dart';
import '../../domain/entities/revision_diff.dart';
import '../bloc/revision_review_bloc.dart';
import '../widgets/approve_confirmation_dialog.dart';
import '../widgets/reject_reason_dialog.dart';

/// Phase 031 (WS-B) — admin review screen for one pending stay-live revision.
///
/// Shows a compact CURRENT-vs-PROPOSED field summary plus the staged media,
/// with Approve (`apply_listing_revision`) and Reject (`reject_listing_revision`)
/// actions. Pushed via Navigator from the pending-review queue (no go_router
/// route added).
class RevisionReviewPage extends StatelessWidget {
  const RevisionReviewPage({
    super.key,
    required this.revisionId,
    required this.listingId,
  });

  final String revisionId;
  final String listingId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RevisionReviewBloc>(
      create: (_) => getIt<RevisionReviewBloc>()
        ..add(RevisionReviewLoad(revisionId: revisionId, listingId: listingId)),
      child: const _RevisionReviewView(),
    );
  }
}

class _RevisionReviewView extends StatelessWidget {
  const _RevisionReviewView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DcCrownScaffold(
      title: l10n.adminRevisionReviewTitle,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.shellHome),
      ),
      body: BlocConsumer<RevisionReviewBloc, RevisionReviewState>(
        listenWhen: (prev, curr) =>
            (curr.outcome != null && prev.outcome == null) ||
            (curr.failure != null && prev.failure != curr.failure),
        listener: (ctx, state) {
          if (state.outcome != null) {
            final msg = state.outcome == RevisionMutatorOutcome.applied
                ? l10n.adminRevisionApprovedToast
                : l10n.adminRevisionRejectedToast;
            AppToast.success(ctx, msg);
            Navigator.of(ctx).pop(true);
            return;
          }
          if (state.failure != null) {
            AppToast.error(ctx, state.failure!.message);
          }
        },
        builder: (ctx, state) {
          if (state.isLoading && state.diff == null) {
            return const AppSpinner.page();
          }
          if (state.failure != null && state.diff == null) {
            return _ErrorState(message: state.failure!.message);
          }
          if (state.diff == null) return const SizedBox.shrink();
          return _RevisionBody(diff: state.diff!);
        },
      ),
      bottomNavigationBar: BlocBuilder<RevisionReviewBloc, RevisionReviewState>(
        builder: (ctx, state) => _BottomBar(state: state),
      ),
    );
  }
}

class _RevisionBody extends StatelessWidget {
  const _RevisionBody({required this.diff});

  final RevisionDiff diff;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final styles = AppTextStyles.of(context);
    final colors = AppColors.of(context);
    final changed = diff.changedKeys;
    final media = diff.revision.manifest.map((m) => m.toMedia('')).toList()
      ..sort((a, b) => a.ordering.compareTo(b.ordering));

    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      children: [
        // Staged media (the proposed gallery).
        if (media.isNotEmpty) ...[
          Text(l10n.adminRevisionProposedMediaLabel, style: styles.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          ListingGallery(media: media),
          const SizedBox(height: AppSpacing.lg),
        ],

        Text(l10n.adminRevisionChangesLabel, style: styles.titleMedium),
        const SizedBox(height: AppSpacing.sm),

        if (changed.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: AppSpacing.md,
            ),
            child: Text(
              l10n.adminRevisionNoFieldChanges,
              style: styles.bodyMedium.copyWith(color: colors.textMuted),
            ),
          )
        else
          for (final key in changed)
            _DiffRow(
              label: _fieldLabel(l10n, key),
              before: _format(diff.current[key]),
              after: _format(diff.proposed[key]),
            ),

        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  String _format(Object? v) {
    if (v == null) return '—';
    if (v is List) {
      if (v.isEmpty) return '—';
      return v.map((e) => e.toString()).join(', ');
    }
    final s = v.toString().trim();
    return s.isEmpty ? '—' : s;
  }

  String _fieldLabel(AppLocalizations l10n, String key) {
    switch (key) {
      case 'title':
        return l10n.fieldLabelTitle;
      case 'purpose':
        return l10n.fieldLabelPurpose;
      case 'property_type':
        return l10n.fieldLabelPropertyType;
      case 'price_amount':
        return l10n.adminRevisionFieldPrice;
      case 'price_currency_code':
        return l10n.adminRevisionFieldCurrency;
      case 'address_text':
        return l10n.adminRevisionFieldAddress;
      case 'area_size':
        return l10n.adminRevisionFieldAreaSize;
      case 'rooms':
        return l10n.adminRevisionFieldRooms;
      case 'bathrooms':
        return l10n.adminRevisionFieldBathrooms;
      case 'floor':
        return l10n.adminRevisionFieldFloor;
      case 'description':
        return l10n.adminRevisionFieldDescription;
      case 'amenities':
        return l10n.adminRevisionFieldAmenities;
      case 'year_built':
        return l10n.adminRevisionFieldYearBuilt;
      case 'furnished':
        return l10n.adminRevisionFieldFurnished;
      case 'parking':
        return l10n.adminRevisionFieldParking;
      case 'phone':
        return l10n.adminRevisionFieldPhone;
      case 'whatsapp':
        return l10n.adminRevisionFieldWhatsapp;
      case 'governorate_id':
      case 'city_id':
      case 'area_id':
        return l10n.adminRevisionFieldLocation;
      case 'location_visibility':
        return l10n.adminRevisionFieldLocationVisibility;
      case 'contact_name_visibility':
        return l10n.adminRevisionFieldContactVisibility;
      default:
        return key;
    }
  }
}

/// One current → proposed field comparison row.
class _DiffRow extends StatelessWidget {
  const _DiffRow({
    required this.label,
    required this.before,
    required this.after,
  });

  final String label;
  final String before;
  final String after;

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyles.of(context);
    final colors = AppColors.of(context);

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: appRadius(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: styles.labelLarge.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  before,
                  style: styles.bodyMedium.copyWith(
                    color: colors.textMuted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.arrow_forward,
                size: AppSpacing.md,
                color: colors.textMuted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  after,
                  style: styles.bodyMedium.copyWith(color: colors.onSurface),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.state});

  final RevisionReviewState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final isReady = state.diff != null && !state.isLoading;
    final disabled = !isReady || state.isMutatorInFlight;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          border: Border(top: BorderSide(color: colors.outline)),
        ),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: AppButton(
                label: l10n.adminPreviewCtaReject,
                variant: AppButtonVariant.destructive,
                onPressed: disabled ? null : () => _onReject(context),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: AppButton(
                label: l10n.adminRevisionApproveCta,
                variant: AppButtonVariant.filledSuccess,
                onPressed: disabled ? null : () => _onApprove(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onApprove(BuildContext context) async {
    final confirmed = await ApproveConfirmationDialog.show(context);
    if (confirmed == true && context.mounted) {
      context.read<RevisionReviewBloc>().add(
        const RevisionReviewApprovePressed(),
      );
    }
  }

  Future<void> _onReject(BuildContext context) async {
    final result = await RejectReasonDialog.show(context);
    if (result != null && context.mounted) {
      context.read<RevisionReviewBloc>().add(
        RevisionReviewRejectPressed(
          preset: result.preset,
          detail: result.detail,
        ),
      );
    }
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: styles.bodyLarge.copyWith(color: colors.error),
        ),
      ),
    );
  }
}
