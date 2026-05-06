import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../core/flags/app_flags.dart';
import '../core/theme/color_palette.dart';
import '../core/theme/colors.dart';
import '../core/theme/palette_cubit.dart';
import '../core/theme/radii.dart';
import '../core/theme/spacing.dart';
import '../core/theme/typography.dart';
import '../core/widgets/_widget_support.dart';

class PaletteTester extends StatelessWidget {
  const PaletteTester({
    super.key,
    this.designToolsEnabled = kDesignToolsEnabled,
  });

  static const chipKey = ValueKey<String>('palette-tester-chip');

  final bool designToolsEnabled;

  @override
  Widget build(BuildContext context) {
    if (!designToolsEnabled) return const SizedBox.shrink();

    return PositionedDirectional(
      top: AppSpacing.lg,
      start: AppSpacing.lg,
      child: SafeArea(
        child: BlocBuilder<PaletteCubit, ColorPalette>(
          builder: (context, palette) {
            final colors = AppColors.of(context);
            final styles = AppTextStyles.of(context);
            final name = _paletteLabel(palette);

            return Material(
              color: Colors.transparent,
              child: InkWell(
                key: chipKey,
                borderRadius: appRadius(AppRadii.pill),
                onTap: () => _cyclePalette(context),
                onLongPress: () => _showPaletteExplorer(context),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  height: AppSpacing.xxl,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: appRadius(AppRadii.pill),
                    border: Border.all(color: colors.outlineStrong),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: AppSpacing.md,
                        height: AppSpacing.md,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: appRadius(AppRadii.pill),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        name,
                        style: styles.labelMedium.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        LucideIcons.refresh_cw,
                        size: AppSpacing.lg,
                        color: colors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _cyclePalette(BuildContext context) async {
    final cubit = context.read<PaletteCubit>();
    await cubit.cycle();
    if (!context.mounted) return;

    final label = _paletteLabel(cubit.state);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(label)));
  }

  void _showPaletteExplorer(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const _PaletteExplorerPage(),
      ),
    );
  }
}

class _PaletteExplorerPage extends StatelessWidget {
  const _PaletteExplorerPage();

  @override
  Widget build(BuildContext context) {
    final activeColors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final palettes = [ColorPalette.defaultPalette, const TrustPalette()];

    return Scaffold(
      appBar: AppBar(title: const Text('Palette Explorer')),
      body: ListView(
        padding: appPadding(),
        children: [
          Text(
            'Compare token roles across palettes and brightness modes.',
            style: styles.bodyMedium.copyWith(color: activeColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final palette in palettes) ...[
            Text(_paletteLabel(palette), style: styles.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            _TokenGroup(palette: palette, brightness: Brightness.light),
            const SizedBox(height: AppSpacing.sm),
            _TokenGroup(palette: palette, brightness: Brightness.dark),
            const SizedBox(height: AppSpacing.xl),
          ],
        ],
      ),
    );
  }
}

class _TokenGroup extends StatelessWidget {
  const _TokenGroup({required this.palette, required this.brightness});

  final ColorPalette palette;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final tokens = palette.tokens(brightness);
    final styles = AppTextStyles.of(context);
    final colors = AppColors.of(context);
    final rows = <(String, Color)>[
      ('primary', tokens.primary),
      ('onPrimary', tokens.onPrimary),
      ('primaryContainer', tokens.primaryContainer),
      ('onPrimaryContainer', tokens.onPrimaryContainer),
      ('secondary', tokens.secondary),
      ('onSecondary', tokens.onSecondary),
      ('tertiary', tokens.tertiary),
      ('accent', tokens.accent),
      ('success', tokens.success),
      ('warning', tokens.warning),
      ('error', tokens.error),
      ('surface', tokens.surface),
      ('surfaceVariant', tokens.surfaceVariant),
      ('card', tokens.card),
      ('outline', tokens.outline),
      ('outlineStrong', tokens.outlineStrong),
      ('onSurface', tokens.onSurface),
      ('onSurfaceVariant', tokens.onSurfaceVariant),
      ('textMuted', tokens.textMuted),
    ];

    return AppSurface(
      padding: appPadding(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(brightness.name, style: styles.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          for (final row in rows)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Container(
                    width: AppSpacing.xl,
                    height: AppSpacing.xl,
                    decoration: BoxDecoration(
                      color: row.$2,
                      borderRadius: appRadius(AppRadii.sm),
                      border: Border.all(color: colors.outline),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(row.$1, style: styles.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _paletteLabel(ColorPalette palette) => switch (palette) {
  TrustPalette() => 'Trust',
  _ => 'Modern',
};
