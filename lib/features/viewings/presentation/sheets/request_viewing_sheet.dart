// lib/features/viewings/presentation/sheets/request_viewing_sheet.dart
//
// Viewing scheduler — modal bottom sheet to request a property viewing.
//
// Flow: pick a date (showDatePicker) + a time (showTimePicker), add an optional
// note, then submit. The chosen LOCAL DateTime is converted to UTC before the
// RPC call. On success the sheet pops with `true` so the caller shows the
// standard confirmation snackbar.
//
// Token-only styling + RTL-correct (EdgeInsetsDirectional). The sheet owns its
// own ViewingsCubit (via getIt) since it can be opened from the listing detail
// where no list cubit is in scope.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
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

/// Caller launches via:
/// ```dart
/// final ok = await showModalBottomSheet<bool>(
///   context: context,
///   isScrollControlled: true,
///   builder: (_) => RequestViewingSheet(listingId: listing.id),
/// );
/// if (ok == true) { /* confirmation snackbar */ }
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

  DateTime? _date;
  TimeOfDay? _time;
  bool _submitting = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  /// The composed local DateTime, or null until both date + time are chosen.
  DateTime? get _localDateTime {
    final d = _date;
    final t = _time;
    if (d == null || t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  bool get _isInPast {
    final dt = _localDateTime;
    return dt != null && dt.isBefore(DateTime.now());
  }

  bool get _canSubmit => !_submitting && _localDateTime != null && !_isInPast;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _date ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (picked != null && mounted) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    final local = _localDateTime;
    if (local == null || _isInPast) return;

    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final cubit = context.read<ViewingsCubit>();

    setState(() => _submitting = true);

    final note = _noteCtrl.text.trim();
    final ok = await cubit.request(
      listingId: widget.listingId,
      scheduledAtUtc: local.toUtc(),
      note: note.isEmpty ? null : note,
    );

    if (!mounted) return;
    if (ok) {
      navigator.pop(true);
    } else {
      setState(() => _submitting = false);
      AppToast.error(context, l10n.viewingRequestError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final locale = Localizations.localeOf(context).toString();

    final dateLabel = _date == null
        ? l10n.viewingPickDate
        : DateFormat.yMMMMd(locale).format(_date!);
    final timeLabel = _time == null
        ? l10n.viewingPickTime
        : _time!.format(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle.
              Center(
                child: Container(
                  width: AppSpacing.xxl,
                  height: AppSpacing.xs,
                  margin: const EdgeInsetsDirectional.only(
                    bottom: AppSpacing.lg,
                  ),
                  decoration: BoxDecoration(
                    color: colors.outline,
                    borderRadius: appRadius(AppRadii.pill),
                  ),
                ),
              ),
              Text(l10n.viewingRequestTitle, style: styles.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              // Date picker field.
              _PickerField(
                icon: LucideIcons.calendar,
                label: dateLabel,
                placeholder: _date == null,
                onTap: _submitting ? null : _pickDate,
              ),
              const SizedBox(height: AppSpacing.md),
              // Time picker field.
              _PickerField(
                icon: LucideIcons.clock,
                label: timeLabel,
                placeholder: _time == null,
                onTap: _submitting ? null : _pickTime,
              ),
              if (_isInPast) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.viewingPastError,
                  style: styles.bodyMedium.copyWith(color: colors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              // Optional note.
              AppTextField(
                controller: _noteCtrl,
                enabled: !_submitting,
                maxLines: 3,
                label: l10n.viewingNoteLabel,
                helperText: l10n.viewingNotePlaceholder,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: l10n.viewingSubmitButton,
                variant: AppButtonVariant.filledPrimary,
                icon: LucideIcons.calendar_check,
                expanded: true,
                loading: _submitting,
                onPressed: _canSubmit ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tappable, read-only field that opens a native picker. Mirrors the
/// outlined-input look via [AppSurface] so the sheet stays token-clean.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.icon,
    required this.label,
    required this.placeholder,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool placeholder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return AppSurface(
      onTap: onTap,
      padding: appPadding(),
      child: Row(
        children: [
          Icon(icon, color: colors.primary, size: AppSpacing.xl),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: styles.bodyLarge.copyWith(
                color: placeholder ? colors.textMuted : colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
