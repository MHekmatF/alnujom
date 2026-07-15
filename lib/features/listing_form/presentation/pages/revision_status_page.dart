// Phase 035 (DC "Blue Crown" · Listing & Viewing · FLOW A — Edit-with-revision).
//
// The publisher-facing status screen for a listing that has an open
// `pending_review` revision. Instead of dropping the owner straight back into
// the edit form, it shows: the stay-live banner, a CURRENT → PROPOSED diff of
// what they changed, an "awaiting review" note, and a «Continue editing» action
// (which opens the edit form — the bloc resumes the same open revision).
//
// Read-only + behaviour-preserving: it reuses the owner-readable reads
// (`FindOpenRevision` + `loadCurrentSnapshot`) — no new backend. Reached from
// My Listings when a card carries an "edit in review" badge.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_form_state.dart' show ListingFormMode;
import '../../domain/entities/listing_revision.dart';
import '../../domain/repositories/listing_revisions_repository.dart';
import '../../domain/usecases/find_open_revision.dart';
import '../util/listing_enum_labels.dart';
import '../widgets/revision_banner.dart';

/// The keys we surface in the diff, in form order (mirrors the admin review
/// screen's field set so both sides show an identical change list).
const List<String> _diffKeys = <String>[
  'title',
  'purpose',
  'property_type',
  'price_amount',
  'price_currency_code',
  'governorate_id',
  'city_id',
  'area_id',
  'address_text',
  'area_size',
  'rooms',
  'bathrooms',
  'floor',
  'description',
  'amenities',
  'year_built',
  'furnished',
  'parking',
  'phone',
  'whatsapp',
  'location_visibility',
  'contact_name_visibility',
];

/// The revision + the current live snapshot, resolved together for the diff.
class _RevisionData {
  const _RevisionData({required this.revision, required this.current});
  final ListingRevision revision;
  final Map<String, dynamic> current;
}

class RevisionStatusPage extends StatefulWidget {
  const RevisionStatusPage({super.key, required this.listingId});

  final String listingId;

  @override
  State<RevisionStatusPage> createState() => _RevisionStatusPageState();
}

class _RevisionStatusPageState extends State<RevisionStatusPage> {
  late Future<_RevisionData?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_RevisionData?> _load() async {
    final revision = await getIt<FindOpenRevision>().call(widget.listingId);
    if (revision == null || !revision.isPending) return null;
    final current =
        await getIt<ListingRevisionsRepository>().loadCurrentSnapshot(
          widget.listingId,
        ) ??
        const <String, dynamic>{};
    return _RevisionData(revision: revision, current: current);
  }

  void _continueEditing() {
    context.goNamed(
      AppRouteNames.publisherListingsEdit,
      pathParameters: {'id': widget.listingId},
      extra: ListingFormMode.edit,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DcCrownScaffold(
      title: l10n.revisionStatusTitle,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.shellHome),
      ),
      body: FutureBuilder<_RevisionData?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AppSpinner.page();
          }
          if (snapshot.hasError) {
            return _CenteredMessage(text: l10n.revisionStatusError);
          }
          final data = snapshot.data;
          if (data == null) {
            // No pending revision (applied/rejected meanwhile) — offer the form.
            return _CenteredMessage(
              text: l10n.revisionStatusNoChanges,
              action: _continueEditing,
              actionLabel: l10n.revisionStatusContinueEditing,
            );
          }
          return _Body(data: data);
        },
      ),
      bottomNavigationBar: FutureBuilder<_RevisionData?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.data == null) return const SizedBox.shrink();
          return _BottomBar(onContinue: _continueEditing);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.data});

  final _RevisionData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    final proposed = data.revision.proposed;
    final current = data.current;
    final changed = <String>[
      for (final k in _diffKeys)
        if (_normalize(current[k]) != _normalize(proposed[k])) k,
    ];

    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        const RevisionBanner(),
        Text(
          l10n.revisionStatusProposedChanges,
          style: styles.titleMedium.copyWith(color: colors.onSurface),
        ),
        const SizedBox(height: AppSpacing.md),
        if (changed.isEmpty)
          Text(
            l10n.revisionStatusNoFieldChanges,
            style: styles.bodyMedium.copyWith(color: colors.textMuted),
          )
        else
          for (final key in changed)
            _DiffRow(
              label: _fieldLabel(l10n, key),
              before: _formatValue(l10n, key, current[key]),
              after: _formatValue(l10n, key, proposed[key]),
            ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.surfaceVariant,
            borderRadius: appRadius(AppRadii.md),
          ),
          child: Row(
            children: [
              Icon(Icons.schedule, size: 20, color: colors.textMuted),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.revisionStatusAwaitingReview,
                  style: styles.bodyMedium.copyWith(color: colors.onSurface),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

/// One CURRENT → PROPOSED field comparison — the old value struck through in the
/// error tone, the new value highlighted in a success tint (DC diff row).
class _DiffRow extends StatelessWidget {
  const _DiffRow({
    required this.label,
    required this.before,
    required this.after,
  });

  final String label;
  final String before;
  final String after;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: appRadius(AppRadii.md),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: styles.labelMedium.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.remove, size: 16, color: colors.onErrorContainer),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  before,
                  style: styles.bodyMedium.copyWith(
                    color: colors.onErrorContainer,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: colors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: colors.verifiedContainer,
              borderRadius: appRadius(AppRadii.sm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.add, size: 16, color: colors.onSuccess),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    after,
                    style: styles.bodyMedium.copyWith(
                      color: colors.onSuccess,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          border: BorderDirectional(top: BorderSide(color: colors.outline)),
        ),
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: AppButton(
          label: l10n.revisionStatusContinueEditing,
          icon: Icons.edit,
          expanded: true,
          onPressed: onContinue,
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.text, this.action, this.actionLabel});

  final String text;
  final VoidCallback? action;
  final String? actionLabel;

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
              text,
              textAlign: TextAlign.center,
              style: styles.bodyLarge.copyWith(color: colors.textMuted),
            ),
            if (action != null && actionLabel != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(label: actionLabel!, onPressed: action),
            ],
          ],
        ),
      ),
    );
  }
}

