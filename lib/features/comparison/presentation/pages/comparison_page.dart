// lib/features/comparison/presentation/pages/comparison_page.dart
//
// Side-by-side property comparison. Renders the 2-3 selected listings as a
// horizontally-scrollable set of columns (image, title, price, then aligned
// fact rows: purpose, type, rooms, baths, area, location). A fixed leading
// label column keeps the rows readable as the property columns scroll.
//
// Token-only styling (no inline hex / TextStyle / numeric insets). RTL-safe;
// numbers render in the active locale's numerals via intl NumberFormat.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
// hide intl's TextDirection so it doesn't shadow dart:ui's.
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/elevation.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../../domain/entities/comparison_item.dart';
import '../cubit/comparison_cubit.dart';

/// Full-screen comparison of the listings selected on the FavoritesPage.
///
/// Consumes the shared [ComparisonCubit] from the widget tree (the caller wraps
/// the route in a `BlocProvider.value`). When the selection drops below two
/// (e.g. the user removes a column) the page shows an empty hint.
class ComparisonPage extends StatelessWidget {
  const ComparisonPage({super.key});

  /// Fixed width for each property column. Wide enough for a title + price but
  /// narrow enough that two-to-three columns invite a horizontal scroll.
  static const double _columnWidth = 168;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.comparisonPageTitle),
        actions: [
          BlocBuilder<ComparisonCubit, ComparisonState>(
            buildWhen: (a, b) => a.count != b.count,
            builder: (context, state) {
              if (state.count == 0) return const SizedBox.shrink();
              return IconButton(
                tooltip: l10n.comparisonClearAll,
                icon: const Icon(LucideIcons.trash_2),
                onPressed: () => context.read<ComparisonCubit>().clear(),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<ComparisonCubit, ComparisonState>(
        builder: (context, state) {
          final items = state.items;
          if (items.length < ComparisonCubit.minToCompare) {
            return _EmptyHint(l10n: l10n, colors: colors);
          }
          return _ComparisonBody(items: items, columnWidth: _columnWidth);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty hint (selection dropped below two)
// ---------------------------------------------------------------------------

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.l10n, required this.colors});

  final AppLocalizations l10n;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyles.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.scale,
              size: AppSpacing.xxxl,
              color: colors.textMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.comparisonEmptyHint,
              textAlign: TextAlign.center,
              style: styles.bodyMedium.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body — a leading label column + N scrollable property columns, kept in
// vertical lock-step so each fact row aligns across columns.
// ---------------------------------------------------------------------------

class _ComparisonBody extends StatelessWidget {
  const _ComparisonBody({required this.items, required this.columnWidth});

  final List<ComparisonItem> items;
  final double columnWidth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // The fact rows rendered for every column, in order.
    final rows = <_FactRow>[
      _FactRow(
        icon: LucideIcons.tag,
        label: l10n.comparisonRowPurpose,
        valueOf: (it) => _purposeLabel(l10n, it.purpose),
      ),
      _FactRow(
        icon: LucideIcons.house,
        label: l10n.comparisonRowType,
        valueOf: (it) => _propertyTypeLabel(l10n, it.propertyType),
      ),
      _FactRow(
        icon: LucideIcons.bed,
        label: l10n.comparisonRowRooms,
        valueOf: (it) => _intOrDash(context, it.rooms),
      ),
      _FactRow(
        icon: LucideIcons.bath,
        label: l10n.comparisonRowBathrooms,
        valueOf: (it) => _intOrDash(context, it.bathrooms),
      ),
      _FactRow(
        icon: LucideIcons.ruler,
        label: l10n.comparisonRowArea,
        valueOf: (it) => _areaOrDash(context, l10n, it.areaSize),
      ),
      _FactRow(
        icon: LucideIcons.map_pin,
        label: l10n.comparisonRowLocation,
        valueOf: (it) => _locationLabel(it),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabelColumn(rows: rows),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in items)
                    _PropertyColumn(
                      item: item,
                      rows: rows,
                      width: columnWidth,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Leading (sticky-feeling) label column — header spacer + one labelled row per
// fact, vertically aligned with the property columns.
// ---------------------------------------------------------------------------

class _LabelColumn extends StatelessWidget {
  const _LabelColumn({required this.rows});

  final List<_FactRow> rows;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Spacer matching the header (image + title + price) height region.
          const SizedBox(height: _kHeaderHeight),
          for (final row in rows)
            Container(
              height: _kRowHeight,
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(row.icon, size: AppSpacing.lg, color: colors.textMuted),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    row.label,
                    style: styles.labelMedium.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One property column: tappable header (image + title + price) that opens the
// listing details, a remove button, then the aligned fact values.
// ---------------------------------------------------------------------------

class _PropertyColumn extends StatelessWidget {
  const _PropertyColumn({
    required this.item,
    required this.rows,
    required this.width,
  });

  final ComparisonItem item;
  final List<_FactRow> rows;
  final double width;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);

    return Container(
      width: width,
      margin: const EdgeInsetsDirectional.only(start: AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: appRadius(AppRadii.lg),
        border: Border.all(color: colors.outline),
        boxShadow: elevation.level1,
      ),
      child: ClipRRect(
        borderRadius: appRadius(AppRadii.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Tappable header (opens the listing details) ---
            PressScale(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () =>
                      context.push(AppRoutes.listingDetailsFor(item.id)),
                  child: SizedBox(
                    height: _kHeaderHeight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ColumnHero(item: item, l10n: l10n),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.all(
                              AppSpacing.sm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title.isEmpty ? '—' : item.title,
                                  style: styles.titleMedium,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Spacer(),
                                if (item.primaryAmount != null &&
                                    item.primaryCurrency != null)
                                  Text(
                                    l10n.priceWithCurrency(
                                      _formatAmount(
                                        context,
                                        item.primaryAmount!,
                                      ),
                                      item.primaryCurrency!,
                                    ),
                                    textDirection: TextDirection.ltr,
                                    textAlign: TextAlign.start,
                                    style: styles.priceMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                else
                                  Text(
                                    l10n.comparisonValueNone,
                                    style: styles.priceMedium,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // --- Remove this column from the comparison ---
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: l10n.comparisonRemoveColumn,
                icon: Icon(
                  LucideIcons.circle_x,
                  size: AppSpacing.lg,
                  color: colors.textMuted,
                ),
                onPressed: () =>
                    context.read<ComparisonCubit>().removeById(item.id),
              ),
            ),
            Divider(height: AppSpacing.xxs, color: colors.divider),
            // --- Aligned fact values ---
            for (var i = 0; i < rows.length; i++)
              Container(
                height: _kRowHeight,
                alignment: AlignmentDirectional.centerStart,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: i.isEven ? colors.surfaceVariant : colors.card,
                ),
                child: Text(
                  rows[i].valueOf(item),
                  style: styles.bodyMedium.copyWith(color: colors.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(BuildContext context, num amount) {
    final fmt = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    )..maximumFractionDigits = 0;
    return fmt.format(amount);
  }
}

class _ColumnHero extends StatelessWidget {
  const _ColumnHero({required this.item, required this.l10n});

  final ComparisonItem item;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: AppNetworkImage(
            url: item.isAvailable ? item.mainImagePath : null,
            semanticLabel: l10n.image_unavailable,
          ),
        ),
        if (!item.isAvailable)
          Positioned.fill(child: ColoredBox(color: colors.scrim)),
        if (!item.isAvailable)
          PositionedDirectional(
            bottom: AppSpacing.xs,
            start: AppSpacing.xs,
            child: StatusPill(
              label: l10n.favorite_unavailable_indicator,
              color: colors.error,
              icon: LucideIcons.circle_slash,
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared layout constants + per-row descriptor
// ---------------------------------------------------------------------------

/// Header region height (image + title/price block) — matched by the label
/// column's leading spacer so the fact rows line up across columns.
const double _kHeaderHeight = 210;

/// Uniform height for each fact row in both the label and property columns.
const double _kRowHeight = AppSpacing.xxxl;

class _FactRow {
  const _FactRow({
    required this.icon,
    required this.label,
    required this.valueOf,
  });

  final IconData icon;
  final String label;
  final String Function(ComparisonItem item) valueOf;
}

// ---------------------------------------------------------------------------
// Value formatters / label maps (mirrors FavoriteCard's idiom).
// ---------------------------------------------------------------------------

String _intOrDash(BuildContext context, int? value) {
  if (value == null) return '—';
  final fmt = NumberFormat.decimalPattern(
    Localizations.localeOf(context).toLanguageTag(),
  );
  return fmt.format(value);
}

String _areaOrDash(
  BuildContext context,
  AppLocalizations l10n,
  double? value,
) {
  if (value == null) return '—';
  final fmt = NumberFormat.decimalPattern(
    Localizations.localeOf(context).toLanguageTag(),
  );
  final number = value == value.roundToDouble()
      ? fmt.format(value.round())
      : fmt.format(double.parse(value.toStringAsFixed(1)));
  return '$number ${l10n.spec_area_unit}';
}

String _locationLabel(ComparisonItem item) {
  final gov = item.governorateNameAr ?? item.governorateNameEn ?? '';
  final city = item.cityNameAr ?? item.cityNameEn ?? '';
  final parts = [if (gov.isNotEmpty) gov, if (city.isNotEmpty) city];
  return parts.isEmpty ? '—' : parts.join(' • ');
}

String _purposeLabel(AppLocalizations l10n, ListingPurpose purpose) {
  switch (purpose) {
    case ListingPurpose.sale:
      return l10n.listingPurposeSale;
    case ListingPurpose.rent:
      return l10n.listingPurposeRent;
    case ListingPurpose.dailyRent:
      return l10n.listingPurposeDailyRent;
    case ListingPurpose.investment:
      return l10n.listingPurposeInvestment;
  }
}

String _propertyTypeLabel(AppLocalizations l10n, PropertyType type) {
  switch (type) {
    case PropertyType.apartment:
      return l10n.propertyTypeApartment;
    case PropertyType.villa:
      return l10n.propertyTypeVilla;
    case PropertyType.land:
      return l10n.propertyTypeLand;
    case PropertyType.shop:
      return l10n.propertyTypeShop;
    case PropertyType.office:
      return l10n.propertyTypeOffice;
    case PropertyType.farm:
      return l10n.propertyTypeFarm;
    case PropertyType.warehouse:
      return l10n.propertyTypeWarehouse;
    case PropertyType.other:
      return l10n.propertyTypeOther;
  }
}
