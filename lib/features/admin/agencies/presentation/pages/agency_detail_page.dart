// Phase 19 (spec/019-agencies) — T069
// AgencyDetailPage: shows a single agency with admin-decrypted PII +
// evidence docs + the four moderation actions via AgencyDecisionDialog.
// Mirrors ReportDetailPage (Phase 18).
// Constitution IX: zero Supabase imports.
// Constitution VI: design tokens only; no inline hex/font/padding.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/errors/result.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../agency/domain/entities/agency_status.dart';
import '../../domain/entities/agency_verification_item.dart';
import '../../domain/repositories/agencies_admin_repository.dart';
import '../bloc/agency_moderation_cubit.dart';
import '../widgets/agency_decision_dialog.dart';

class AgencyDetailPage extends StatefulWidget {
  const AgencyDetailPage({super.key, required this.agencyId});

  final String agencyId;

  @override
  State<AgencyDetailPage> createState() => _AgencyDetailPageState();
}

class _AgencyDetailPageState extends State<AgencyDetailPage> {
  AgencyVerificationItem? _item;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // Load the single agency by id via the repository's loadDetail — it reads
    // v_agencies (admin sees ANY status) + the latest verification request +
    // the Vault-decrypted PII. (Previously this reused the pending-only queue
    // use-case + firstWhere, so an approved/suspended agency was never found
    // and the page rendered a spurious "something went wrong".)
    final result = await getIt<AgenciesAdminRepository>().loadDetail(
      widget.agencyId,
    );
    switch (result) {
      case Success(:final value):
        if (mounted) {
          setState(() {
            _item = value;
            _loading = false;
          });
        }
      case FailureResult(:final failure):
        if (mounted) {
          setState(() {
            _error = failure.message;
            _loading = false;
          });
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AgencyModerationCubit>(
      create: (_) => getIt<AgencyModerationCubit>(),
      child: BlocListener<AgencyModerationCubit, AgencyModerationState>(
        listener: _onModerationStateChanged,
        child: Builder(
          builder: (ctx) {
            final l10n = AppLocalizations.of(ctx)!;
            if (_loading) {
              return Scaffold(
                appBar: AppBar(title: Text(l10n.agencies_queue_title)),
                body: const Center(child: CircularProgressIndicator()),
              );
            }
            if (_error != null || _item == null) {
              return Scaffold(
                appBar: AppBar(title: Text(l10n.agencies_queue_title)),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error ?? l10n.errorGeneric,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton(
                          onPressed: _loadDetail,
                          child: Text(l10n.actionReload),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return _AgencyDetailView(item: _item!, onReload: _loadDetail);
          },
        ),
      ),
    );
  }

  void _onModerationStateChanged(
    BuildContext context,
    AgencyModerationState state,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (state is AgencyModerationSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.agency_decision_success)),
      );
      _loadDetail();
      context.read<AgencyModerationCubit>().reset();
    } else if (state is AgencyModerationFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.failure.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      context.read<AgencyModerationCubit>().reset();
    }
  }
}

class _AgencyDetailView extends StatelessWidget {
  const _AgencyDetailView({required this.item, required this.onReload});

  final AgencyVerificationItem item;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cubit = context.read<AgencyModerationCubit>();
    final agency = item.agency;
    final request = item.request;

