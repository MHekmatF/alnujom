// lib/features/inquiries/presentation/widgets/inbox_status_badge.dart
//
// Phase 16 Sub-Phase F (T065) — Colored Chip keyed by InquiryStatus.
// Color scheme tokens only — never hex literals (Constitution VI).
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/inquiry_status.dart';

class InboxStatusBadge extends StatelessWidget {
  const InboxStatusBadge({required this.status, super.key});

  final InquiryStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final (label, bgColor, fgColor) = switch (status) {
      InquiryStatus.new_ => (
        l10n.inquiry_status_new,
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
      ),
      InquiryStatus.seen => (
        l10n.inquiry_status_seen,
        colorScheme.secondaryContainer,
        colorScheme.onSecondaryContainer,
      ),
      InquiryStatus.responded => (
        l10n.inquiry_status_responded,
        colorScheme.tertiaryContainer,
        colorScheme.onTertiaryContainer,
      ),
      InquiryStatus.closed => (
        l10n.inquiry_status_closed,
        colorScheme.surfaceContainerHighest,
        colorScheme.onSurface,
      ),
      InquiryStatus.spam => (
        l10n.inquiry_status_spam,
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
      ),
    };

    return Chip(
      label: Text(label),
      backgroundColor: bgColor,
      labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: fgColor,
      ),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
