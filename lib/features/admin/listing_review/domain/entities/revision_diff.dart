import 'package:equatable/equatable.dart';

import '../../../../listing_form/domain/entities/listing_revision.dart';

/// Phase 031 (WS-B) — the admin review payload for one pending revision: the
/// revision (proposed snapshot + manifest) plus the CURRENT live listing
/// snapshot, both keyed by the same `proposed` JSON keys so the review screen
/// can list changed fields side-by-side.
class RevisionDiff extends Equatable {
  const RevisionDiff({
    required this.revision,
    required this.current,
    required this.proposed,
  });

  final ListingRevision revision;

  /// Current live values keyed by the proposed JSON keys (e.g. `title`,
  /// `price_amount`, `area_size`…).
  final Map<String, dynamic> current;

  /// Staged proposed values (same keys).
  final Map<String, dynamic> proposed;

  /// The subset of [_diffKeys] whose current vs proposed values differ
  /// (stringified comparison, null-safe). Drives the compact field summary.
  List<String> get changedKeys {
    final keys = <String>[];
    for (final k in _diffKeys) {
      final c = current[k];
      final p = proposed[k];
      if (_normalize(c) != _normalize(p)) keys.add(k);
    }
    return keys;
  }

  static String _normalize(Object? v) {
    if (v == null) return '';
    if (v is List) return v.map((e) => e.toString()).join(',');
    return v.toString().trim();
  }

  /// The editable keys we surface in the diff, in form order.
  static const List<String> _diffKeys = <String>[
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

  @override
  List<Object?> get props => [revision, current, proposed];
}
