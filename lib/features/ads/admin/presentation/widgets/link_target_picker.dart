// Phase 21 (spec/021-ads-banners) — T024
// LinkTargetPicker: select AdLinkKind + validate the value per R-179.
//   external  → absolute URL (validate URI + http/https scheme)
//   listing   → listing UUID
//   agency    → agency UUID
//   category  → property-type key (apartment/villa/land/shop/office/farm/warehouse/other)
//   search    → free-text query string (any non-empty value)
// Phase 2 tokens only; RTL-safe.
// Constitution IX: zero supabase_flutter imports.
import 'package:flutter/material.dart';

import '../../../../../core/theme/spacing.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../domain/entities/ad_link.dart';

/// Valid property-type keys for the `category` link kind (R-179).
const _kPropertyTypeKeys = <String>[
  'apartment',
  'villa',
  'land',
  'shop',
  'office',
  'farm',
  'warehouse',
  'other',
];

/// UUID v4 pattern — used for listing / agency link value validation.
final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Validates a link value per R-179.
///
/// Returns null on valid, or a localized error message key for the caller to
/// resolve. This function is intentionally pure (no l10n dependency) so it
/// can be called from a [FormField] validator.
String? validateLinkValue(AdLinkKind kind, String value) {
  if (value.trim().isEmpty) return 'adLinkValueRequired';
  return switch (kind) {
    AdLinkKind.external => _validateUrl(value),
    AdLinkKind.listing || AdLinkKind.agency => _validateUuid(value),
    AdLinkKind.category => _validateCategoryKey(value),
    AdLinkKind.search => null, // any non-empty string is valid
  };
}

String? _validateUrl(String v) {
  final uri = Uri.tryParse(v.trim());
  if (uri == null || !uri.hasScheme) return 'adLinkValueInvalidUrl';
  if (uri.scheme != 'http' && uri.scheme != 'https') return 'adLinkValueInvalidUrl';
  return null;
}

String? _validateUuid(String v) {
  if (!_uuidPattern.hasMatch(v.trim())) return 'adLinkValueInvalidUuid';
  return null;
}

String? _validateCategoryKey(String v) {
  if (!_kPropertyTypeKeys.contains(v.trim())) return 'adLinkValueInvalidCategoryKey';
  return null;
}

/// A form widget that combines a [DropdownButtonFormField] for [AdLinkKind]
/// with a [TextFormField] for the link value, validated per R-179.
class LinkTargetPicker extends StatefulWidget {
  const LinkTargetPicker({
    super.key,
    required this.initialKind,
    required this.initialValue,
    required this.onChanged,
  });

  final AdLinkKind initialKind;
  final String initialValue;

  /// Called whenever kind or value changes with the new (kind, value) pair.
  final void Function(AdLinkKind kind, String value) onChanged;

  @override
  State<LinkTargetPicker> createState() => _LinkTargetPickerState();
}

class _LinkTargetPickerState extends State<LinkTargetPicker> {
  late AdLinkKind _kind;
  late final TextEditingController _valueController;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    _valueController = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  void _notifyChanged() =>
      widget.onChanged(_kind, _valueController.text);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.adsAdminLinkLabel, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<AdLinkKind>(
          initialValue: _kind,
          decoration: InputDecoration(labelText: l10n.adLinkKindLabel),
          items: AdLinkKind.values.map((k) {
            return DropdownMenuItem(
              value: k,
              child: Text(_kindLabel(l10n, k)),
            );
          }).toList(),
          onChanged: (k) {
            if (k == null) return;
            setState(() {
              _kind = k;
              _valueController.clear();
            });
            _notifyChanged();
          },
        ),
        const SizedBox(height: AppSpacing.md),
        // For `category` kind — show a dropdown of valid property-type keys.
        if (_kind == AdLinkKind.category)
          DropdownButtonFormField<String>(
            initialValue: _kPropertyTypeKeys.contains(_valueController.text)
                ? _valueController.text
                : null,
            decoration: InputDecoration(labelText: _valueHint(l10n, _kind)),
            items: _kPropertyTypeKeys
                .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                .toList(),
            validator: (_) {
              final err = validateLinkValue(_kind, _valueController.text);
              return err == null ? null : _resolveValidationError(l10n, err);
            },
            onChanged: (v) {
              if (v == null) return;
              _valueController.text = v;
              _notifyChanged();
            },
          )
        else
          TextFormField(
            controller: _valueController,
            decoration: InputDecoration(labelText: _valueHint(l10n, _kind)),
            keyboardType: _kind == AdLinkKind.external
                ? TextInputType.url
                : TextInputType.text,
            validator: (v) {
              final err = validateLinkValue(_kind, v ?? '');
              return err == null ? null : _resolveValidationError(l10n, err);
            },
            onChanged: (_) => _notifyChanged(),
          ),
      ],
    );
  }

  String _kindLabel(AppLocalizations l10n, AdLinkKind kind) {
    return switch (kind) {
      AdLinkKind.external => l10n.adLinkKindExternal,
      AdLinkKind.listing => l10n.adLinkKindListing,
      AdLinkKind.agency => l10n.adLinkKindAgency,
      AdLinkKind.category => l10n.adLinkKindCategory,
      AdLinkKind.search => l10n.adLinkKindSearch,
    };
  }

  String _valueHint(AppLocalizations l10n, AdLinkKind kind) {
    return switch (kind) {
      AdLinkKind.external => l10n.adLinkValueHintUrl,
      AdLinkKind.listing => l10n.adLinkValueHintUuid,
      AdLinkKind.agency => l10n.adLinkValueHintUuid,
      AdLinkKind.category => l10n.adLinkValueHintCategoryKey,
      AdLinkKind.search => l10n.adLinkValueHintSearch,
    };
  }

  String _resolveValidationError(AppLocalizations l10n, String key) {
    return switch (key) {
      'adLinkValueRequired' => l10n.adLinkValueRequired,
      'adLinkValueInvalidUrl' => l10n.adLinkValueInvalidUrl,
      'adLinkValueInvalidUuid' => l10n.adLinkValueInvalidUuid,
      'adLinkValueInvalidCategoryKey' => l10n.adLinkValueInvalidCategoryKey,
      _ => l10n.errorGeneric,
    };
  }
}
