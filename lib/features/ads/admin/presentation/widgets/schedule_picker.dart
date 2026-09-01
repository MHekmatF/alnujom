// Phase 21 (spec/021-ads-banners) — T024
// SchedulePicker: optional start/end date-time pickers.
// Enforces start < end before letting the caller proceed.
// Phase 2 tokens only; RTL-safe.
// Constitution IX: zero supabase_flutter imports.
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/radii.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../core/widgets/_widget_support.dart';
import '../../../../../l10n/app_localizations.dart';

/// Optional schedule window (start/end) picker.
///
/// Both fields are optional; when set, enforces [start] < [end].
/// [onChanged] is called whenever either date-time changes.
class SchedulePicker extends StatelessWidget {
  const SchedulePicker({
    super.key,
    this.startAt,
    this.endAt,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  final DateTime? startAt;
  final DateTime? endAt;
  final ValueChanged<DateTime?> onStartChanged;
  final ValueChanged<DateTime?> onEndChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    // Validate: start must be before end.
    final hasError =
        startAt != null && endAt != null && !startAt!.isBefore(endAt!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.adsAdminScheduleLabel, style: styles.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _DateTimeField(
                label: l10n.scheduleStartLabel,
                value: startAt,
                onChanged: onStartChanged,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _DateTimeField(
                label: l10n.scheduleEndLabel,
                value: endAt,
                onChanged: onEndChanged,
              ),
            ),
          ],
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.scheduleStartMustBeforeEnd,
            style: styles.labelMedium.copyWith(color: colors.error),
          ),
        ],
      ],
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (!context.mounted || pickedDate == null) return;

        final pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(value ?? now),
        );
        if (!context.mounted) return;

        if (pickedTime != null) {
          onChanged(
            DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              pickedTime.hour,
              pickedTime.minute,
            ),
          );
        }
      },
      borderRadius: appRadius(AppRadii.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: styles.labelMedium,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value == null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
                  child: Icon(
                    LucideIcons.calendar,
                    size: AppSpacing.lg,
                    color: colors.onSurfaceVariant,
                  ),
                )
              else
                // Batch-2 a11y: the 16px clear glyph sat in a sub-48dp slot and
                // the calendar icon crowded it; when a value is set the clear
                // action is the only affordance, at a full 48dp target.
                IconButton(
                  icon: const Icon(LucideIcons.x, size: AppSpacing.lg),
                  color: colors.onSurfaceVariant,
                  constraints: const BoxConstraints(
                    minWidth: kAppMinTouchTarget,
                    minHeight: kAppMinTouchTarget,
                  ),
                  tooltip: l10n.scheduleClearTooltip,
                  onPressed: () => onChanged(null),
                ),
            ],
          ),
        ),
        child: Text(
          value != null ? _formatDateTime(value!) : l10n.scheduleNotSet,
          style: value != null
              ? styles.bodyLarge
              : styles.bodyLarge.copyWith(color: colors.textMuted),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    // ISO-style display: YYYY-MM-DD HH:mm
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${pad(dt.month)}-${pad(dt.day)} '
        '${pad(dt.hour)}:${pad(dt.minute)}';
  }
}