/// Normalizes a value for equality comparison (matches the admin diff logic).
String _normalize(Object? v) {
  if (v == null) return '';
  if (v is List) return v.map((e) => e.toString()).join(',');
  return v.toString().trim();
}

/// Human-readable value for a proposed/current field. Enum keys resolve to
/// localized labels; lists join; everything else falls back to its string.
String _formatValue(AppLocalizations l10n, String key, Object? v) {
  if (v == null) return '—';
  switch (key) {
    case 'purpose':
      try {
        return listingPurposeLabel(ListingPurposeDb.fromDbValue('$v'), l10n);
      } catch (_) {
        return '$v';
      }
    case 'property_type':
      try {
        return propertyTypeLabel(PropertyTypeDb.fromDbValue('$v'), l10n);
      } catch (_) {
        return '$v';
      }
  }
  if (v is List) {
    if (v.isEmpty) return '—';
    return v.map((e) => e.toString()).join('، ');
  }
  final s = v.toString().trim();
  return s.isEmpty ? '—' : s;
}

String _fieldLabel(AppLocalizations l10n, String key) {
  switch (key) {
    case 'title':
      return l10n.fieldLabelTitle;
    case 'purpose':
      return l10n.fieldLabelPurpose;
    case 'property_type':
      return l10n.fieldLabelPropertyType;
    case 'price_amount':
      return l10n.adminRevisionFieldPrice;
    case 'price_currency_code':
      return l10n.adminRevisionFieldCurrency;
    case 'address_text':
      return l10n.adminRevisionFieldAddress;
    case 'area_size':
      return l10n.adminRevisionFieldAreaSize;
    case 'rooms':
      return l10n.adminRevisionFieldRooms;
    case 'bathrooms':
      return l10n.adminRevisionFieldBathrooms;
    case 'floor':
      return l10n.adminRevisionFieldFloor;
    case 'description':
      return l10n.adminRevisionFieldDescription;
    case 'amenities':
      return l10n.adminRevisionFieldAmenities;
    case 'year_built':
      return l10n.adminRevisionFieldYearBuilt;
    case 'furnished':
      return l10n.adminRevisionFieldFurnished;
    case 'parking':
      return l10n.adminRevisionFieldParking;
    case 'phone':
      return l10n.adminRevisionFieldPhone;
    case 'whatsapp':
      return l10n.adminRevisionFieldWhatsapp;
    case 'governorate_id':
    case 'city_id':
    case 'area_id':
      return l10n.adminRevisionFieldLocation;
    case 'location_visibility':
      return l10n.adminRevisionFieldLocationVisibility;
    case 'contact_name_visibility':
      return l10n.adminRevisionFieldContactVisibility;
    default:
      return key;
  }
}
