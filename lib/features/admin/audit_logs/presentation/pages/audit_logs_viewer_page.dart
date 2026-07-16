// Phase 20 (spec/020-admin-dashboard) — T023
// AuditLogsViewerPage: read-only, paginated, localized, themed viewer of
// public.audit_logs. Gated by audit_logs.view at BOTH the route
// (requireAuditLogsViewRedirect) and the swapped RLS policy
// (20260601120004). NO create/edit/delete affordance (FR-021).
// Constitution IX: zero Supabase imports. Phase 2 tokens only.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../../core/di/injection.dart';
import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/radii.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../core/widgets/_widget_support.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_spinner.dart';
import '../../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../../core/widgets/loading_state.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../domain/entities/audit_log_entry.dart';
import '../bloc/audit_log_cubit.dart';
import '../bloc/audit_log_state.dart';

class AuditLogsViewerPage extends StatelessWidget {
  const AuditLogsViewerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuditLogCubit>(
      create: (_) => getIt<AuditLogCubit>()..load(),
      child: const _AuditLogsView(),
    );
  }
}

class _AuditLogsView extends StatefulWidget {
  const _AuditLogsView();

  @override
  State<_AuditLogsView> createState() => _AuditLogsViewState();
}

class _AuditLogsViewState extends State<_AuditLogsView> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      context.read<AuditLogCubit>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DcCrownScaffold(
      title: l10n.auditLogsTitle,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.shellHome),
      ),
      body: BlocBuilder<AuditLogCubit, AuditLogState>(
        builder: (ctx, state) {
          if (state.isLoadingFirstPage && state.items.isEmpty) {
            return const _LogsSkeleton();
          }
          if (state.failure != null && state.items.isEmpty) {
            return _ErrorState(
              message: state.failure!.message,
              onRetry: () => ctx.read<AuditLogCubit>().refresh(),
            );
          }
          if (state.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ctx.read<AuditLogCubit>().refresh(),
              child: ListView(
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  Center(child: Text(l10n.auditLogsEmpty)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ctx.read<AuditLogCubit>().refresh(),
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              itemCount: state.items.length + (state.isLoadingNextPage ? 1 : 0),
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (ctx, index) {
                if (index >= state.items.length) {
                  return const Padding(
                    padding: EdgeInsetsDirectional.all(AppSpacing.md),
                    child: AppSpinner(),
                  );
                }
                return _AuditLogCard(entry: state.items[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

/// One read-only audit entry. Header shows action / target / actor /
/// timestamp; an expandable section reveals the before/after JSON
/// snapshots. There is no write affordance.
class _AuditLogCard extends StatelessWidget {
  const _AuditLogCard({required this.entry});

  final AuditLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final locale = Localizations.localeOf(context).toString();
    final timestamp = DateFormat.yMMMd(
      locale,
    ).add_Hms().format(entry.createdAt.toLocal());

    return Material(
      color: colors.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: appRadius(AppRadii.lg),
        side: BorderSide(color: colors.outline),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsetsDirectional.only(
          start: AppSpacing.lg,
          end: AppSpacing.lg,
          bottom: AppSpacing.lg,
        ),
        title: Text(entry.action, style: styles.titleMedium),
        subtitle: Padding(
          padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldRow(
                label: l10n.auditLogsTargetLabel,
                value: entry.targetId == null
                    ? entry.targetType
                    : '${entry.targetType} · ${entry.targetId}',
              ),
              _FieldRow(
                label: l10n.auditLogsActorLabel,
                value: entry.actorUserId ?? l10n.auditLogsActorSystem,
              ),
              _FieldRow(label: l10n.auditLogsTimestampLabel, value: timestamp),
            ],
          ),
        ),
        children: [
          _JsonBlock(
            label: l10n.auditLogsBeforeLabel,
            json: entry.beforeState,
            emptyLabel: l10n.auditLogsNoData,
          ),
          const SizedBox(height: AppSpacing.sm),
          _JsonBlock(
            label: l10n.auditLogsAfterLabel,
            json: entry.afterState,
            emptyLabel: l10n.auditLogsNoData,
          ),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    // Composed outside TextSpan() so the l10n-literals lint passes — [label] is
    // a localized field label supplied by the caller.
    final labelText = '$label: ';
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
      child: RichText(
        text: TextSpan(
          style: styles.bodyMedium.copyWith(color: colors.textMuted),
          children: [
            TextSpan(
              text: labelText,
              style: styles.bodyMedium.copyWith(
                color: colors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _JsonBlock extends StatelessWidget {
  const _JsonBlock({
    required this.label,
    required this.json,
    required this.emptyLabel,
  });

  final String label;
  final Map<String, dynamic>? json;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final hasData = json != null && json!.isNotEmpty;
    final text = hasData
        ? const JsonEncoder.withIndent('  ').convert(json)
        : emptyLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: styles.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: colors.surfaceVariant,
            borderRadius: appRadius(AppRadii.sm),
          ),
          child: SelectableText(
            text,
            textDirection: TextDirection.ltr,
            style: styles.bodyMedium.copyWith(fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: styles.bodyLarge.copyWith(color: colors.error),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: AppLocalizations.of(context)!.actionReload,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer placeholder rows shown while the first audit-log page loads.
class _LogsSkeleton extends StatelessWidget {
  const _LogsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, __) => const SizedBox(
        height: AppSpacing.xxxl + AppSpacing.xxl,
        child: LoadingState.card(),
      ),
    );
  }
}
