import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
// hide intl's TextDirection so it doesn't shadow dart:ui's.
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/di/injection.dart';
import '../../../../core/settings/lite_mode.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/util/arabic_digits.dart';
import '../../domain/entities/nearby_amenity.dart';
import '../bloc/nearby_amenities_cubit.dart';

/// Spec 028 — the "Nearby" section on the listing details page: a section
/// header (tinted icon circle + title) over a [Wrap] of chips, one per nearby
/// point of interest (school / hospital / pharmacy / market / mosque) with its
/// distance, sourced from OpenStreetMap via the Overpass API.
///
/// Self-contained: hosts its own [NearbyAmenitiesCubit] and fires the fetch
/// once. Collapses to nothing when Data saver ([LiteMode]) is ON, when the
/// listing has no coordinates, or when the fetch fails / finds nothing — it
/// never blocks the page.
class NearbyAmenitiesSection extends StatelessWidget {
  const NearbyAmenitiesSection({
    super.key,
    required this.listingId,
    this.latitude,
    this.longitude,
  });

  /// The listing id — keys the datasource's session cache.
  final String listingId;

  /// The listing's coordinates (either null → section collapses).
  final double? latitude;
  final double? longitude;

  @override
  Widget build(BuildContext context) {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) return const SizedBox.shrink();

    // Data saver: skip the extra network round-trip entirely. Reactive — the
    // section appears/disappears live when the user flips the toggle.
    return ValueListenableBuilder<bool>(
      valueListenable: LiteMode.notifier,
      builder: (context, lite, _) {
        if (lite) return const SizedBox.shrink();
        return BlocProvider<NearbyAmenitiesCubit>(
          create: (_) =>
              getIt<NearbyAmenitiesCubit>()
                ..load(listingId: listingId, latitude: lat, longitude: lng),
          child: const _NearbyAmenitiesBody(),
        );
      },
    );
  }
}

class _NearbyAmenitiesBody extends StatelessWidget {
  const _NearbyAmenitiesBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NearbyAmenitiesCubit, NearbyAmenitiesState>(
      builder: (context, state) {
        // Initial / loading / error / empty all collapse silently — the
        // section appears only when there is something nearby to show.
        if (state.status != NearbyAmenitiesStatus.loaded ||
            state.amenities.isEmpty) {
          return const SizedBox.shrink();
        }

        final l10n = AppLocalizations.of(context)!;
        final colors = AppColors.of(context);
        final styles = AppTextStyles.of(context);
        final locale = Localizations.localeOf(context);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header — tinted icon circle + title.
            Row(
              children: [
                Container(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    LucideIcons.map_pin,
                    size: AppSpacing.lg,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.nearbyAmenitiesTitle,
                    style: styles.titleMedium.copyWith(color: colors.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final amenity in state.amenities)
                  _AmenityChip(amenity: amenity, locale: locale),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        );
      },
    );
  }
}

/// One amenity chip: a kind glyph + localized kind label + distance pill text.
class _AmenityChip extends StatelessWidget {
  const _AmenityChip({required this.amenity, required this.locale});

  final NearbyAmenity amenity;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: appRadius(AppRadii.pill),
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _kindIcon(amenity.kind),
            size: AppSpacing.lg,
            color: colors.primary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            _kindLabel(l10n, amenity.kind),
            style: styles.labelMedium.copyWith(color: colors.onSurface),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            _distanceLabel(l10n, amenity.distanceMeters),
            style: styles.labelMedium.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }

  IconData _kindIcon(NearbyAmenityKind kind) {
    switch (kind) {
      case NearbyAmenityKind.school:
        return LucideIcons.school;
      case NearbyAmenityKind.hospital:
        return LucideIcons.hospital;
      case NearbyAmenityKind.pharmacy:
        return LucideIcons.pill;
      case NearbyAmenityKind.market:
        return LucideIcons.store;
      case NearbyAmenityKind.mosque:
        return LucideIcons.moon_star;
    }
  }

  String _kindLabel(AppLocalizations l10n, NearbyAmenityKind kind) {
    switch (kind) {
      case NearbyAmenityKind.school:
        return l10n.amenitySchool;
      case NearbyAmenityKind.hospital:
        return l10n.amenityHospital;
      case NearbyAmenityKind.pharmacy:
        return l10n.amenityPharmacy;
      case NearbyAmenityKind.market:
        return l10n.amenityMarket;
      case NearbyAmenityKind.mosque:
        return l10n.amenityMosque;
    }
  }

  /// "350 m" under a kilometer, "1.2 km" above — locale-aware intl formatting,
  /// post-processed to Arabic-Indic digits under `ar` (intl's bundled `ar`
  /// data keeps Western digits).
  String _distanceLabel(AppLocalizations l10n, double meters) {
    final isArabic = locale.languageCode == 'ar';
    if (meters < 1000) {
      final label = l10n.amenityDistanceM(meters.round());
      return isArabic ? toArabicIndicNumerals(label) : label;
    }
    final kmFmt = NumberFormat.decimalPattern(locale.toLanguageTag())
      ..minimumFractionDigits = 1
      ..maximumFractionDigits = 1;
    final km = kmFmt.format(meters / 1000);
    return l10n.amenityDistanceKm(isArabic ? toArabicIndicNumerals(km) : km);
  }
}
