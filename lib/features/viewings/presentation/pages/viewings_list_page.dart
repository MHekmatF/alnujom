// lib/features/viewings/presentation/pages/viewings_list_page.dart
//
// Viewing scheduler — the caller's viewings, as token-styled cards. Each card
// shows the listing title, the formatted scheduled date/time, an optional note,
// and a status pill coloured by status. Member actions:
//   - publisher + requested        → Confirm / Decline
//   - requester + requested|confirmed → Cancel
// Empty/loading/error use the shared state widgets. Token-only + RTL-correct.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../crm/presentation/widgets/add_to_crm_action.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/viewing.dart';
import '../cubit/viewings_cubit.dart';

class ViewingsListPage extends StatefulWidget {
  const ViewingsListPage({super.key});

  @override
  State<ViewingsListPage> createState() => _ViewingsListPageState();
}

class _ViewingsListPageState extends State<ViewingsListPage> {
  @override
  void initState() {
    super.initState();
    context.read<ViewingsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.viewingsListTitle)),
      body: BlocBuilder<ViewingsCubit, ViewingsState>(
        builder: (context, state) {
          switch (state.status) {
            case ViewingsStatus.initial:
            case ViewingsStatus.loading:
              return const AppSpinner.page();
            case ViewingsStatus.error:
              return ErrorState(
                title: l10n.viewingsListErrorTitle,
                onRetry: () => context.read<ViewingsCubit>().load(),
              );
            case ViewingsStatus.list:
              if (state.viewings.isEmpty) {
                return EmptyState(
                  icon: LucideIcons.calendar,
                  headline: l10n.viewingsListEmptyTitle,
                  body: l10n.viewingsListEmptyBody,
                );
              }
              return ListView.separated(
                padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                itemCount: state.viewings.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) =>
                    _ViewingCard(viewing: state.viewings[i]),
              );
          }
        },
      ),
    );
  }
}

class _ViewingCard extends StatelessWidget {
  const _ViewingCard({required this.viewing});

  final Viewing viewing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final locale = Localizations.localeOf(context).toString();

    final title = viewing.listingTitle ?? l10n.viewingListingUnavailable;
    final when = DateFormat.yMMMMEEEEd(
      locale,
    ).add_jm().format(viewing.scheduledAt.toLocal());

    final pill = _statusPill(context, l10n, colors, viewing.status);
    final actions = _actionsFor(context, l10n);

    return AppSurface(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: styles.titleMedium,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              pill,
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                LucideIcons.clock,
                size: AppSpacing.lg,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  when,
                  style: styles.bodyMedium.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (viewing.note != null && viewing.note!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              viewing.note!.trim(),
              style: styles.bodyMedium.copyWith(color: colors.textMuted),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Row(children: _interspersed(actions)),
          ],
          // Phase 29 (F1) — publisher-only "Add to CRM": attach this viewing's
          // requester as a lead (resolved + ownership-checked server-side).
          if (viewing.amIPublisher) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppButton(
                label: l10n.crmAddToCrmAction,
                variant: AppButtonVariant.text,
                size: AppButtonSize.dense,
                icon: LucideIcons.handshake,
                onPressed: () => addToCrm(
                  context,
                  source: CrmLeadSource.viewing,
                  sourceId: viewing.id,
                  displayName: viewing.listingTitle,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The member actions available on this row. Empty for terminal rows.
  List<Widget> _actionsFor(BuildContext context, AppLocalizations l10n) {
    // Publisher reviewing a pending request → Confirm / Decline.
    if (viewing.amIPublisher && viewing.status == ViewingStatus.requested) {
      return [
        Expanded(
          child: AppButton(
            label: l10n.viewingConfirmAction,
            variant: AppButtonVariant.filledSuccess,
            onPressed: () => _transition(context, ViewingStatus.confirmed),
          ),
        ),
        Expanded(
          child: AppButton(
            label: l10n.viewingDeclineAction,
            variant: AppButtonVariant.outlined,
            onPressed: () => _transition(context, ViewingStatus.declined),
          ),
        ),
      ];
    }
    // Requester may cancel while the request is still live.
    if (!viewing.amIPublisher &&
        (viewing.status == ViewingStatus.requested ||
            viewing.status == ViewingStatus.confirmed)) {
      return [
        Expanded(
          child: AppButton(
            label: l10n.viewingCancelAction,
            variant: AppButtonVariant.outlined,
            onPressed: () => _transition(context, ViewingStatus.cancelled),
          ),
        ),
      ];
    }
    return const [];
  }

  Future<void> _transition(BuildContext context, ViewingStatus status) async {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<ViewingsCubit>();

    final ok = await cubit.updateStatus(viewingId: viewing.id, status: status);
    if (!context.mounted) return;

    final message = ok
        ? switch (status) {
            ViewingStatus.confirmed => l10n.viewingConfirmedSuccess,
            ViewingStatus.declined => l10n.viewingDeclinedSuccess,
            ViewingStatus.cancelled => l10n.viewingCancelledSuccess,
            ViewingStatus.requested => l10n.viewingsListTitle,
          }
        : l10n.viewingUpdateError;
    AppToast.show(
      context,
      message,
      variant: ok ? AppToastVariant.success : AppToastVariant.error,
    );
  }

  _SoftStatusPill _statusPill(
    BuildContext context,
    AppLocalizations l10n,
    AppColors colors,
    ViewingStatus status,
  ) {
    final (label, color) = switch (status) {
      ViewingStatus.requested => (l10n.viewingStatusRequested, colors.warning),
      ViewingStatus.confirmed => (l10n.viewingStatusConfirmed, colors.success),
      ViewingStatus.declined => (l10n.viewingStatusDeclined, colors.error),
      ViewingStatus.cancelled => (
        l10n.viewingStatusCancelled,
        colors.textMuted,
      ),
    };
    return _SoftStatusPill(label: label, color: color);
  }

  static List<Widget> _interspersed(List<Widget> actions) {
    final out = <Widget>[];
    for (var i = 0; i < actions.length; i++) {
      if (i > 0) out.add(const SizedBox(width: AppSpacing.sm));
      out.add(actions[i]);
    }
    return out;
  }
}

/// Phase-33 DS soft-tinted status pill for the viewing rows: a low-alpha tint
/// of the status [color] as the fill, the same colour (at full strength) for
/// the label, and a faint outline of it — a quieter, more "airy" read than the
/// shared solid [StatusPill], matching the new design system's status chips.
class _SoftStatusPill extends StatelessWidget {
  const _SoftStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyles.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: appRadius(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: Text(label, style: styles.labelMedium.copyWith(color: color)),
      ),
    );
  }
}
