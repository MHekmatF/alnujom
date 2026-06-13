import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/property_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../locations/domain/usecases/load_area_detail.dart';
import '../../../locations/domain/usecases/load_city_detail.dart';
import '../../../locations/domain/usecases/load_governorate_detail.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_form_state.dart';
import '../../domain/entities/listing_media.dart';
import '../../domain/entities/listing_price.dart';
import '../../domain/repositories/listings_repository.dart';
import '../../domain/usecases/validate_submit_payload.dart';
import '../bloc/listing_form_bloc.dart';
import '../bloc/listing_form_event.dart';
import '../util/listing_enum_labels.dart';
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
        // Phase 029 (F3) — resolve the location ids to localized display names
        // once (FutureBuilder), then render every section + the live preview.
        return _LocationNamesResolver(
          governorateId: listing.governorateId,
          cityId: listing.cityId,
          areaId: listing.areaId,
          builder: (context, locationNames) {
            final locationLine = _composeLocationLine(locationNames, l10n);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Phase 029 (F3) — live preview card fed from the draft state.
                _LivePreview(
                  listing: listing,
                  price: price,
                  media: state.media,
                  locationLine: locationLine,
                ),
                const SizedBox(height: AppSpacing.lg),
                // Phase 029 (F3) — required-field checklist mirroring the
                // ValidateSubmitPayload use case. Tapping a missing item jumps
                // to the offending step (reuses the JumpToStep event).
                _ValidationChecklist(state: state),
                const SizedBox(height: AppSpacing.lg),
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
                    (
                      l10n.fieldLabelPurpose,
                      listingPurposeLabel(listing.purpose, l10n),
                    ),
                    (
                      l10n.fieldLabelPropertyType,
                      propertyTypeLabel(listing.propertyType, l10n),
                    ),
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
                    (l10n.fieldLabelGovernorate, locationNames.governorate),
                    (l10n.fieldLabelCity, locationNames.city),
                    (l10n.fieldLabelArea, locationNames.area),
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
                    (
                      l10n.fieldLabelAreaSize,
                      listing.areaSize?.toString() ?? '—',
                    ),
                    if (listing.propertyType.isResidential) ...[
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
                      _locationVisibilityLabel(listing.locationVisibility, l10n),
                    ),
                    (
                      l10n.fieldLabelContactNameVisibility,
                      _contactVisibilityLabel(
                        listing.contactNameVisibility,
                        l10n,
                      ),
                    ),
                    (l10n.fieldLabelPhone, listing.phone ?? '—'),
                    (l10n.fieldLabelWhatsapp, listing.whatsapp ?? '—'),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Composes a single-line "Area, City, Governorate" string for the preview
  /// card, skipping any segment that is not yet resolved.
  static String _composeLocationLine(
    _LocationNames names,
    AppLocalizations l10n,
  ) {
    final segments = <String>[];
    for (final s in [names.area, names.city, names.governorate]) {
      if (s.isNotEmpty && s != '—') segments.add(s);
    }
    return segments.isEmpty
        ? l10n.listingFormPreviewLocationPlaceholder
        : segments.join('، ');
  }
}

String _locationVisibilityLabel(LocationVisibility v, AppLocalizations l10n) {
  switch (v) {
    case LocationVisibility.hidden:
      return l10n.locationVisibilityHidden;
    case LocationVisibility.approximate:
      return l10n.locationVisibilityApproximate;
    case LocationVisibility.exact:
      return l10n.locationVisibilityExact;
    case LocationVisibility.adminOnly:
      return l10n.locationVisibilityAdminOnly;
  }
}

String _contactVisibilityLabel(
  ContactNameVisibility v,
  AppLocalizations l10n,
) {
  switch (v) {
    case ContactNameVisibility.public:
      return l10n.contactNameVisibilityPublic;
    case ContactNameVisibility.adminOnly:
      return l10n.contactNameVisibilityAdminOnly;
  }
}

/// Resolved localized location display names for the current draft.
class _LocationNames {
  const _LocationNames({
    this.governorate = '—',
    this.city = '—',
    this.area = '—',
  });

  final String governorate;
  final String city;
  final String area;
}

/// Phase 029 (F3) — loads the governorate / city / area display names for the
/// given ids via the locations use cases (already injected for the location
/// step) and rebuilds [builder] with the resolved names. Falls back to the
/// dash placeholder while loading or on any lookup failure (behaviour on
/// persisted data is unchanged — this is display-only).
class _LocationNamesResolver extends StatefulWidget {
  const _LocationNamesResolver({
    required this.governorateId,
    required this.cityId,
    required this.areaId,
    required this.builder,
  });

  final String? governorateId;
  final String? cityId;
  final String? areaId;
  final Widget Function(BuildContext context, _LocationNames names) builder;

  @override
  State<_LocationNamesResolver> createState() => _LocationNamesResolverState();
}

class _LocationNamesResolverState extends State<_LocationNamesResolver> {
  late Future<_LocationNames> _future;
  String? _loadedKey;

  @override
  void initState() {
    super.initState();
    _future = _resolve(context);
    _loadedKey = _key;
  }

  @override
  void didUpdateWidget(_LocationNamesResolver oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-resolve only when one of the three ids actually changed.
    if (_key != _loadedKey) {
      _future = _resolve(context);
      _loadedKey = _key;
    }
  }

  String get _key =>
      '${widget.governorateId}|${widget.cityId}|${widget.areaId}';

  Future<_LocationNames> _resolve(BuildContext context) async {
    final locale = Localizations.localeOf(context);
    String gov = '—';
    String city = '—';
    String area = '—';
    final govId = widget.governorateId;
    final cityId = widget.cityId;
    final areaId = widget.areaId;
    if (govId != null && govId.isNotEmpty) {
      try {
        gov = (await getIt<LoadGovernorateDetail>()(govId)).localizedName(
          locale,
        );
      } catch (_) {
        /* keep dash */
      }
    }
    if (cityId != null && cityId.isNotEmpty) {
      try {
        city = (await getIt<LoadCityDetail>()(cityId)).localizedName(locale);
      } catch (_) {
        /* keep dash */
      }
    }
    if (areaId != null && areaId.isNotEmpty) {
      try {
        area = (await getIt<LoadAreaDetail>()(areaId)).localizedName(locale);
      } catch (_) {
        /* keep dash */
      }
    }
    return _LocationNames(governorate: gov, city: city, area: area);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LocationNames>(
      future: _future,
      builder: (context, snap) {
        final names = snap.data ?? const _LocationNames();
        return widget.builder(context, names);
      },
    );
  }
}

/// Phase 029 (F3) — live preview of how the listing will appear in the feed,
/// fed from the draft state. Reuses the shared [PropertyCard] (horizontal
/// layout) via a thin adapter — no fork of the card.
class _LivePreview extends StatelessWidget {
  const _LivePreview({
    required this.listing,
    required this.price,
    required this.media,
    required this.locationLine,
  });

  final Listing listing;
  final ListingPrice? price;
  final List<ListingMedia> media;
  final String locationLine;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    // Resolve the main image (or the first image) public URL for the preview.
    final mainImage = _resolveMainImage(media);
    String? imageUrl;
    if (mainImage?.storagePath != null) {
      imageUrl = getIt<ListingsRepository>().getMediaPublicUrl(
        bucket: 'listing-images',
        path: mainImage!.storagePath!,
      );
    }

    final title = listing.title.trim().isEmpty
        ? l10n.listingFormPreviewTitlePlaceholder
        : listing.title.trim();
    final amount = price?.amount.toString();
    final priceText = (amount == null || amount.isEmpty)
        ? l10n.listingFormPreviewPricePlaceholder
        : amount;
    final currency = price?.currencyCode ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.eye, size: AppSpacing.lg, color: colors.primary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              l10n.listingFormPreviewHeading,
              style: styles.labelLarge.copyWith(color: colors.onSurface),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (currency.isEmpty)
          PropertyCard(
            title: title,
            price: priceText,
            location: locationLine,
            imageUrl: imageUrl,
            layout: PropertyCardLayout.horizontal,
            featuredLabel: l10n.listingFormPreviewFeaturedLabel,
          )
        else
          PropertyCard(
            title: title,
            price: priceText,
            currency: currency,
            location: locationLine,
            imageUrl: imageUrl,
            layout: PropertyCardLayout.horizontal,
            featuredLabel: l10n.listingFormPreviewFeaturedLabel,
          ),
      ],
    );
  }

  ListingMedia? _resolveMainImage(List<ListingMedia> media) {
    final images = media
        .where((m) => m.kind == ListingMediaKind.image && m.storagePath != null)
        .toList();
    if (images.isEmpty) return null;
    final main = images.where((m) => m.isMain);
    if (main.isNotEmpty) return main.first;
    images.sort((a, b) => a.ordering.compareTo(b.ordering));
    return images.first;
  }
}

