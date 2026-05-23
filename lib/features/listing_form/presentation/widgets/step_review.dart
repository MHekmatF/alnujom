import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/listing_form_state.dart';
import '../../domain/entities/listing_media.dart';
import '../../domain/repositories/listings_repository.dart';
import '../bloc/listing_form_bloc.dart';
import '../bloc/listing_form_event.dart';

class StepReview extends StatelessWidget {
  const StepReview({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<ListingFormBloc, ListingFormState>(
      builder: (context, state) {
        final listing = state.draftListing;
        if (listing == null) return const SizedBox.shrink();
        final details = state.draftDetails;
        final price = state.draftPrice;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.media.isNotEmpty) _MediaSection(media: state.media),
            _Section(
              title: l10n.listingFormStepBasicsTitle,
              onEdit: () => context.read<ListingFormBloc>().add(
                const JumpToStep(ListingFormStep.basics),
              ),
              rows: [
                (l10n.fieldLabelTitle, listing.title),
                (l10n.fieldLabelPurpose, listing.purpose.name),
                (l10n.fieldLabelPropertyType, listing.propertyType.name),
              ],
            ),
            _Section(
              title: l10n.listingFormStepLocationTitle,
              onEdit: () => context.read<ListingFormBloc>().add(
                const JumpToStep(ListingFormStep.location),
              ),
              rows: [
                (l10n.fieldLabelGovernorate, listing.governorateId ?? '—'),
                (l10n.fieldLabelCity, listing.cityId ?? '—'),
                (l10n.fieldLabelArea, listing.areaId ?? '—'),
                (l10n.fieldLabelAddressText, listing.addressText ?? '—'),
              ],
            ),
            _Section(
              title: l10n.listingFormStepDetailsTitle,
              onEdit: () => context.read<ListingFormBloc>().add(
                const JumpToStep(ListingFormStep.details),
              ),
              rows: [
                (l10n.fieldLabelAreaSize, listing.areaSize?.toString() ?? '—'),
                if (listing.propertyType.name == 'apartment' ||
                    listing.propertyType.name == 'villa') ...[
                  (l10n.fieldLabelRooms, listing.rooms?.toString() ?? '—'),
                  (
                    l10n.fieldLabelBathrooms,
                    listing.bathrooms?.toString() ?? '—',
                  ),
                ],
                (l10n.fieldLabelFloor, listing.floor?.toString() ?? '—'),
                (l10n.fieldLabelDescription, details?.description ?? '—'),
                (
                  l10n.fieldLabelAmenities,
                  (details?.amenities ?? const <String>[]).join(', '),
                ),
              ],
            ),
            _Section(
              title: l10n.listingFormStepPricesTitle,
              onEdit: () => context.read<ListingFormBloc>().add(
                const JumpToStep(ListingFormStep.prices),
              ),
              rows: [
                (l10n.fieldLabelCurrency, price?.currencyCode ?? '—'),
                (l10n.fieldLabelPrice, price?.amount.toString() ?? '—'),
              ],
            ),
            _Section(
              title: l10n.listingFormStepVisibilityTitle,
              onEdit: () => context.read<ListingFormBloc>().add(
                const JumpToStep(ListingFormStep.visibility),
              ),
              rows: [
                (
                  l10n.fieldLabelLocationVisibility,
                  listing.locationVisibility.name,
                ),
                (
                  l10n.fieldLabelContactNameVisibility,
                  listing.contactNameVisibility.name,
                ),
                (l10n.fieldLabelPhone, listing.phone ?? '—'),
                (l10n.fieldLabelWhatsapp, listing.whatsapp ?? '—'),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.rows,
    required this.onEdit,
  });

  final String title;
  final List<(String, String)> rows;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: onEdit,
                  child: Text(l10n.listingFormJumpToStepButton),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsetsDirectional.only(
                  bottom: AppSpacing.xs,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        row.$1,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.$2.isEmpty ? '—' : row.$2,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal carousel of watermarked thumbnails shown at the top of the
/// Review step. Read-only — no long-press actions. The main image (`is_main`)
/// renders a "Main" badge. An Edit button jumps back to the media step.
class _MediaSection extends StatelessWidget {
  const _MediaSection({required this.media});

  final List<ListingMedia> media;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sorted = [...media]
      ..sort((a, b) => a.ordering.compareTo(b.ordering));
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.mediaReviewCarouselLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => context.read<ListingFormBloc>().add(
                    const JumpToStep(ListingFormStep.media),
                  ),
                  child: Text(l10n.listingFormJumpToStepButton),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: sorted.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final m = sorted[index];
                  return _ReviewThumbnail(
                    media: m,
                    mainBadge: m.isMain
                        ? l10n.mediaThumbnailMainBadge
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewThumbnail extends StatelessWidget {
  const _ReviewThumbnail({required this.media, this.mainBadge});

  final ListingMedia media;
  final String? mainBadge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildPreview(scheme),
            if (mainBadge != null)
              Positioned(
                top: AppSpacing.xs,
                right: AppSpacing.xs,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Text(
                    mainBadge!,
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(ColorScheme scheme) {
    if (media.kind == ListingMediaKind.video) {
      return Container(
        color: scheme.surfaceContainerHigh,
        alignment: Alignment.center,
        child: Icon(Icons.play_arrow, color: scheme.onSurfaceVariant, size: 32),
      );
    }
    final path = media.storagePath;
    if (path == null) {
      return Container(
        color: scheme.errorContainer,
        child: Icon(Icons.broken_image_outlined, color: scheme.error),
      );
    }
    final url = getIt<ListingsRepository>().getMediaPublicUrl(
      bucket: 'listing-images',
      path: path,
    );
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(color: scheme.surfaceContainerHigh),
      errorWidget: (_, _, _) => Container(
        color: scheme.errorContainer,
        child: Icon(Icons.broken_image_outlined, color: scheme.error),
      ),
    );
  }
}
