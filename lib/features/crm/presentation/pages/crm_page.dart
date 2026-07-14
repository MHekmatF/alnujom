// lib/features/crm/presentation/pages/crm_page.dart
//
// Phase 029 (F1) — the CRM pipeline page, restyled to the DC "Blue Crown"
// system (`AlNujom - Publisher.dc.html` «العملاء المحتملون»): a crown header
// with the stage filters as scrollable underline tabs, a "due today" reminder
// banner, flat lead rows (avatar + name + last-activity + a DcStatusChip stage
// dot-pill), and a FAB to add a manual lead. Behaviour-preserving.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/crown_underline_tabs.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/ds/dc_status_chip.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/crm_lead.dart';
import '../../domain/entities/crm_reminder.dart';
import '../../domain/entities/crm_stage.dart';
import '../bloc/crm_leads_cubit.dart';
import '../bloc/lead_detail_cubit.dart';
import '../widgets/crm_stage_styles.dart';
import 'lead_detail_page.dart';

/// The stage-filter tabs (null = "الكل" first, then the 6 ordered stages).
final List<CrmStage?> _stageFilters = [null, ...CrmStage.ordered];

/// Maps a CRM stage to a DC status tone: won→green, lost→red, else neutral.
DcStatusTone crmStageTone(CrmStage stage) => switch (stage) {
  CrmStage.won => DcStatusTone.green,
  CrmStage.lost => DcStatusTone.red,
  CrmStage.newLead ||
  CrmStage.contacted ||
  CrmStage.viewing ||
  CrmStage.negotiation => DcStatusTone.neutral,
};

class CrmPage extends StatelessWidget {
  const CrmPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CrmLeadsCubit>(
      create: (_) => getIt<CrmLeadsCubit>()..load(),
      child: const _CrmView(),
    );
  }
}

class _CrmView extends StatelessWidget {
  const _CrmView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DcCrownScaffold(
      title: l10n.crmPageTitle,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () => Navigator.of(context).maybePop(),
      ),
      crownBottom: BlocBuilder<CrmLeadsCubit, CrmLeadsState>(
        buildWhen: (a, b) => a.stageFilter != b.stageFilter,
        builder: (context, state) => CrownUnderlineTabs(
          scrollable: true,
          fontSize: 14,
          labels: [
            for (final s in _stageFilters)
              s == null ? l10n.crmFilterAll : crmStageLabel(s, l10n),
          ],
          selectedIndex: _stageFilters.indexOf(state.stageFilter),
          onChanged: (i) =>
              context.read<CrmLeadsCubit>().setStageFilter(_stageFilters[i]),
        ),
      ),
      floatingActionButton: Builder(
        builder: (context) => FloatingActionButton.extended(
          onPressed: () => _showAddLeadSheet(context),
          icon: const Icon(LucideIcons.user_plus),
          label: Text(l10n.crmAddLeadAction),
        ),
      ),
      body: BlocBuilder<CrmLeadsCubit, CrmLeadsState>(
        builder: (context, state) {
          switch (state.status) {
            case CrmLeadsStatus.initial:
            case CrmLeadsStatus.loading:
              return const AppSpinner.page();
            case CrmLeadsStatus.error:
              return ErrorState(
                title: l10n.crmLoadErrorTitle,
                onRetry: () => context.read<CrmLeadsCubit>().load(),
              );
            case CrmLeadsStatus.ready:
              return _CrmBody(state: state);
          }
        },
      ),
    );
  }

  Future<void> _showAddLeadSheet(BuildContext context) async {
    final cubit = context.read<CrmLeadsCubit>();
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: _AddLeadSheet(controller: controller, cubit: cubit),
      ),
    );
    controller.dispose();
    if (created == true && context.mounted) {
      AppToast.success(context, l10n.crmLeadCreatedSuccess);
    }
  }
}

class _CrmBody extends StatelessWidget {
  const _CrmBody({required this.state});

