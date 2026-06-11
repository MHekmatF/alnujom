import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/listing_form_state.dart';
import '../../domain/entities/listing_media.dart';
import '../../domain/repositories/listings_repository.dart';
import '../bloc/listing_form_bloc.dart';
import '../bloc/listing_form_event.dart';
import 'step_section.dart';

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
            if (state.media.isNotEmpty) ...[
              _MediaSection(media: state.media),
              const SizedBox(height: AppSpacing.lg),
            ],
            _Section(
              icon: Icons.home_work_outlined,
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
            const SizedBox(height: AppSpacing.lg),
            _Section(
              icon: Icons.location_on_outlined,
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
            const SizedBox(height: AppSpacing.lg),
            _Section(
              icon: Icons.description_outlined,
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
            const SizedBox(height: AppSpacing.lg),
            _Section(
              icon: Icons.payments_outlined,
              title: l10n.listingFormStepPricesTitle,
              onEdit: () => context.read<ListingFormBloc>().add(
                const JumpToStep(ListingFormStep.prices),
              ),
              rows: [
                (l10n.fieldLabelCurrency, price?.currencyCode ?? '—'),
                (l10n.fieldLabelPrice, price?.amount.toString() ?? '—'),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              icon: Icons.visibility_outlined,
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

/// A grouped summary card for one step, with an Edit affordance that jumps back
/// to that step (existing navigation — no new routes added).
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.rows,
    required this.onEdit,
  });

  final IconData icon;
  final String title;
  final List<(String, String)> rows;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return StepSection(
      icon: icon,
      title: title,
      trailing: AppButton(
        label: l10n.listingFormJumpToStepButton,
        icon: Icons.edit_outlined,
        variant: AppButtonVariant.text,
        size: AppButtonSize.dense,
        onPressed: onEdit,
      ),
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: AppSpacing.sm,
              ),
              child: Divider(height: AppSpacing.xxs, color: colors.divider),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: AppSpacing.xxxl * 2 + AppSpacing.xl,
                child: Text(
                  rows[i].$1,
                  style: styles.bodyMedium.copyWith(color: colors.textMuted),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  rows[i].$2.isEmpty ? '—' : rows[i].$2,
                  style: styles.bodyLarge.copyWith(color: colors.onSurface),
                ),
              ),
            ],
          ),
        ],
      ],
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
    final sorted = [...media]..sort((a, b) => a.ordering.compareTo(b.ordering));
    return StepSection(
      icon: Icons.photo_library_outlined,
      title: l10n.mediaReviewCarouselLabel,
      trailing: AppButton(
        label: l10n.listingFormJumpToStepButton,
        icon: Icons.edit_outlined,
        variant: AppButtonVariant.text,
        size: AppButtonSize.dense,
        onPressed: () => context.read<ListingFormBloc>().add(
          const JumpToStep(ListingFormStep.media),
        ),
      ),
      children: [
        SizedBox(
          height: AppSpacing.xxxl * 2,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final m = sorted[index];
              return _ReviewThumbnail(
                media: m,
                mainBadge: m.isMain ? l10n.mediaThumbnailMainBadge : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReviewThumbnail extends StatelessWidget {
  const _ReviewThumbnail({required this.media, this.mainBadge});

  final ListingMedia media;
  final String? mainBadge;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return ClipRRect(
      borderRadius: appRadius(AppRadii.md),
      child: SizedBox(
        width: AppSpacing.xxxl * 2,
        height: AppSpacing.xxxl * 2,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildPreview(colors),
            if (mainBadge != null)
              PositionedDirectional(
                top: AppSpacing.xs,
                end: AppSpacing.xs,
                child: Container(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: appRadius(AppRadii.pill),
                  ),
                  child: Text(
                    mainBadge!,
                    style: styles.labelMedium.copyWith(color: colors.onPrimary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(AppColors colors) {
    if (media.kind == ListingMediaKind.video) {
      return Container(
        color: colors.surfaceVariant,
        alignment: Alignment.center,
        child: Icon(
          Icons.play_arrow,
          color: colors.textMuted,
          size: AppSpacing.xxl,
        ),
      );
    }
    final path = media.storagePath;
    if (path == null) {
      return Container(
        color: colors.error.withValues(alpha: 0.12),
        child: Icon(Icons.broken_image_outlined, color: colors.error),
      );
    }
    final url = getIt<ListingsRepository>().getMediaPublicUrl(
      bucket: 'listing-images',
      path: path,
    );
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(color: colors.surfaceVariant),
      errorWidget: (_, _, _) => Container(
        color: colors.error.withValues(alpha: 0.12),
        child: Icon(Icons.broken_image_outlined, color: colors.error),
      ),
    );
  }
}
