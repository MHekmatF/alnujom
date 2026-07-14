// lib/features/viewings/presentation/pages/viewings_list_page.dart
//
// Viewing scheduler — the caller's viewings, restyled to the DC "Blue Crown"
// system (`AlNujom - Publisher.dc.html` «طلبات المعاينة»): a crown-headered list
// of flat cards, each showing the listing, a DcStatusChip, the scheduled
// date/time on a surface2 strip, an optional note, and the member actions:
//   - publisher + requested          → Confirm / Decline
//   - requester + requested|confirmed → Cancel
// Behaviour-preserving. Token-only + RTL-correct.

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
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/ds/dc_status_chip.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/staggered_list_item.dart';
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

    return DcCrownScaffold(
      title: l10n.viewingsListTitle,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () => Navigator.of(context).maybePop(),
      ),
      body: BlocBuilder<ViewingsCubit, ViewingsState>(
        builder: (context, state) {
          switch (state.status) {
            case ViewingsStatus.initial:
            case ViewingsStatus.loading:
              return ListView.separated(
                padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                itemCount: 5,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (_, __) => const LoadingState.card(),
              );
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
              final colors = AppColors.of(context);
              return RefreshIndicator(
                color: colors.primary,
                onRefresh: () => context.read<ViewingsCubit>().load(),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                  itemCount: state.viewings.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) => StaggeredListItem(
                    index: i,
                    child: _ViewingCard(viewing: state.viewings[i]),
                  ),
                ),
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

    final actions = _actionsFor(context, l10n);

    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: appRadius(AppRadii.lg),
        border: Border.all(color: colors.outline),
      ),
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
                  style: styles.titleMedium.copyWith(color: colors.onSurface),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _statusChip(l10n, viewing.status),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: appRadius(AppRadii.md),
            ),
            child: Row(
              children: [
                Icon(Icons.event, size: 20, color: colors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    when,
                    style: styles.bodyMedium.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
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

  DcStatusChip _statusChip(AppLocalizations l10n, ViewingStatus status) {
    final (label, tone, icon) = switch (status) {
      ViewingStatus.requested => (
        l10n.viewingStatusRequested,
        DcStatusTone.neutral,
        Icons.hourglass_empty,
      ),
      ViewingStatus.confirmed => (
        l10n.viewingStatusConfirmed,
        DcStatusTone.green,
        Icons.event_available,
      ),
      ViewingStatus.declined => (
        l10n.viewingStatusDeclined,
        DcStatusTone.red,
        Icons.event_busy,
      ),
      ViewingStatus.cancelled => (
        l10n.viewingStatusCancelled,
        DcStatusTone.neutral,
        Icons.history,
      ),
    };
    return DcStatusChip(label: label, tone: tone, icon: icon);
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