  final CrmLeadsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return RefreshIndicator(
      onRefresh: () => context.read<CrmLeadsCubit>().load(),
      child: CustomScrollView(
        slivers: [
          if (state.dueReminders.isNotEmpty)
            SliverToBoxAdapter(
              child: _DueTodayBanner(
                reminders: state.dueReminders,
                permissionDenied: state.permissionDenied,
              ),
            ),
          if (state.leads.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: LucideIcons.users,
                headline: l10n.crmEmptyTitle,
                body: l10n.crmEmptyBody,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xxxl,
              ),
              sliver: SliverList.separated(
                itemCount: state.leads.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) => _LeadCard(lead: state.leads[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _DueTodayBanner extends StatelessWidget {
  const _DueTodayBanner({
    required this.reminders,
    required this.permissionDenied,
  });

  final List<CrmReminder> reminders;
  final bool permissionDenied;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.lg,
        end: AppSpacing.lg,
        top: AppSpacing.lg,
      ),
      child: Container(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.warning.withValues(alpha: 0.10),
          borderRadius: appRadius(AppRadii.lg),
          border: Border.all(color: colors.warning.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.bell,
                  color: colors.warning,
                  size: AppSpacing.lg,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.crmDueTodayTitle(reminders.length),
                    style: styles.titleMedium.copyWith(color: colors.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final r in reminders.take(3))
              Padding(
                padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxs),
                child: Text(
                  r.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: styles.bodyMedium.copyWith(color: colors.textMuted),
                ),
              ),
            if (permissionDenied) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.crmRemindersPermissionDenied,
                style: styles.labelMedium.copyWith(color: colors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  const _LeadCard({required this.lead});

  final CrmLead lead;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final trimmedName = lead.displayName.trim();
    final initial = trimmedName.isEmpty ? '؟' : trimmedName.substring(0, 1);

    return Material(
      color: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: appRadius(AppRadii.lg),
        side: BorderSide(color: colors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: appRadius(AppRadii.lg),
        onTap: () => _openDetail(context, lead),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initial,
                  style: styles.titleMedium.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: styles.titleMedium.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      l10n.crmLeadLastActivity(
                        _relativeDay(context, lead.updatedAt),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: styles.labelMedium.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              DcStatusChip(
                label: crmStageLabel(lead.stage, l10n),
                tone: crmStageTone(lead.stage),
                dot: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeDay(BuildContext context, DateTime when) {
    final l10n = AppLocalizations.of(context)!;
    final days = DateTime.now().difference(when.toLocal()).inDays;
    if (days <= 0) return l10n.crmRelativeToday;
    if (days == 1) return l10n.crmRelativeYesterday;
    return l10n.crmRelativeDaysAgo(days);
  }
}

/// Opens [LeadDetailPage] with a fresh [LeadDetailCubit] provider.
void _openDetail(BuildContext context, CrmLead lead) {
  final parent = context.read<CrmLeadsCubit>();
  Navigator.of(context)
      .push(
        MaterialPageRoute<void>(
          builder: (_) => BlocProvider<LeadDetailCubit>(
            create: (_) => getIt<LeadDetailCubit>()..open(lead),
            child: LeadDetailPage(lead: lead),
          ),
        ),
      )
      .then((_) => parent.load());
}

class _AddLeadSheet extends StatelessWidget {
  const _AddLeadSheet({required this.controller, required this.cubit});

  final TextEditingController controller;
  final CrmLeadsCubit cubit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.crmAddLeadTitle,
              style: AppTextStyles.of(context).titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(controller: controller, label: l10n.crmLeadNameLabel),
            const SizedBox(height: AppSpacing.lg),
            AppButton.filledPrimary(
              label: l10n.crmAddLeadAction,
              expanded: true,
              onPressed: () async {
                final ok = await cubit.createManualLead(controller.text);
                if (context.mounted) Navigator.of(context).pop(ok);
              },
            ),
          ],
        ),
      ),
    );
  }
}
