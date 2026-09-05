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
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/routing/app_router.dart';
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
import '../../../../core/widgets/load_more_row.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import '../../../crm/presentation/widgets/add_to_crm_action.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/presentation/money_formatter.dart';
import '../../../listing_form/domain/entities/listing.dart' show PropertyType;
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
                  // Plan A36 — paged; the row at the end fetches the next page.
                  itemCount: state.viewings.length + (state.hasMore ? 1 : 0),
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) {
                    if (i >= state.viewings.length) {
                      return LoadMoreRow(
                        loading: state.loadingMore,
                        onLoad: () =>
                            context.read<ViewingsCubit>().loadMore(),
                      );
                    }
                    return StaggeredListItem(
                      index: i,
                      child: _ViewingCard(viewing: state.viewings[i]),
                    );
                  },
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
    final locale = Localizations.localeOf(context);
    final localeStr = locale.toString();

    final title = viewing.listingTitle ?? l10n.viewingListingUnavailable;
    final local = viewing.scheduledAt.toLocal();
    final dateStr = DateFormat('EEEE d MMMM', localeStr).format(local);
    final timeStr = DateFormat.jm(localeStr).format(local);

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: appRadius(AppRadii.lg),
        border: Border.all(color: colors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Thumb(propertyType: viewing.propertyType),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: styles.bodyLarge.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _statusChip(l10n, viewing.status),
                        ],
                      ),
                      if (viewing.priceAmount != null &&
                          viewing.priceCurrency != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          MoneyFormatter.formatAmount(
                            viewing.priceAmount!,
                            viewing.priceCurrency!,
                            locale: locale,
                          ),
                          textDirection: TextDirection.ltr,
                          style: styles.priceMedium.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      _WhenRow(date: dateStr, time: timeStr),
                      if (viewing.note != null &&
                          viewing.note!.trim().isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          viewing.note!.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: styles.bodyMedium.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          _footer(context, l10n, colors, title),
        ],
      ),
    );
  }

  /// The card footer, branched by the caller's role:
  ///   - publisher + requested  → Confirm / Decline, plus «add to CRM»
  ///   - requester              → call/WhatsApp the listing contact, plus a
  ///                              low-key «cancel» while the request is live
  /// Renders nothing (no divider) when there is no action for a terminal row.
  Widget _footer(
    BuildContext context,
    AppLocalizations l10n,
    AppColors colors,
    String title,
  ) {
    final rows = <Widget>[];

    if (viewing.amIPublisher) {
      if (viewing.status == ViewingStatus.requested) {
        rows.add(
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: l10n.viewingConfirmAction,
                  variant: AppButtonVariant.filledSuccess,
                  size: AppButtonSize.dense,
                  onPressed: () =>
                      _transition(context, ViewingStatus.confirmed),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: l10n.viewingDeclineAction,
                  variant: AppButtonVariant.outlined,
                  size: AppButtonSize.dense,
                  onPressed: () => _transition(context, ViewingStatus.declined),
                ),
              ),
            ],
          ),
        );
      }
      rows.add(
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
      );
    } else {
      final phone = viewing.publisherPhone;
      final whatsapp = viewing.publisherWhatsapp;
      if (phone != null || whatsapp != null) {
        rows.add(
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 16,
                      color: colors.textMuted,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        l10n.viewingContactPublisher,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.of(context).labelMedium.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (phone != null) ...[
                const SizedBox(width: AppSpacing.sm),
                _CircleIconButton(
                  icon: Icons.call,
                  onTap: () => _call(context, phone),
                ),
              ],
              if (whatsapp != null) ...[
                const SizedBox(width: AppSpacing.sm),
                AppButton(
                  label: l10n.cta_whatsapp,
                  variant: AppButtonVariant.whatsapp,
                  size: AppButtonSize.dense,
                  icon: Icons.chat_outlined,
                  onPressed: () => _whatsApp(context, title, whatsapp),
                ),
              ],
            ],
          ),
        );
      }
      if (viewing.status == ViewingStatus.requested ||
          viewing.status == ViewingStatus.confirmed) {
        rows.add(
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton(
              label: l10n.viewingCancelAction,
              variant: AppButtonVariant.text,
              size: AppButtonSize.dense,
              icon: Icons.close,
              onPressed: () => _transition(context, ViewingStatus.cancelled),
            ),
          ),
        );
      }
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, thickness: 1, color: colors.divider),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _interspersed(rows, vertical: true),
          ),
        ),
      ],
    );
  }

  /// Opens the dialer for the listing's public contact number.
  Future<void> _call(BuildContext context, String phone) async {
    final launched = await launchUrl(Uri.parse('tel:$phone'));
    if (!launched && context.mounted) {
      AppToast.error(
        context,
        AppLocalizations.of(context)!.contact_dialer_unavailable,
      );
    }
  }

  /// Opens `wa.me` with the same localized listing pre-fill the detail page uses.
  Future<void> _whatsApp(
    BuildContext context,
    String title,
    String whatsapp,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final link =
        'https://alnujom.app${AppRoutes.listingDetailsFor(viewing.listingId)}';
    final uri = Uri(
      scheme: 'https',
      host: 'wa.me',
      path: whatsapp.replaceAll('+', ''),
      queryParameters: {'text': l10n.contactWhatsappPrefill(title, link)},
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      AppToast.error(context, l10n.contact_whatsapp_app_unavailable);
    }
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

  static List<Widget> _interspersed(
    List<Widget> actions, {
    bool vertical = false,
  }) {
    final out = <Widget>[];
    for (var i = 0; i < actions.length; i++) {
      if (i > 0) {
        out.add(
          vertical
              ? const SizedBox(height: AppSpacing.xs)
              : const SizedBox(width: AppSpacing.sm),
        );
      }
      out.add(actions[i]);
    }
    return out;
  }
}

