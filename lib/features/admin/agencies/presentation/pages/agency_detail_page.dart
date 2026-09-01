// Phase 19 (spec/019-agencies) — T069
// AgencyDetailPage: shows a single agency with admin-decrypted PII +
// evidence docs + the four moderation actions via AgencyDecisionDialog.
// Mirrors ReportDetailPage (Phase 18).
// Constitution IX: zero Supabase imports.
// Constitution VI: design tokens only; no inline hex/font/padding.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/errors/result.dart';
import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_spinner.dart';
import '../../../../../core/widgets/app_toast.dart';
import '../../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../../core/widgets/ds/dc_status_chip.dart';
import '../../../../../core/widgets/error_state.dart';
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
              return DcCrownScaffold(
                title: l10n.agencies_queue_title,
                dense: true,
                leading: DcCrownIconButton(
                  icon: Icons.arrow_forward,
                  onTap: () =>
                      ctx.canPop() ? ctx.pop() : ctx.go(AppRoutes.shellHome),
                ),
                body: const AppSpinner.page(),
              );
            }
            if (_error != null || _item == null) {
              return DcCrownScaffold(
                title: l10n.agencies_queue_title,
                dense: true,
                leading: DcCrownIconButton(
                  icon: Icons.arrow_forward,
                  onTap: () =>
                      ctx.canPop() ? ctx.pop() : ctx.go(AppRoutes.shellHome),
                ),
                // Batch-2: the ad-hoc Text + AppButton column became the shared
                // ErrorState (glyph badge, title, tonal Retry). Same reload.
                body: ErrorState(
                  title: l10n.errorGeneric,
                  message: _error,
                  onRetry: _loadDetail,
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
      AppToast.success(context, l10n.agency_decision_success);
      _loadDetail();
      context.read<AgencyModerationCubit>().reset();
    } else if (state is AgencyModerationFailure) {
      AppToast.error(context, state.failure.message);
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
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final cubit = context.read<AgencyModerationCubit>();
    final agency = item.agency;
    final request = item.request;

    return DcCrownScaffold(
      title: agency.name,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.shellHome),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Agency basic info ────────────────────────────────────────────
            Text(agency.name, style: styles.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            _AgencyStatusChip(status: agency.status, l10n: l10n),
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
                label: l10n.agency_whatsapp_label,
                value: agency.whatsapp!,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (agency.address != null) ...[
              _InfoRow(
                label: l10n.agency_address_label,
                value: agency.address!,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (agency.description != null &&
                agency.description!.isNotEmpty) ...[
              _InfoRow(
                label: l10n.agency_description_label,
                value: agency.description!,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            const Divider(height: AppSpacing.xl),

            // ── Verification request ─────────────────────────────────────────
            Text(l10n.agency_verify_title, style: styles.titleMedium),
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
                style: styles.labelLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final url in request.evidenceUrls!)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: AppSpacing.xs,
                  ),
                  child: Text(
                    url,
                    style: styles.bodyMedium.copyWith(color: colors.primary),
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
    final AgencyStatus status = agency.status as AgencyStatus;

    if (isLoading) {
      return const AppSpinner();
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        // Approve — only when pending
        if (status == AgencyStatus.pending)
          AppButton(
            label: l10n.agency_action_approve,
            variant: AppButtonVariant.filledSuccess,
            icon: LucideIcons.circle_check,
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
          AppButton(
            label: l10n.agency_action_reject,
            variant: AppButtonVariant.destructive,
            icon: LucideIcons.circle_x,
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
          AppButton(
            label: l10n.agency_action_suspend,
            variant: AppButtonVariant.destructive,
            icon: LucideIcons.circle_pause,
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
          AppButton(
            label: l10n.agency_action_reinstate,
            icon: LucideIcons.circle_play,
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

// ─── Status chip ─────────────────────────────────────────────────────────────

class _AgencyStatusChip extends StatelessWidget {
  const _AgencyStatusChip({required this.status, required this.l10n});

  final AgencyStatus status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      AgencyStatus.pending => (
        l10n.agency_status_pending,
        DcStatusTone.neutral,
      ),
      AgencyStatus.approved => (
        l10n.agency_status_approved,
        DcStatusTone.green,
      ),
      AgencyStatus.rejected => (l10n.agency_status_rejected, DcStatusTone.red),
      AgencyStatus.suspended => (
        l10n.agency_status_suspended,
        DcStatusTone.neutral,
      ),
    };
    return DcStatusChip(label: label, tone: tone);
  }
}

// ─── Info row ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.label_colon_prefix(label),
          style: styles.labelMedium.copyWith(color: colors.textMuted),
        ),
        Expanded(child: Text(value, style: styles.bodyMedium)),
      ],
    );
  }
}
