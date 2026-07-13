import 'package:alnujom/core/theme/color_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModernPalette light tokens', () {
    final tokens = const ModernPalette().lightTokens();

    test('primary', () => expect(tokens.primary, const Color(0xFF1F4FE6)));
    test('onPrimary', () => expect(tokens.onPrimary, const Color(0xFFFFFFFF)));
    test(
      'primaryContainer',
      () => expect(tokens.primaryContainer, const Color(0xFFE2E9FF)),
    );
    test(
      'onPrimaryContainer',
      () => expect(tokens.onPrimaryContainer, const Color(0xFF123287)),
    );
    test('accent', () => expect(tokens.accent, const Color(0xFFFF5B6E)));
    test('onAccent', () => expect(tokens.onAccent, const Color(0xFFFFFFFF)));
    test(
      'accentContainer',
      () => expect(tokens.accentContainer, const Color(0xFFFFE1E6)),
    );
    test('secondary', () => expect(tokens.secondary, const Color(0xFF0F172A)));
    test(
      'onSecondary',
      () => expect(tokens.onSecondary, const Color(0xFFFFFFFF)),
    );
    test('tertiary', () => expect(tokens.tertiary, const Color(0xFF8A6912)));
    test('success', () => expect(tokens.success, const Color(0xFF0E7A3C)));
    test('warning', () => expect(tokens.warning, const Color(0xFFC98318)));
    test('error', () => expect(tokens.error, const Color(0xFFD93B3B)));
    test('surface', () => expect(tokens.surface, const Color(0xFFEAEDF2)));
    test(
      'surfaceVariant',
      () => expect(tokens.surfaceVariant, const Color(0xFFF2F4F9)),
    );
    test('card', () => expect(tokens.card, const Color(0xFFFFFFFF)));
    test('outline', () => expect(tokens.outline, const Color(0xFFE7EAF1)));
    test(
      'outlineStrong',
      () => expect(tokens.outlineStrong, const Color(0xFFC6CAD6)),
    );
    test('onSurface', () => expect(tokens.onSurface, const Color(0xFF1A1C22)));
    test(
      'onSurfaceVariant',
      () => expect(tokens.onSurfaceVariant, const Color(0xFF5B6070)),
    );
    test('textMuted', () => expect(tokens.textMuted, const Color(0xFF5B6070)));
    test('verified', () => expect(tokens.verified, const Color(0xFF0E7A3C)));
    test(
      'verifiedContainer',
      () => expect(tokens.verifiedContainer, const Color(0xFFE4F3E9)),
    );

    test('lightScheme().primary matches token', () {
      expect(const ModernPalette().lightScheme().primary, tokens.primary);
    });
  });

  group('ModernPalette dark tokens', () {
    final tokens = const ModernPalette().darkTokens();

    test('primary', () => expect(tokens.primary, const Color(0xFFAEC2FF)));
    test('onPrimary', () => expect(tokens.onPrimary, const Color(0xFF0A2063)));
    test(
      'primaryContainer',
      () => expect(tokens.primaryContainer, const Color(0xFF26356E)),
    );
    test(
      'onPrimaryContainer',
      () => expect(tokens.onPrimaryContainer, const Color(0xFFDCE4FF)),
    );
    test('accent', () => expect(tokens.accent, const Color(0xFFFF5B6E)));
    test('onAccent', () => expect(tokens.onAccent, const Color(0xFFFFFFFF)));
    test(
      'accentContainer',
      () => expect(tokens.accentContainer, const Color(0xFF4A1420)),
    );
    test('secondary', () => expect(tokens.secondary, const Color(0xFFE7E8ED)));
    test(
      'onSecondary',
      () => expect(tokens.onSecondary, const Color(0xFF0B1220)),
    );
    test('tertiary', () => expect(tokens.tertiary, const Color(0xFFE6C56A)));
    test('success', () => expect(tokens.success, const Color(0xFF74D99A)));
    test('warning', () => expect(tokens.warning, const Color(0xFFE2B25A)));
    test('error', () => expect(tokens.error, const Color(0xFFFF6B6B)));
    test('surface', () => expect(tokens.surface, const Color(0xFF0C0C10)));
    test(
      'surfaceVariant',
      () => expect(tokens.surfaceVariant, const Color(0xFF1C1D25)),
    );
    test('card', () => expect(tokens.card, const Color(0xFF131318)));
    test('outline', () => expect(tokens.outline, const Color(0xFF26272F)));
    test(
      'outlineStrong',
      () => expect(tokens.outlineStrong, const Color(0xFF3B3D48)),
    );
    test('onSurface', () => expect(tokens.onSurface, const Color(0xFFE7E8ED)));
    test(
      'onSurfaceVariant',
      () => expect(tokens.onSurfaceVariant, const Color(0xFFA7ABB8)),
    );
    test('textMuted', () => expect(tokens.textMuted, const Color(0xFFA7ABB8)));
    test('verified', () => expect(tokens.verified, const Color(0xFF74D99A)));
    test(
      'verifiedContainer',
      () => expect(tokens.verifiedContainer, const Color(0xFF12331F)),
    );

    test('darkScheme().primary matches token', () {
      expect(const ModernPalette().darkScheme().primary, tokens.primary);
    });
  });

  group('TrustPalette light tokens', () {
    final tokens = const TrustPalette().lightTokens();

    test('primary', () => expect(tokens.primary, const Color(0xFF2457A6)));
    test('onPrimary', () => expect(tokens.onPrimary, const Color(0xFFFFFFFF)));
    test(
      'primaryContainer',
      () => expect(tokens.primaryContainer, const Color(0xFFD9E5FF)),
    );
    test(
      'onPrimaryContainer',
      () => expect(tokens.onPrimaryContainer, const Color(0xFF001A41)),
    );
    test('accent', () => expect(tokens.accent, const Color(0xFF00897B)));
    test('onAccent', () => expect(tokens.onAccent, const Color(0xFFFFFFFF)));
    test(
      'accentContainer',
      () => expect(tokens.accentContainer, const Color(0xFFCCE8E4)),
    );
    test('secondary', () => expect(tokens.secondary, const Color(0xFF0F172A)));
    test(
      'onSecondary',
      () => expect(tokens.onSecondary, const Color(0xFFFFFFFF)),
    );
    test('tertiary', () => expect(tokens.tertiary, const Color(0xFFF57C00)));
    test('success', () => expect(tokens.success, const Color(0xFF16A34A)));
    test('warning', () => expect(tokens.warning, const Color(0xFFF59E0B)));
    test('error', () => expect(tokens.error, const Color(0xFFDC2626)));
    test('surface', () => expect(tokens.surface, const Color(0xFFF8FAFC)));
    test(
      'surfaceVariant',
      () => expect(tokens.surfaceVariant, const Color(0xFFE1E5EE)),
    );
    test('card', () => expect(tokens.card, const Color(0xFFFFFFFF)));
    test('outline', () => expect(tokens.outline, const Color(0xFFE2E8F0)));
    test(
      'outlineStrong',
      () => expect(tokens.outlineStrong, const Color(0xFF74777F)),
    );
    test('onSurface', () => expect(tokens.onSurface, const Color(0xFF111827)));
    test(
      'onSurfaceVariant',
      () => expect(tokens.onSurfaceVariant, const Color(0xFF64748B)),
    );
    test('textMuted', () => expect(tokens.textMuted, const Color(0xFF94A3B8)));
    test('verified', () => expect(tokens.verified, const Color(0xFF1F7A4D)));
    test(
      'verifiedContainer',
      () => expect(tokens.verifiedContainer, const Color(0xFFDCF0E5)),
    );

    test('lightScheme().primary matches token', () {
      expect(const TrustPalette().lightScheme().primary, tokens.primary);
    });
  });

  group('TrustPalette dark tokens', () {
    final tokens = const TrustPalette().darkTokens();

    test('primary', () => expect(tokens.primary, const Color(0xFF9FC5FF)));
    test('onPrimary', () => expect(tokens.onPrimary, const Color(0xFF002C72)));
    test(
      'primaryContainer',
      () => expect(tokens.primaryContainer, const Color(0xFF1F4488)),
    );
    test(
      'onPrimaryContainer',
      () => expect(tokens.onPrimaryContainer, const Color(0xFFD9E5FF)),
    );
    test('accent', () => expect(tokens.accent, const Color(0xFF4DB6AC)));
    test('onAccent', () => expect(tokens.onAccent, const Color(0xFF04231F)));
    test(
      'accentContainer',
      () => expect(tokens.accentContainer, const Color(0xFF134E48)),
    );
    test('secondary', () => expect(tokens.secondary, const Color(0xFFE2E8F0)));
    test(
      'onSecondary',
      () => expect(tokens.onSecondary, const Color(0xFF0B1220)),
    );
    test('tertiary', () => expect(tokens.tertiary, const Color(0xFFFFB74D)));
    test('success', () => expect(tokens.success, const Color(0xFF22C55E)));
    test('warning', () => expect(tokens.warning, const Color(0xFFFBBF24)));
    test('error', () => expect(tokens.error, const Color(0xFFF87171)));
    test('surface', () => expect(tokens.surface, const Color(0xFF0B1220)));
    test(
      'surfaceVariant',
      () => expect(tokens.surfaceVariant, const Color(0xFF3E4856)),
    );
    test('card', () => expect(tokens.card, const Color(0xFF0F172A)));
    test('outline', () => expect(tokens.outline, const Color(0xFF1E293B)));
    test(
      'outlineStrong',
      () => expect(tokens.outlineStrong, const Color(0xFF8E9099)),
    );
    test('onSurface', () => expect(tokens.onSurface, const Color(0xFFF8FAFC)));
    test(
      'onSurfaceVariant',
      () => expect(tokens.onSurfaceVariant, const Color(0xFF94A3B8)),
    );
    test('textMuted', () => expect(tokens.textMuted, const Color(0xFF64748B)));
    test('verified', () => expect(tokens.verified, const Color(0xFF57C48C)));
    test(
      'verifiedContainer',
      () => expect(tokens.verifiedContainer, const Color(0xFF163A2A)),
    );

    test('darkScheme().primary matches token', () {
      expect(const TrustPalette().darkScheme().primary, tokens.primary);
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