/// The 74px rounded placeholder thumbnail — a surface2 tile carrying the
/// property-type glyph (viewings never render a photo). Mirrors the DC
/// «معايناتي» card.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.propertyType});

  final PropertyType? propertyType;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: appRadius(AppRadii.md),
      ),
      alignment: Alignment.center,
      child: Icon(
        _propertyIcon(propertyType),
        size: 30,
        color: colors.outlineStrong,
      ),
    );
  }
}

/// The muted «event · date | schedule · time» meta line. The time is forced LTR
/// (clock digits read left-to-right even in Arabic).
class _WhenRow extends StatelessWidget {
  const _WhenRow({required this.date, required this.time});

  final String date;
  final String time;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final style = AppTextStyles.of(context).labelMedium.copyWith(
      color: colors.textMuted,
    );
    return Row(
      children: [
        Icon(Icons.event, size: 14, color: colors.textMuted),
        const SizedBox(width: AppSpacing.xxs),
        Flexible(
          child: Text(
            date,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Icon(Icons.schedule, size: 14, color: colors.textMuted),
        const SizedBox(width: AppSpacing.xxs),
        Text(time, textDirection: TextDirection.ltr, style: style),
      ],
    );
  }
}

/// A 36px circular hairline icon button — the call affordance in the requester
/// footer.
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: colors.card,
      shape: CircleBorder(side: BorderSide(color: colors.outline)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: colors.primary),
        ),
      ),
    );
  }
}

IconData _propertyIcon(PropertyType? t) {
  switch (t) {
    case PropertyType.apartment:
      return Icons.apartment;
    case PropertyType.villa:
      return Icons.villa_outlined;
    case PropertyType.land:
      return Icons.terrain_outlined;
    case PropertyType.shop:
      return Icons.storefront_outlined;
    case PropertyType.office:
      return Icons.business_center_outlined;
    case PropertyType.farm:
      return Icons.agriculture_outlined;
    case PropertyType.warehouse:
      return Icons.warehouse_outlined;
    case PropertyType.other:
    case null:
      return Icons.home_work_outlined;
  }
}
