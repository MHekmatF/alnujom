import 'package:alnujom/core/theme/color_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModernPalette light', () {
    final tokens = const ModernPalette().lightTokens();

    test('primary is #1D4ED8', () => expect(tokens.primary, const Color(0xFF1D4ED8)));
    test('onPrimary is white', () => expect(tokens.onPrimary, const Color(0xFFFFFFFF)));
    test('primaryContainer', () => expect(tokens.primaryContainer, const Color(0xFFDBEAFE)));
    test('onPrimaryContainer', () => expect(tokens.onPrimaryContainer, const Color(0xFF0B2354)));
    test('secondary', () => expect(tokens.secondary, const Color(0xFF0F172A)));
    test('onSecondary', () => expect(tokens.onSecondary, const Color(0xFFFFFFFF)));
    test('error', () => expect(tokens.error, const Color(0xFFDC2626)));
    test('surface', () => expect(tokens.surface, const Color(0xFFF8FAFC)));
    test('onSurface', () => expect(tokens.onSurface, const Color(0xFF111827)));
    test('outline', () => expect(tokens.outline, const Color(0xFFE2E8F0)));

    test('lightScheme().primary matches token', () {
      expect(
        const ModernPalette().lightScheme().primary,
        const Color(0xFF1D4ED8),
      );
    });
  });

  group('ModernPalette dark', () {
    final tokens = const ModernPalette().darkTokens();

    test('primary is #60A5FA', () => expect(tokens.primary, const Color(0xFF60A5FA)));
    test('onPrimary', () => expect(tokens.onPrimary, const Color(0xFF0B1220)));
    test('primaryContainer', () => expect(tokens.primaryContainer, const Color(0xFF1E3A8A)));
    test('surface', () => expect(tokens.surface, const Color(0xFF0B1220)));
    test('onSurface', () => expect(tokens.onSurface, const Color(0xFFF8FAFC)));

    test('darkScheme().primary matches token', () {
      expect(
        const ModernPalette().darkScheme().primary,
        const Color(0xFF60A5FA),
      );
    });
  });

  group('TrustPalette light', () {
    final tokens = const TrustPalette().lightTokens();

    test('primary is #2457A6', () => expect(tokens.primary, const Color(0xFF2457A6)));
    test('onPrimary is white', () => expect(tokens.onPrimary, const Color(0xFFFFFFFF)));
    test('primaryContainer', () => expect(tokens.primaryContainer, const Color(0xFFD9E5FF)));
    test('onPrimaryContainer', () => expect(tokens.onPrimaryContainer, const Color(0xFF001A41)));
    test('error', () => expect(tokens.error, const Color(0xFFDC2626)));
    test('surface', () => expect(tokens.surface, const Color(0xFFF8FAFC)));
    test('onSurface', () => expect(tokens.onSurface, const Color(0xFF111827)));

    test('lightScheme().primary matches token', () {
      expect(
        const TrustPalette().lightScheme().primary,
        const Color(0xFF2457A6),
      );
    });
  });

  group('TrustPalette dark', () {
    final tokens = const TrustPalette().darkTokens();

    test('primary is #9FC5FF', () => expect(tokens.primary, const Color(0xFF9FC5FF)));
    test('onPrimary', () => expect(tokens.onPrimary, const Color(0xFF002C72)));
    test('primaryContainer', () => expect(tokens.primaryContainer, const Color(0xFF1F4488)));
    test('surface', () => expect(tokens.surface, const Color(0xFF0B1220)));
    test('onSurface', () => expect(tokens.onSurface, const Color(0xFFF8FAFC)));

    test('darkScheme().primary matches token', () {
      expect(
        const TrustPalette().darkScheme().primary,
        const Color(0xFF9FC5FF),
      );
    });
  });

  group('ColorPalette.fromName', () {
    test('fromName trust returns TrustPalette', () {
      expect(ColorPalette.fromName('trust'), isA<TrustPalette>());
    });

    test('fromName modern returns ModernPalette', () {
      expect(ColorPalette.fromName('modern'), isA<ModernPalette>());
    });

    test('fromName unknown falls back to Modern', () {
      expect(ColorPalette.fromName('unknown'), isA<ModernPalette>());
    });
  });

  test('defaultPalette is ModernPalette', () {
    expect(ColorPalette.defaultPalette, isA<ModernPalette>());
  });
}