    return Scaffold(
      appBar: AppBar(title: Text(agency.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Agency basic info ────────────────────────────────────────────
            Text(agency.name, style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            _StatusPill(status: agency.status, l10n: l10n),
            const SizedBox(height: AppSpacing.md),

            if (item.ownerDisplayName != null) ...[
              _InfoRow(label: 'Owner', value: item.ownerDisplayName!),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (agency.phone != null) ...[
              _InfoRow(label: l10n.agency_phone_label, value: agency.phone!),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (agency.whatsapp != null) ...[
              _InfoRow(
                  label: l10n.agency_whatsapp_label, value: agency.whatsapp!),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (agency.address != null) ...[
              _InfoRow(
                  label: l10n.agency_address_label, value: agency.address!),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (agency.description != null &&
                agency.description!.isNotEmpty) ...[
              _InfoRow(
                  label: l10n.agency_description_label,
                  value: agency.description!),
              const SizedBox(height: AppSpacing.sm),
            ],

            const Divider(height: AppSpacing.xl),

            // ── Verification request ─────────────────────────────────────────
            Text(l10n.agency_verify_title,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            _InfoRow(
              label: 'Submitted',
              value: request.submittedAt.toLocal().toString().substring(0, 16),
            ),
            if (request.decisionReason != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _InfoRow(
                label: l10n.agency_reject_reason_label,
                value: request.decisionReason!,
              ),
            ],

            // ── Evidence document links ──────────────────────────────────────
            if (request.evidenceUrls != null &&
                request.evidenceUrls!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.agency_verify_documents_label,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final url in request.evidenceUrls!)
                Padding(
                  padding:
                      const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
                  child: Text(
                    url,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],

            const Divider(height: AppSpacing.xl),

            // ── Admin-only decrypted PII ─────────────────────────────────────
            if (item.idDocumentNumber != null) ...[
              _InfoRow(
                label: l10n.agency_verify_id_number_label,
                value: item.idDocumentNumber!,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (item.commercialRegistrationNumber != null) ...[
              _InfoRow(
                label: l10n.agency_verify_registration_label,
                value: item.commercialRegistrationNumber!,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            const SizedBox(height: AppSpacing.lg),

            // ── Moderation actions ───────────────────────────────────────────
            BlocBuilder<AgencyModerationCubit, AgencyModerationState>(
              builder: (ctx, state) {
                final isLoading = state is AgencyModerationLoading;
                return _ActionButtons(
                  agency: agency,
                  isLoading: isLoading,
                  cubit: cubit,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Action buttons ───────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.agency,
    required this.isLoading,
    required this.cubit,
  });

  final dynamic agency; // Agency
  final bool isLoading;
  final AgencyModerationCubit cubit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final AgencyStatus status = agency.status as AgencyStatus;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        // Approve — only when pending
        if (status == AgencyStatus.pending)
          FilledButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: Text(l10n.agency_action_approve),
            onPressed: () async {
              final result = await AgencyDecisionDialog.show(
                context,
                AgencyDecisionAction.approve,
              );
              if (result != null && context.mounted) {
                await cubit.approve(agency.id as String);
              }
            },
          ),

        // Reject — only when pending
        if (status == AgencyStatus.pending)
          OutlinedButton.icon(
            icon: Icon(
              Icons.cancel_outlined,
              color: theme.colorScheme.error,
            ),
            label: Text(
              l10n.agency_action_reject,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: theme.colorScheme.error),
            ),
            onPressed: () async {
              final result = await AgencyDecisionDialog.show(
                context,
                AgencyDecisionAction.reject,
              );
              if (result != null && context.mounted) {
                await cubit.reject(
                  agency.id as String,
                  preset: result.rejectPreset ?? '',
                  detail: result.rejectDetail,
                );
              }
            },
          ),

        // Suspend — only when approved
        if (status == AgencyStatus.approved)
          OutlinedButton.icon(
            icon: Icon(
              Icons.pause_circle_outline,
              color: theme.colorScheme.error,
            ),
            label: Text(
              l10n.agency_action_suspend,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: theme.colorScheme.error),
            ),
            onPressed: () async {
              final result = await AgencyDecisionDialog.show(
                context,
                AgencyDecisionAction.suspend,
              );
              if (result != null && context.mounted) {
                await cubit.suspend(
                  agency.id as String,
                  reason: result.suspendReason,
                );
              }
            },
          ),

        // Reinstate — only when suspended
        if (status == AgencyStatus.suspended)
          FilledButton.icon(
            icon: const Icon(Icons.play_circle_outline),
            label: Text(l10n.agency_action_reinstate),
            onPressed: () async {
              final result = await AgencyDecisionDialog.show(
                context,
                AgencyDecisionAction.reinstate,
              );
              if (result != null && context.mounted) {
                await cubit.reinstate(agency.id as String);
              }
            },
          ),
      ],
    );
  }
}

// ─── Status pill ─────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.l10n});

  final AgencyStatus status;
  final AppLocalizations l10n;

  String _label() {
    switch (status) {
      case AgencyStatus.pending:
        return l10n.agency_status_pending;
      case AgencyStatus.approved:
        return l10n.agency_status_approved;
      case AgencyStatus.rejected:
        return l10n.agency_status_rejected;
      case AgencyStatus.suspended:
        return l10n.agency_status_suspended;
    }
  }

  Color _color(ThemeData theme) {
    switch (status) {
      case AgencyStatus.pending:
        return theme.colorScheme.tertiary;
      case AgencyStatus.approved:
        return theme.colorScheme.primary;
      case AgencyStatus.rejected:
        return theme.colorScheme.error;
      case AgencyStatus.suspended:
        return theme.colorScheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _color(theme);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: color),
      ),
      child: Text(
        _label(),
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

// ─── Info row ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
