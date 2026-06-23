// lib/features/inquiries/presentation/widgets/inbox_status_badge.dart
//
// Phase 16 Sub-Phase F (T065) — Colored pill keyed by InquiryStatus.
// Restyled to the royal-blue DS: a soft tinted pill (token color at low alpha
// with a matching outline + ink), matching the AppBadge idiom. Color scheme
// tokens only — never hex literals (Constitution VI).
import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/inquiry_status.dart';

class InboxStatusBadge extends StatelessWidget {
  const InboxStatusBadge({required this.status, super.key});

  final InquiryStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    // Each status maps to a single token color; the pill renders it as a soft
    // tint (fill) + a matching outline + ink so it reads as a status chip.
    final (label, color) = switch (status) {
      InquiryStatus.new_ => (l10n.inquiry_status_new, colors.primary),
      InquiryStatus.seen => (l10n.inquiry_status_seen, colors.accent),
      InquiryStatus.responded => (l10n.inquiry_status_responded, colors.success),
      InquiryStatus.closed => (l10n.inquiry_status_closed, colors.textMuted),
      InquiryStatus.spam => (l10n.inquiry_status_spam, colors.error),
    };

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(0x24),
        borderRadius: appRadius(AppRadii.pill),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: styles.labelMedium.copyWith(color: color),
      ),
    );
  }
}
