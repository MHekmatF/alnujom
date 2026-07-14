// lib/features/viewings/presentation/sheets/request_viewing_sheet.dart
//
// Viewing scheduler — modal bottom sheet to request a property viewing.
//
// DC "Blue Crown" (Listing & Viewing handoff): pick a DAY from a horizontal
// chip strip (next 14 days) + a time-slot (morning/midday/afternoon/evening),
// add an optional note, then confirm. On success the sheet swaps to an in-sheet
// "request sent" confirmation (edit / done) rather than popping immediately.
//
// The chosen slot maps to a representative local hour; that local DateTime is
// converted to UTC before the RPC call. Token-only styling + RTL-correct. The
// sheet owns its own ViewingsCubit (via getIt) since it can be opened from the
// listing detail where no list cubit is in scope.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/di/injection.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/viewings_cubit.dart';

/// A selectable viewing time-slot: a localized [label], the displayed [range],
/// and the representative local [hour] sent to the backend.
class _Slot {
  const _Slot({required this.label, required this.range, required this.hour});
  final String label;
  final String range;
  final int hour;
}

/// Caller launches via:
/// ```dart
/// await showModalBottomSheet<bool>(
///   context: context,
///   isScrollControlled: true,
///   builder: (_) => RequestViewingSheet(listingId: listing.id),
/// );
/// ```
class RequestViewingSheet extends StatelessWidget {
  const RequestViewingSheet({required this.listingId, super.key});

  final String listingId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ViewingsCubit>(
      create: (_) => getIt<ViewingsCubit>(),
      child: _RequestViewingBody(listingId: listingId),
    );
  }
}

class _RequestViewingBody extends StatefulWidget {
  const _RequestViewingBody({required this.listingId});

  final String listingId;

  @override
  State<_RequestViewingBody> createState() => _RequestViewingBodyState();
}

class _RequestViewingBodyState extends State<_RequestViewingBody> {
  final TextEditingController _noteCtrl = TextEditingController();

  DateTime? _day;
  int? _slotIndex;
  bool _submitting = false;
  bool _booked = false;
  String _bookSummary = '';

  /// The next 14 calendar days, starting today (date-only).
  late final List<DateTime> _days = () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List<DateTime>.generate(
      14,
      (i) => today.add(Duration(days: i)),
      growable: false,
    );
  }();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  List<_Slot> _slots(AppLocalizations l10n) => [
    _Slot(label: l10n.viewingSlotMorning, range: _range(9, 12), hour: 10),
    _Slot(label: l10n.viewingSlotNoon, range: _range(12, 15), hour: 13),
    _Slot(label: l10n.viewingSlotAfternoon, range: _range(15, 18), hour: 16),
    _Slot(label: l10n.viewingSlotEvening, range: _range(18, 21), hour: 19),
  ];

  // A plain "9:00 – 12:00" range string (computed, not a Text() literal).
  String _range(int startH, int endH) => '$startH:00 – $endH:00';

  bool get _canSubmit => !_submitting && _day != null && _slotIndex != null;

  Future<void> _submit(List<_Slot> slots) async {
    final day = _day;
    final slotIndex = _slotIndex;
    if (day == null || slotIndex == null) return;

    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final cubit = context.read<ViewingsCubit>();
    final slot = slots[slotIndex];
    final local = DateTime(day.year, day.month, day.day, slot.hour);

    setState(() => _submitting = true);

    final note = _noteCtrl.text.trim();
    final ok = await cubit.request(
      listingId: widget.listingId,
      scheduledAtUtc: local.toUtc(),
      note: note.isEmpty ? null : note,
    );

    if (!mounted) return;
    if (ok) {
      setState(() {
        _submitting = false;
        _booked = true;
        _bookSummary = '${DateFormat.MMMEd(locale).format(day)} · ${slot.label}';
      });
    } else {
      setState(() => _submitting = false);
      AppToast.error(context, l10n.viewingRequestError);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: _booked ? _bookedView(context) : _formView(context),
      ),
    );
  }

  // ─── Form ──────────────────────────────────────────────────────────────────

  Widget _formView(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final locale = Localizations.localeOf(context).toString();
    final slots = _slots(l10n);

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: tonal-ish icon tile + title.
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: appRadius(AppRadii.md),
                ),
                child: Icon(
                  Icons.calendar_month,
                  size: AppSpacing.xl,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  l10n.viewingRequestTitle,
                  style: styles.titleMedium.copyWith(color: colors.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Choose day.
          Text(
            l10n.viewingChooseDayLabel,
            style: styles.labelLarge.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 66,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _days.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) {
                final day = _days[i];
                return _DayChip(
                  dow: DateFormat.E(locale).format(day),
                  num: DateFormat.d(locale).format(day),
                  selected: _day == day,
                  onTap: () => setState(() => _day = day),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Choose slot.
          Text(
            l10n.viewingChoosePeriodLabel,
            style: styles.labelLarge.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: AppSpacing.sm),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 3.1,
            children: [
              for (var i = 0; i < slots.length; i++)
                _SlotChip(
                  label: slots[i].label,
                  range: slots[i].range,
                  selected: _slotIndex == i,
                  onTap: () => setState(() => _slotIndex = i),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _noteCtrl,
            enabled: !_submitting,
            maxLines: 2,
            label: l10n.viewingNoteLabel,
            helperText: l10n.viewingNotePlaceholder,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: l10n.viewingConfirmRequestButton,
            variant: AppButtonVariant.filledPrimary,
            expanded: true,
            loading: _submitting,
            onPressed: _canSubmit ? () => _submit(slots) : null,
          ),
        ],
      ),
    );
  }

  // ─── Booked confirmation ─────────────────────────────────────────────────────

  Widget _bookedView(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 80,
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.verifiedContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_available,
                size: 44,
                color: colors.onSuccess,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.viewingBookedTitle,
            textAlign: TextAlign.center,
            style: styles.titleLarge.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.viewingBookedBody,
            textAlign: TextAlign.center,
            style: styles.bodyMedium.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          // Summary pill.
          Align(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: appRadius(AppRadii.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event, size: AppSpacing.lg, color: colors.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _bookSummary,
                    style: styles.labelLarge.copyWith(color: colors.onSurface),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: l10n.viewingEditRequestAction,
                  variant: AppButtonVariant.outlined,
                  onPressed: () => setState(() => _booked = false),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: l10n.viewingDoneAction,
                  variant: AppButtonVariant.filledPrimary,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}

/// A single day chip in the horizontal strip: weekday abbreviation over the
/// day-of-month number. Selected = solid primary.
class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.dow,
    required this.num,
    required this.selected,
    required this.onTap,
  });

  final String dow;
  final String num;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.card,
          borderRadius: appRadius(AppRadii.md),
          border: selected ? null : Border.all(color: colors.outline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dow,
              style: styles.labelSmall.copyWith(
                color: selected ? colors.onPrimary : colors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              num,
              style: styles.titleMedium.copyWith(
                color: selected ? colors.onPrimary : colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A time-slot chip: label over a small time range. Selected = tonal fill with
/// a primary outline.
class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.label,
    required this.range,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String range;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        alignment: AlignmentDirectional.centerStart,
        decoration: BoxDecoration(
          color: selected ? colors.primaryContainer : colors.card,
          borderRadius: appRadius(AppRadii.md),
          border: Border.all(
            color: selected ? colors.primary : colors.outline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: styles.labelLarge.copyWith(
                color: selected ? colors.onPrimaryContainer : colors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              range,
              textDirection: TextDirection.ltr,
              style: styles.labelSmall.copyWith(
                color: selected ? colors.onPrimaryContainer : colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
