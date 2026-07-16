import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../_widget_support.dart';
import 'dc_status_chip.dart';

/// No trailing gap under the last timeline node (token-lint-safe zero).
const double _noGap = 0;

/// A single node in a [DcModerationTimeline]: an icon in a toned circle, a title,
/// a timestamp, and an optional body box.
class DcTimelineNode {
  const DcTimelineNode({
    required this.icon,
    required this.tone,
    required this.title,
    required this.time,
    this.body,
  });

  final IconData icon;
  final DcStatusTone tone;
  final String title;
  final String time;

  /// Optional detail (e.g. a rejection reason) shown in a surface2 box.
  final String? body;
}

/// DC "Blue Crown" vertical moderation timeline (`AlNujom - Publisher.dc.html`
/// «سجل المراجعة»): connected 32px toned nodes down the start edge with a title/
/// time/optional-body on the end. All strings are pre-localized by the caller.
class DcModerationTimeline extends StatelessWidget {
  const DcModerationTimeline({required this.nodes, super.key});

  final List<DcTimelineNode> nodes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < nodes.length; i++)
          _Node(node: nodes[i], isLast: i == nodes.length - 1),
      ],
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.node, required this.isLast});

  final DcTimelineNode node;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    final (bg, fg, border) = switch (node.tone) {
      DcStatusTone.green => (colors.verifiedContainer, colors.onSuccess, null),
      DcStatusTone.red => (colors.errorContainer, colors.onErrorContainer, null),
      DcStatusTone.neutral || DcStatusTone.outline => (
        colors.surfaceVariant,
        colors.textMuted,
        colors.outline,
      ),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: bg,
                    shape: BoxShape.circle,
                    border: border == null ? null : Border.all(color: border),
                  ),
                  child: Icon(node.icon, size: 18, color: fg),
                ),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(width: 2, color: colors.divider),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                bottom: isLast ? _noGap : AppSpacing.lg,
                top: AppSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    node.title,
                    style: styles.labelLarge.copyWith(color: colors.onSurface),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    node.time,
                    style: styles.labelSmall.copyWith(color: colors.textMuted),
                  ),
                  if (node.body != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant,
                        borderRadius: appRadius(AppRadii.md),
                      ),
                      child: Text(
                        node.body!,
                        style: styles.bodyMedium.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
