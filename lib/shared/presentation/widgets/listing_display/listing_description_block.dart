import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../l10n/app_localizations.dart';

/// Phase 12 Q8=A shared widget — multi-line description text with ~10-line
/// truncation + localized "Read more" affordance that expands inline.
///
/// Constitution IX-clean: no Supabase imports. Accepts plain String only.
class ListingDescriptionBlock extends StatefulWidget {
  const ListingDescriptionBlock({
    super.key,
    required this.description,
    this.collapsedMaxLines = 10,
  });

  final String description;
  final int collapsedMaxLines;

  @override
  State<ListingDescriptionBlock> createState() =>
      _ListingDescriptionBlockState();
}

class _ListingDescriptionBlockState extends State<ListingDescriptionBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (widget.description.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: AppMotion.fast,
          alignment: AlignmentDirectional.topStart,
          child: Text(
            widget.description,
            // DS: relaxed, airy body copy in the muted text colour with a
            // generous ~1.85 line-height so long Arabic descriptions breathe.
            style: styles.bodyMedium.copyWith(
              color: colors.textMuted,
              height: 1.85,
            ),
            maxLines: _expanded ? null : widget.collapsedMaxLines,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.sm,
              ),
              // A 48dp-tall hit slot: the label alone was ~32dp.
              minimumSize: const Size(0, AppSpacing.xxxl),
            ),
            child: Text(
              _expanded ? l10n.descriptionReadLess : l10n.descriptionReadMore,
            ),
          ),
        ),
      ],
    );
  }
}
