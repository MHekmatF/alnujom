import 'dart:math';

import 'package:alnujom/core/theme/color_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// WCAG AA thresholds
const double _bodyMinRatio = 4.5;
const double _uiMinRatio = 3.0;

void main() {
  group('Color scheme WCAG AA contrast floor', () {
    for (final (label, palette, brightness) in _combinations) {
      group(label, () {
        final tokens = palette.tokens(brightness);
        final scheme = palette.scheme(brightness);

        _bodyPair('onPrimary on primary', tokens.onPrimary, tokens.primary);
        _bodyPair(
          'onSecondary on secondary',
          tokens.onSecondary,
          tokens.secondary,
        );
        _bodyPair('onSurface on surface', tokens.onSurface, tokens.surface);
        _bodyPair(
          'onPrimaryContainer on primaryContainer',
          tokens.onPrimaryContainer,
          tokens.primaryContainer,
        );
        _bodyPair(
          'onSurfaceVariant on surface',
          tokens.onSurfaceVariant,
          tokens.surface,
        );

        _uiPair(
          'primary on surface (UI element)',
          tokens.primary,
          tokens.surface,
        );
        _uiPair(
          'error on surface (error indicator)',
          tokens.error,
          tokens.surface,
        );

        // Material ColorScheme slots should also respect the floor
        _bodyPair(
          'scheme.onPrimary on scheme.primary',
          scheme.onPrimary,
          scheme.primary,
        );
        _bodyPair(
          'scheme.onSurface on scheme.surface',
          scheme.onSurface,
          scheme.surface,
        );
      });
    }
  });
}

const _combinations = [
  ('ModernPalette light', ModernPalette(), Brightness.light),
  ('ModernPalette dark', ModernPalette(), Brightness.dark),
  ('TrustPalette light', TrustPalette(), Brightness.light),
  ('TrustPalette dark', TrustPalette(), Brightness.dark),
];

void _bodyPair(String label, Color foreground, Color background) {
  test('$label ≥ 4.5:1', () {
    final ratio = contrastRatio(foreground, background);
    expect(
      ratio,
      greaterThanOrEqualTo(_bodyMinRatio),
      reason:
          '$label ratio was ${ratio.toStringAsFixed(2)}:1 '
          '(fg=$foreground, bg=$background)',
    );
  });
}

void _uiPair(String label, Color foreground, Color background) {
  test('$label ≥ 3.0:1', () {
    final ratio = contrastRatio(foreground, background);
    expect(
      ratio,
      greaterThanOrEqualTo(_uiMinRatio),
      reason:
          '$label ratio was ${ratio.toStringAsFixed(2)}:1 '
          '(fg=$foreground, bg=$background)',
    );
  });
}

double contrastRatio(Color foreground, Color background) {
  final l1 = _relativeLuminance(foreground);
  final l2 = _relativeLuminance(background);
  final lighter = max(l1, l2);
  final darker = min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

double _relativeLuminance(Color color) {
  final r = _linearize(color.r);
  final g = _linearize(color.g);
  final b = _linearize(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _linearize(double channel) {
  return channel <= 0.04045
      ? channel / 12.92
      : pow((channel + 0.055) / 1.055, 2.4).toDouble();
}
