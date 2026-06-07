import 'package:flutter/material.dart';

/// The AlNujom app emblem (brand mark) shown on the auth surfaces
/// (login / register / reset-password) in place of the painted [BrandMark].
///
/// Renders the tightly-trimmed transparent emblem directly — no white tile, no
/// rounded badge, no shadow, no clip — so it sits on whatever surface hosts it.
/// The artwork is `assets/branding/logo_mark.png`: a trimmed, transparent
/// version of the launcher emblem, so the mark fills the box and reads larger
/// than the old badged composition. A logo is not mirrored for RTL — the
/// composition is fixed in both directions.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96});

  /// The edge length of the emblem box, in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'النجوم',
      image: true,
      child: Image.asset(
        'assets/branding/logo_mark.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
