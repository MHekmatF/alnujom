import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:panorama_viewer/panorama_viewer.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/glass_pill.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../features/listing_form/domain/entities/listing_media.dart';
import '../../data/panorama_tour_url_resolver.dart';

/// Spec 026 (growth-features) — full-screen 360°/virtual-tour viewer.
///
/// Loads an equirectangular image into a [PanoramaViewer] so the buyer can
/// pan/look around the property. The image is the panorama [ListingMedia] row's
/// storage object (an equirectangular still in the `listing-images` bucket,
/// `kind='panorama'`); its public URL is resolved by the data layer
/// ([PanoramaTourUrlResolver]) so this presentation page imports zero
/// `package:supabase_flutter` (FR-030 / Constitution IX boundary).
///
/// Chrome is token-only: a dark photo scrim background, a frosted [GlassPill]
/// title, and a frosted close button — all drawn from the design-token system so
/// the surface reads correctly over imagery in light + dark and Arabic + English.
///
/// Reached via `Navigator.push(MaterialPageRoute(...))` from the listing-details
/// gallery — no new go_router route.
class PanoramaTourPage extends StatelessWidget {
  /// Builds the page from a panorama [ListingMedia] row, resolving its storage
  /// path to a public URL via the data layer. Falls back to an error glyph when
  /// the row has no resolvable URL.
  PanoramaTourPage.fromMedia(ListingMedia media, {super.key})
    : imageUrl = PanoramaTourUrlResolver.resolve(media);

  /// Builds the page from an already-resolved public image URL.
  const PanoramaTourPage.fromUrl({required this.imageUrl, super.key});

  /// The resolved equirectangular image URL, or null when unresolvable.
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      // A dark photo scrim so the panorama reads as an immersive surface in
      // both themes (the viewer paints over it edge-to-edge).
      backgroundColor: colors.scrim,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null && imageUrl!.isNotEmpty)
            PanoramaViewer(
              // A gentle idle auto-rotation invites interaction; the buyer can
              // grab and drag at any time (interactive defaults to true).
              animSpeed: 0.3,
              child: Image(image: CachedNetworkImageProvider(imageUrl!)),
            )
          else
            Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: colors.onPhoto,
                size: AppSpacing.xxxl,
              ),
            ),
          // Top chrome: a "360°" title pill at the start, a close button at the
          // end. SafeArea keeps both clear of the status bar / notch.
          SafeArea(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              child: Row(
                children: [
                  GlassPill(label: l10n.panoramaTourTitle, icon: Icons.threesixty),
                  const Spacer(),
                  _CloseButton(
                    label: l10n.panoramaTourClose,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A frosted, tappable close affordance drawn from the photo-overlay tokens so
/// it lifts off busy imagery in either theme.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: colors.photoOverlay,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsetsDirectional.all(AppSpacing.sm),
            child: _CloseGlyph(),
          ),
        ),
      ),
    );
  }
}

class _CloseGlyph extends StatelessWidget {
  const _CloseGlyph();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Icon(Icons.close, size: AppSpacing.lg, color: colors.onPhoto);
  }
}
