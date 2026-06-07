import 'package:flutter/material.dart';

/// The AlNujom app emblem (brand mark) shown on the auth surfaces
/// (login / register / reset-password) in place of the painted [BrandMark].
///
/// Renders the tightly-trimmed transparent logo directly — no white tile, no
/// rounded badge, no shadow, no clip — so it sits on whatever surface hosts it.
/// The artwork is `assets/branding/logo_full.png`: the full brand composition
/// (N emblem + النجوم wordmark + English line) cropped tight to its content, so
/// it fills the allotted width and reads large instead of floating inside the
/// splash image's wide transparent margins. A logo is not mirrored for RTL —
/// the composition is fixed in both directions.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 200});

  /// The rendered width of the logo, in logical pixels. Height follows the
  /// artwork's natural aspect ratio (the mark is taller than it is wide).
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'النجوم',
      image: true,
      child: Image.asset(
        'assets/branding/logo_full.png',
        width: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
