import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../agency/presentation/widgets/publish_under_agency_field.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_form_state.dart';
import '../bloc/listing_form_bloc.dart';
import '../bloc/listing_form_event.dart';
import '../util/listing_enum_labels.dart';
import 'express_form_fields.dart' show expressDecoration;
import 'revision_banner.dart';
import 'step_section.dart';

class StepBasics extends StatefulWidget {
  const StepBasics({super.key});

  @override
  State<StepBasics> createState() => _StepBasicsState();
}

class _StepBasicsState extends State<StepBasics> {
  final TextEditingController _titleController = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<ListingFormBloc, ListingFormState>(
      builder: (context, state) {
        final listing = state.draftListing;
        if (listing == null) return const SizedBox.shrink();
        if (!_seeded) {
          _titleController.text = listing.title;
          _seeded = true;
        }
        return StepSection(
          icon: Icons.home_work_outlined,
          title: l10n.listingFormStepBasicsTitle,
          subtitle: l10n.listingFormStepBasicsSubtitle,
          children: [
            // Phase 031 (WS-B) — stay-live edit notice (revision mode only).
            if (state.isRevision) const RevisionBanner(),
            FieldLabel(label: l10n.fieldLabelTitle, required: true),
            TextField(
              controller: _titleController,
              // Phase 029 (F3 #5) — keyboard polish: keep the focused field
              // visible above the keyboard and advance focus on submit.
              scrollPadding: const EdgeInsets.all(AppSpacing.xxxl),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              onChanged: (v) =>
                  context.read<ListingFormBloc>().add(FieldChanged.title(v)),
              decoration: expressDecoration(context, hint: l10n.fieldLabelTitle),
            ),
            const FieldGap(),
            FieldLabel(label: l10n.fieldLabelPurpose, required: true),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final p in ListingPurpose.values)
                  _ChoiceChipTile(
                    label: listingPurposeLabel(p, l10n),
                    selected: listing.purpose == p,
                    onTap: () => context.read<ListingFormBloc>().add(
                      FieldChanged.purpose(p),
                    ),
                  ),
              ],
            ),
            const FieldGap(),
            FieldLabel(label: l10n.fieldLabelPropertyType, required: true),
            const SizedBox(height: AppSpacing.sm),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.05,
              children: [
                for (final p in PropertyType.values)
                  _TypeTile(
                    icon: _propertyTypeIcon(p),
                    label: propertyTypeLabel(p, l10n),
                    selected: listing.propertyType == p,
                    onTap: () => context.read<ListingFormBloc>().add(
                      FieldChanged.propertyType(p),
                    ),
                  ),
              ],
            ),
            // Phase 19 (T062) — publish-under-agency selector. Renders nothing
            // when the user has no eligible agency (no reflow for personal).
            PublishUnderAgencyField(
              agencies: state.availableAgencies,
              selectedAgencyId: listing.agencyId,
              onChanged: (agencyId) => context
                  .read<ListingFormBloc>()
                  .add(FieldChanged.agencyId(agencyId)),
            ),
          ],
        );
      },
    );
  }
}

/// A purpose chip (for-sale / for-rent / …): a pill that fills with the tonal
/// container + a leading check when selected. Same value the dropdown set — just
/// a friendlier picker (DC FLOW A · Wizard).
class _ChoiceChipTile extends StatelessWidget {
  const _ChoiceChipTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Material(
      color: selected ? colors.primaryContainer : colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: appRadius(AppRadii.pill),
        side: BorderSide(
          color: selected ? colors.primaryContainer : colors.outline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(
                  Icons.check,
                  size: 16,
                  color: colors.onPrimaryContainer,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label,
                style: styles.labelLarge.copyWith(
                  color: selected ? colors.onPrimaryContainer : colors.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A property-type tile: an icon + label cell that lifts onto the tonal
/// container with a primary border when selected (DC FLOW A · Wizard grid).
class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Material(
      color: selected ? colors.primaryContainer : colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: appRadius(AppRadii.md),
        side: BorderSide(
          color: selected ? colors.primary : colors.outline,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 26,
                color: selected ? colors.onPrimaryContainer : colors.textMuted,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: styles.labelMedium.copyWith(
                  color: selected ? colors.onPrimaryContainer : colors.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _propertyTypeIcon(PropertyType t) {
  switch (t) {
    case PropertyType.apartment:
      return Icons.apartment;
    case PropertyType.villa:
      return Icons.villa_outlined;
    case PropertyType.land:
      return Icons.terrain_outlined;
    case PropertyType.shop:
      return Icons.storefront_outlined;
    case PropertyType.office:
      return Icons.business_center_outlined;
    case PropertyType.farm:
      return Icons.agriculture_outlined;
    case PropertyType.warehouse:
      return Icons.warehouse_outlined;
    case PropertyType.other:
      return Icons.home_work_outlined;
  }
}
