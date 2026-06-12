import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../../core/di/injection.dart';
import '../../../../../core/errors/failure.dart';
import '../../../../../core/security/permission_checker.dart';
import '../../../../../core/security/permission_keys.dart';
import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/radii.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../core/widgets/_widget_support.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_spinner.dart';
import '../../../../../core/widgets/app_toast.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/presentation/widgets/listing_display/listing_amenities_block.dart';
import '../../../../../shared/presentation/widgets/listing_display/listing_description_block.dart';
import '../../../../../shared/presentation/widgets/listing_display/listing_gallery.dart';
import '../../../../../shared/presentation/widgets/listing_display/listing_location_block.dart';
import '../../../../../shared/presentation/widgets/listing_display/listing_price_block.dart';
import '../../../../currencies/domain/entities/currency.dart';
import '../bloc/listing_preview_bloc.dart';
import '../widgets/approve_confirmation_dialog.dart';
import '../widgets/feature_listing_dialog.dart';
import '../widgets/reject_reason_dialog.dart';

/// Phase 12 — admin listing preview page.
/// Route: `/admin/listing-review/preview/:id`.
/// Contract: `contracts/phase12-listing-preview-page.md`.
///
/// Approve button is wired in this phase. Reject button is rendered but
/// disabled (Phase 4 / US2 enables it).
class ListingPreviewPage extends StatelessWidget {
  const ListingPreviewPage({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ListingPreviewBloc>(
      create: (_) =>
          getIt<ListingPreviewBloc>()..add(ListingPreviewLoad(listingId)),
      child: const _ListingPreviewView(),
    );
  }
}

class _ListingPreviewView extends StatelessWidget {
  const _ListingPreviewView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Phase 25 — the feature/unfeature action is gated on `listings.edit_any`,
    // mirroring the permission gating used across the admin surfaces
    // (see role_editor_page / auth_redirect). Cached, synchronous check.
    final canFeature = getIt<PermissionChecker>().has(
      PermissionKeys.listingsEditAny,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminPreviewTitle),
        actions: [
          if (canFeature)
            BlocBuilder<ListingPreviewBloc, ListingPreviewState>(
              builder: (ctx, state) => _FeatureAction(state: state),
            ),
        ],
      ),
      body: BlocConsumer<ListingPreviewBloc, ListingPreviewState>(
        listenWhen: (prev, curr) =>
            (curr.lastSuccess != null && prev.lastSuccess == null) ||
            (curr.failure != null && prev.failure != curr.failure),
        listener: _handleStateSideEffects,
        builder: (ctx, state) {
          if (state.isLoading && state.preview == null) {
            return const AppSpinner.page();
          }
          if (state.failure != null && state.preview == null) {
            return _ErrorState(message: state.failure!.message);
          }
          if (state.preview == null) {
            return const SizedBox.shrink();
          }
          return _PreviewBody(state: state);
        },
      ),
      bottomNavigationBar: BlocBuilder<ListingPreviewBloc, ListingPreviewState>(
        builder: (ctx, state) => _StickyBottomBar(state: state),
      ),
    );
  }

  void _handleStateSideEffects(BuildContext ctx, ListingPreviewState state) {
    final l10n = AppLocalizations.of(ctx)!;
    final success = state.lastSuccess;
    if (success != null) {
      // Phase 25 — feature/unfeature stays on the page (the admin keeps
      // reviewing); only approve/reject pop back to the queue.
      if (success is FeatureSuccess) {
        final msg = success.result.isFeatured
            ? l10n.adminToastFeatureSuccess
            : l10n.adminToastUnfeatureSuccess;
        AppToast.success(ctx, msg);
        return;
      }
      final msg = success is RejectSuccess
          ? l10n.adminToastRejectSuccess
          : l10n.adminToastApproveSuccess;
      AppToast.success(ctx, msg);
      // Pop back to the queue page (the queue will refresh on-pop via the
      // RefreshIndicator pattern when the admin pulls).
      ctx.pop();
      return;
    }
    if (state.failure != null) {
      final msg = _localizedFailureMessage(l10n, state.failure!);
      AppToast.error(ctx, msg);
      // For race-condition failures, pop back to queue.
      if (state.failure is AlreadyActedOnFailure ||
          state.failure is InvalidStatusTransitionFailure) {
        ctx.pop();
      }
    }
  }

  String _localizedFailureMessage(AppLocalizations l10n, Failure f) {
    if (f is PermissionDeniedFailure) return l10n.adminErrorPermissionDenied;
    if (f is InvalidStatusTransitionFailure) {
      return l10n.adminErrorInvalidStatusTransition;
    }
    if (f is AlreadyActedOnFailure) return l10n.adminErrorAlreadyActedOn;
    if (f is InvalidReasonPresetFailure) {
      return l10n.adminErrorInvalidReasonPreset;
    }
    if (f is ReasonDetailTooLongFailure) {
      return l10n.adminErrorReasonDetailTooLong;
    }
    return l10n.adminErrorUnknown;
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({required this.state});

  final ListingPreviewState state;

  @override
  Widget build(BuildContext context) {
    final preview = state.preview!;
    final l = preview.listing;

    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      children: [
        // Gallery
        ListingGallery(media: preview.media),
        const SizedBox(height: AppSpacing.lg),

        // Title
        Text(
          l.title.isEmpty ? '—' : l.title,
          style: AppTextStyles.of(context).titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),

        // Phase 25 — current featured state (only when actively featured).
        if (preview.isFeatured) ...[
          _FeaturedBanner(featuredUntil: preview.featuredUntil!),
          const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.xs),

        // Price (Phase 12 ships without a per-page currency resolver — the
        // primary price is rendered in the publisher's stored currency).
        Builder(
          builder: (ctx) {
            if (preview.prices.isEmpty) return const SizedBox.shrink();
            final primary = preview.prices.firstWhere(
              (p) => p.isPrimary,
              orElse: () => preview.prices.first,
            );
            final currency = _stubCurrency(primary.currencyCode);
            return ListingPriceBlock(
              prices: preview.prices,
              displayCurrency: currency,
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),

        // Location
        if (preview.governorate != null &&
            preview.city != null &&
            preview.area != null)
          ListingLocationBlock(
            governorate: preview.governorate!,
            city: preview.city!,
            area: preview.area!,
            addressText: l.addressText,
          ),
        const SizedBox(height: AppSpacing.lg),

        // Amenities (List<String> per Phase 10 entity shape)
        if (preview.details != null &&
            preview.details!.amenities.isNotEmpty) ...[
          ListingAmenitiesBlock(amenities: preview.details!.amenities),
          const SizedBox(height: AppSpacing.lg),
        ],

        // Description
        if (preview.details?.description != null &&
            preview.details!.description!.trim().isNotEmpty) ...[
          ListingDescriptionBlock(description: preview.details!.description!),
          const SizedBox(height: AppSpacing.lg),
        ],

        // Bottom padding so the sticky bar doesn't overlap the last item.
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  /// Phase 12 ships without a Currency lookup in the preview path; we
  /// synthesize a minimal `Currency` from the price's `currencyCode` so
  /// `MoneyFormatter` can format the amount. Display details (Arabic name,
  /// custom decimals) fall back to safe defaults. A future spec MAY inject
  /// a `CurrenciesRepository` into the preview BLoC for richer rendering.
  Currency _stubCurrency(String code) {
    return Currency(
      code: code,
      nameAr: code,
      nameEn: code,
      symbol: code,
      isActive: true,
      sortOrder: 0,
      isSystem: false,
      displayDecimals: 2,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class _StickyBottomBar extends StatelessWidget {
  const _StickyBottomBar({required this.state});

  final ListingPreviewState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final isReady = state.preview != null && !state.isLoading;
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
                onPressed: disabled ? null : () => _onRejectPressed(context),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: AppButton(
                label: l10n.adminPreviewCtaApprove,
                variant: AppButtonVariant.filledSuccess,
                onPressed: disabled ? null : () => _onApprovePressed(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onApprovePressed(BuildContext context) async {
    final confirmed = await ApproveConfirmationDialog.show(context);
    if (confirmed == true && context.mounted) {
      context.read<ListingPreviewBloc>().add(
        const ListingPreviewApprovePressed(),
      );
    }
  }

  Future<void> _onRejectPressed(BuildContext context) async {
    final result = await RejectReasonDialog.show(context);
    if (result != null && context.mounted) {
      context.read<ListingPreviewBloc>().add(
        ListingPreviewRejectPressed(
          preset: result.preset,
          detail: result.detail,
        ),
      );
    }
  }
}

/// Phase 25 — app-bar action that opens the feature-duration chooser and
/// dispatches [ListingPreviewFeaturePressed]. Reflects current featured state
/// via a filled vs outlined star. Disabled while a mutator is in flight or the
/// preview hasn't loaded yet.
class _FeatureAction extends StatelessWidget {
  const _FeatureAction({required this.state});

  final ListingPreviewState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final preview = state.preview;
    final isReady = preview != null && !state.isLoading;
    final disabled = !isReady || state.isMutatorInFlight;
    final isFeatured = preview?.isFeatured ?? false;

    return IconButton(
      tooltip: l10n.adminPreviewActionFeature,
      icon: Icon(
        isFeatured ? Icons.star_rounded : Icons.star_outline_rounded,
        color: isFeatured ? colors.primary : null,
      ),
      onPressed: disabled ? null : () => _onFeaturePressed(context, isFeatured),
    );
  }

  Future<void> _onFeaturePressed(
    BuildContext context,
    bool isCurrentlyFeatured,
  ) async {
    final days = await FeatureListingDialog.show(
      context,
      isCurrentlyFeatured: isCurrentlyFeatured,
    );
    if (days != null && context.mounted) {
      context.read<ListingPreviewBloc>().add(
        ListingPreviewFeaturePressed(days: days),
      );
    }
  }
}

/// Phase 25 — inline "currently featured until {date}" banner shown in the
/// preview body when the listing has an active `featured_until`.
class _FeaturedBanner extends StatelessWidget {
  const _FeaturedBanner({required this.featuredUntil});

  final DateTime featuredUntil;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final dateStr = DateFormat.yMMMd(
      Localizations.localeOf(context).languageCode,
    ).format(featuredUntil.toLocal());

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: appRadius(AppRadii.md),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.star, size: AppSpacing.lg, color: colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.adminFeaturedUntil(dateStr),
              style: styles.labelLarge.copyWith(
                color: colors.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
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