/// Phase 029 (F3) — required-field checklist mirroring [ValidateSubmitPayload].
/// Shows each missing required field; tapping a row jumps to its step.
class _ValidationChecklist extends StatelessWidget {
  const _ValidationChecklist({required this.state});

  final ListingFormState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final result = getIt<ValidateSubmitPayload>().call(state);

    if (result.ok) {
      return StepSection(
        icon: Icons.task_alt,
        title: l10n.listingFormChecklistTitle,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.circle_check,
                size: AppSpacing.xl,
                color: colors.success,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.listingFormChecklistAllComplete,
                  style: styles.bodyLarge.copyWith(color: colors.onSurface),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return StepSection(
      icon: Icons.checklist,
      title: l10n.listingFormChecklistTitle,
      subtitle: l10n.listingFormChecklistMissingSubtitle(
        result.missingFields.length,
      ),
      children: [
        for (final field in result.missingFields)
          _ChecklistRow(
            label: _missingFieldLabel(field, l10n),
            onTap: () => context.read<ListingFormBloc>().add(
              JumpToStep(_stepForMissingField(field)),
            ),
          ),
      ],
    );
  }

  /// Maps a ValidateSubmitPayload missing-field token to a localized label.
  String _missingFieldLabel(String token, AppLocalizations l10n) {
    switch (token) {
      case 'listings.title':
        return l10n.fieldLabelTitle;
      case 'listings.governorate_id':
        return l10n.fieldLabelGovernorate;
      case 'listings.city_id':
        return l10n.fieldLabelCity;
      case 'listings.area_id':
        return l10n.fieldLabelArea;
      case 'listings.address_text':
        return l10n.fieldLabelAddressText;
      case 'listings.area_size':
        return l10n.fieldLabelAreaSize;
      case 'listings.rooms':
        return l10n.fieldLabelRooms;
      case 'listings.bathrooms':
        return l10n.fieldLabelBathrooms;
      case 'listings.phone_or_whatsapp':
        return l10n.listingFormChecklistPhoneOrWhatsapp;
      case 'listing_prices.primary':
        return l10n.fieldLabelPrice;
      default:
        return l10n.listingFormChecklistGenericMissing;
    }
  }

  /// Maps a missing-field token to the step the publisher should jump to.
  ListingFormStep _stepForMissingField(String token) {
    switch (token) {
      case 'listings.title':
        return ListingFormStep.basics;
      case 'listings.governorate_id':
      case 'listings.city_id':
      case 'listings.area_id':
      case 'listings.address_text':
        return ListingFormStep.location;
      case 'listings.area_size':
      case 'listings.rooms':
      case 'listings.bathrooms':
        return ListingFormStep.details;
      case 'listing_prices.primary':
        return ListingFormStep.prices;
      case 'listings.phone_or_whatsapp':
        return ListingFormStep.visibility;
      default:
        return ListingFormStep.basics;
    }
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: appRadius(AppRadii.sm),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.circle_alert,
              size: AppSpacing.xl,
              color: colors.warning,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: styles.bodyLarge.copyWith(color: colors.onSurface),
              ),
            ),
            Text(
              l10n.listingFormChecklistFix,
              style: styles.labelMedium.copyWith(color: colors.primary),
            ),
            const SizedBox(width: AppSpacing.xxs),
            Icon(
              Icons.chevron_right,
              size: AppSpacing.lg,
              color: colors.primary,
            ),
          ],
        ),
      ),
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
