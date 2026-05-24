import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (widget.description.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: AlignmentDirectional.topStart,
          child: Text(
            widget.description,
            style: theme.textTheme.bodyLarge,
            maxLines: _expanded ? null : widget.collapsedMaxLines,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
        ),
        if (!_expanded) ...[
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: () => setState(() => _expanded = true),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(l10n.descriptionReadMore),
          ),
        ],
      ],
    );
  }
}
