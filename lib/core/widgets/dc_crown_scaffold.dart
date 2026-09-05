import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '_widget_support.dart';

/// The DC "Blue Crown" scaffold shared by the app's tab and pushed screens
/// (`AlNujom.dc.html`): a brand-blue header carrying an optional back button, a
/// bold white title, and trailing actions, above a white sheet whose rounded
/// top corners reveal the blue crown behind them.
///
/// Screens that need a bespoke crown (Home, Search) build their own; this covers
/// the straightforward title-over-list screens (Saved, Messages, Account,
/// Notifications, Edit profile, …) so they stay consistent without duplication.
class DcCrownScaffold extends StatelessWidget {
  const DcCrownScaffold({
    required this.title,
    required this.body,
    this.titleWidget,
    this.leading,
    this.actions,
    this.crownBottom,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.drawer,
    this.sheet = true,
    this.dense = false,
    super.key,
  });

  final String title;
  final Widget body;

  /// A bespoke crown title block (e.g. a two-line identity row with an avatar).
  /// When provided it replaces the plain [title] Text; [title] is still required
  /// for the accessibility label / fallback.
  final Widget? titleWidget;

  /// Leading action (typically a [DcCrownIconButton] back button). Null on tab
  /// roots.
  final Widget? leading;

  /// Trailing crown actions.
  final List<Widget>? actions;

  /// An extra widget under the title row inside the crown (e.g. tabs).
  final Widget? crownBottom;

  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final Widget? drawer;

  /// Wrap [body] in the white rounded sheet (true) or let it own the surface
  /// (false — e.g. a screen that paints its own header inside the sheet).
  final bool sheet;

  /// Pushed screens use a smaller (17px) title; tab roots use 20px.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final topInset = MediaQuery.paddingOf(context).top;

    final titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: (dense ? styles.titleMedium : styles.titleLarge).copyWith(
        color: colors.onBrandHeader,
        fontWeight: FontWeight.w700,
      ),
    );

    return Scaffold(
      backgroundColor: colors.brandHeader,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      drawer: drawer,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: colors.brandHeader,
            padding: EdgeInsetsDirectional.only(
              top: topInset + AppSpacing.sm,
              start: AppSpacing.sm,
              end: AppSpacing.sm,
              bottom: crownBottom == null ? AppSpacing.lg : AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    Expanded(
                      child: titleWidget != null
                          ? titleWidget!
                          : (leading == null
                                ? Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      start: AppSpacing.sm,
                                    ),
                                    child: titleText,
                                  )
                                : titleText),
                    ),
                    if (actions != null) ...actions!,
                  ],
                ),
                if (crownBottom != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  crownBottom!,
                ],
              ],
            ),
          ),
          Expanded(
            child: sheet
                ? Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: const BorderRadiusDirectional.vertical(
                        top: Radius.circular(AppRadii.sheet),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: body,
                  )
                : body,
          ),
        ],
      ),
    );
  }
}

/// A 42px circular white-icon action button for the DC crown.
class DcCrownIconButton extends StatelessWidget {
  const DcCrownIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // Plan A37 — sixty-odd crown buttons are the back arrow and none carried
    // a label, so TalkBack read "button". The arrow gets one here, once; any
    // other icon says what it does through [tooltip].
    final isBack = icon == Icons.arrow_forward || icon == Icons.arrow_back;
    final label =
        tooltip ?? (isBack ? AppStrings.of(context).loc.a11yBack : null);
    final button = InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 42,
        height: 42,
        child: Icon(icon, size: 24, color: colors.onBrandHeader),
      ),
    );
    final labelled = label == null
        ? button
        : Semantics(
            button: true,
            label: label,
            excludeSemantics: true,
            child: button,
          );
    return tooltip == null
        ? labelled
        : Tooltip(message: tooltip!, child: labelled);
  }
}

/// A small white-text crown action button (e.g. "تعليم الكل كمقروء").
class DcCrownTextButton extends StatelessWidget {
  const DcCrownTextButton({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: appRadius(AppRadii.sm),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Text(
          label,
          style: styles.labelMedium.copyWith(
            color: colors.onBrandHeader,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
