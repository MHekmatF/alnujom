import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../../../locations/domain/entities/area.dart';
import '../../../locations/domain/entities/governorate.dart';
import '../../../locations/domain/repositories/locations_repository.dart';
import '../../domain/entities/publisher_listing.dart';
import 'status_badge.dart';

/// Tap target for non-editable listings (approved / paused / sold / rented /
/// expired / pending_review). Renders a read-only summary; no edit
/// affordance.
class ReadOnlyListingPreview extends StatefulWidget {
  const ReadOnlyListingPreview({super.key, required this.publisherListing});

  final PublisherListing publisherListing;

  @override
  State<ReadOnlyListingPreview> createState() => _ReadOnlyListingPreviewState();
}

class _ReadOnlyListingPreviewState extends State<ReadOnlyListingPreview> {
  Governorate? _governorate;
  Area? _area;

  @override
  void initState() {
    super.initState();
    _loadLocationLabels();
  }

  Future<void> _loadLocationLabels() async {
    final repo = getIt<LocationsRepository>();
    final listing = widget.publisherListing.listing;
    final govId = listing.governorateId;
    final areaId = listing.areaId;
    Governorate? gov;
    Area? area;
    if (govId != null) {
      try {
        gov = await repo.loadGovernorate(govId);
      } catch (_) {}
    }
    if (areaId != null) {
      try {
        area = await repo.loadArea(areaId);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _governorate = gov;
      _area = area;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final pl = widget.publisherListing;
    final listing = pl.listing;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.readOnlyPreviewTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  listing.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(status: listing.status),
            ],
          ),
          if (listing.status == ListingStatus.approved) ...[
            const SizedBox(height: AppSpacing.md),
            _ApprovedBanner(message: l10n.approvedNotEditableMessage),
          ],
          const SizedBox(height: AppSpacing.lg),
          _Row(
            label: l10n.fieldLabelPurpose,
            value: listing.purpose.toDbValue(),
          ),
          _Row(
            label: l10n.fieldLabelPropertyType,
            value: listing.propertyType.toDbValue(),
          ),
          if (_governorate != null)
            _Row(
              label: l10n.fieldLabelGovernorate,
              value: _governorate!.localizedName(locale),
            ),
          if (_area != null)
            _Row(
              label: l10n.fieldLabelArea,
              value: _area!.localizedName(locale),
            ),
          if (listing.addressText != null && listing.addressText!.isNotEmpty)
            _Row(
              label: l10n.fieldLabelAddressText,
              value: listing.addressText!,
            ),
          if (listing.areaSize != null)
            _Row(
              label: l10n.fieldLabelAreaSize,
              value: listing.areaSize!.toString(),
            ),
          if (listing.rooms != null)
            _Row(
              label: l10n.fieldLabelRooms,
              value: listing.rooms!.toString(),
            ),
          if (listing.bathrooms != null)
            _Row(
              label: l10n.fieldLabelBathrooms,
              value: listing.bathrooms!.toString(),
            ),
          if (listing.floor != null)
            _Row(
              label: l10n.fieldLabelFloor,
              value: listing.floor!.toString(),
            ),
          if (pl.primaryPrice != null)
            _Row(
              label: l10n.fieldLabelPrice,
              value:
                  '${pl.primaryPrice!.amount} ${pl.primaryPrice!.currencyCode}',
            ),
          if (listing.phone != null && listing.phone!.isNotEmpty)
            _Row(label: l10n.fieldLabelPhone, value: listing.phone!),
          if (listing.whatsapp != null && listing.whatsapp!.isNotEmpty)
            _Row(label: l10n.fieldLabelWhatsapp, value: listing.whatsapp!),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovedBanner extends StatelessWidget {
  const _ApprovedBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
