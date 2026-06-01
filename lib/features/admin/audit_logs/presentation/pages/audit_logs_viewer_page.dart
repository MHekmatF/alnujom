// Phase 20 (spec/020-admin-dashboard) — T023
// AuditLogsViewerPage: read-only, paginated, localized, themed viewer of
// public.audit_logs. Gated by audit_logs.view at BOTH the route
// (requireAuditLogsViewRedirect) and the swapped RLS policy
// (20260601120004). NO create/edit/delete affordance (FR-021).
// Constitution IX: zero Supabase imports. Phase 2 tokens only.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../../core/di/injection.dart';
import '../../../../../core/theme/spacing.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.auditLogsTitle)),
      body: BlocBuilder<AuditLogCubit, AuditLogState>(
        builder: (ctx, state) {
          if (state.isLoadingFirstPage && state.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
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
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount:
                  state.items.length + (state.isLoadingNextPage ? 1 : 0),
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (ctx, index) {
                if (index >= state.items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
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
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final timestamp = DateFormat.yMMMd(locale).add_Hms().format(
          entry.createdAt.toLocal(),
        );

    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        title: Text(entry.action, style: theme.textTheme.titleSmall),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
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
              _FieldRow(
                label: l10n.auditLogsTimestampLabel,
                value: timestamp,
              ),
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodySmall,
          children: [
            TextSpan(
              text: '$label: ',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
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
    final theme = Theme.of(context);
    final hasData = json != null && json!.isNotEmpty;
    final text = hasData
        ? const JsonEncoder.withIndent('  ').convert(json)
        : emptyLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppSpacing.xs),
          ),
          child: SelectableText(
            text,
            textDirection: TextDirection.ltr,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
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
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context)!.actionReload),
            ),
          ],
        ),
      ),
    );
  }
}
