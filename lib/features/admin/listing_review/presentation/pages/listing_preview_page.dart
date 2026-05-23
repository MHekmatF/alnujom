import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/errors/failure.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/presentation/widgets/listing_display/listing_amenities_block.dart';
import '../../../../../shared/presentation/widgets/listing_display/listing_description_block.dart';
import '../../../../../shared/presentation/widgets/listing_display/listing_gallery.dart';
import '../../../../../shared/presentation/widgets/listing_display/listing_location_block.dart';
import '../../../../../shared/presentation/widgets/listing_display/listing_price_block.dart';
import '../../../../currencies/domain/entities/currency.dart';
import '../bloc/listing_preview_bloc.dart';
import '../widgets/approve_confirmation_dialog.dart';

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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminPreviewTitle)),
      body: BlocConsumer<ListingPreviewBloc, ListingPreviewState>(
        listenWhen: (prev, curr) =>
            (curr.lastSuccess != null && prev.lastSuccess == null) ||
            (curr.failure != null && prev.failure != curr.failure),
        listener: _handleStateSideEffects,
        builder: (ctx, state) {
          if (state.isLoading && state.preview == null) {
            return const Center(child: CircularProgressIndicator());
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

  void _handleStateSideEffects(
    BuildContext ctx,
    ListingPreviewState state,
  ) {
    final l10n = AppLocalizations.of(ctx)!;
    if (state.lastSuccess != null) {
      final msg = state.lastSuccess is ApproveSuccess
          ? l10n.adminToastApproveSuccess
          : l10n.adminToastApproveSuccess; // Phase 4 adds adminToastRejectSuccess
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
      // Pop back to the queue page (the queue will refresh on-pop via the
      // RefreshIndicator pattern when the admin pulls).
      ctx.pop();
      return;
    }
    if (state.failure != null) {
      final msg = _localizedFailureMessage(l10n, state.failure!);
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
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
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Gallery
        ListingGallery(media: preview.media),
        const SizedBox(height: AppSpacing.lg),

        // Title
        Text(
          l.title.isEmpty ? '—' : l.title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.md),

        // Price (Phase 12 ships without a per-page currency resolver — the
        // primary price is rendered in the publisher's stored currency).
        Builder(
          builder: (ctx) {
            if (preview.prices.isEmpty) return const SizedBox.shrink();
            final primary =
                preview.prices.firstWhere((p) => p.isPrimary, orElse: () => preview.prices.first);
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
    final theme = Theme.of(context);
    final isReady = state.preview != null && !state.isLoading;
    final disabled = !isReady || state.isMutatorInFlight;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                // Phase 4 (US2) wires the reject path. Phase 3 keeps the
                // button rendered but disabled per the contract.
                onPressed: null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                child: Text(l10n.adminPreviewCtaReject),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: FilledButton(
                onPressed: disabled
                    ? null
                    : () => _onApprovePressed(context),
                child: Text(l10n.adminPreviewCtaApprove),
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
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ),
    );
  }
}
