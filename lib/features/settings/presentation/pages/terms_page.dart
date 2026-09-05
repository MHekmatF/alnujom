// Plan A27 — the terms of service, readable inside the app.
//
// The document is the markdown under docs/legal/ (Arabic is the authority,
// English a translation), bundled as an asset so it opens with no network and
// before any web page exists. The renderer below understands exactly the
// subset those files use — headings, paragraphs, bullets, bold, links, rules —
// which is also the subset tool/build_privacy_site.py accepts, so the app and
// the website can never disagree on what a line means.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../l10n/app_localizations.dart';

String termsAssetFor(Locale locale) => locale.languageCode == 'en'
    ? 'docs/legal/terms-of-service.en.md'
    : 'docs/legal/terms-of-service.md';

class TermsPage extends StatefulWidget {
  const TermsPage({super.key});

  @override
  State<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> {
  Future<String>? _load;
  Locale? _loadedFor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    if (_loadedFor != locale) {
      _loadedFor = locale;
      _load = rootBundle.loadString(termsAssetFor(locale));
    }
    return DcCrownScaffold(
      title: l10n.terms_page_title,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () => Navigator.of(context).maybePop(),
      ),
      body: FutureBuilder<String>(
        future: _load,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorState(
              title: l10n.terms_page_load_failed,
              onRetry: () => setState(() => _loadedFor = null),
            );
          }
          final text = snapshot.data;
          if (text == null) return const Center(child: AppSpinner());
          return _MarkdownLite(text);
        },
      ),
    );
  }
}

/// Headings, paragraphs, bullets, rules, **bold** and [label](target) — the
/// legal documents' whole vocabulary. Anything else renders as plain text
/// rather than disappearing.
class _MarkdownLite extends StatelessWidget {
  const _MarkdownLite(this.source);

  final String source;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final blocks = <Widget>[];
    final lines = source.split('\n');
    var i = 0;
    while (i < lines.length) {
      final line = lines[i].trimRight();
      if (line.trim().isEmpty) {
        i++;
        continue;
      }
      if (line.startsWith('---') && line.replaceAll('-', '').isEmpty) {
        blocks.add(
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: AppSpacing.md,
            ),
            child: Divider(color: colors.divider, height: 1),
          ),
        );
        i++;
        continue;
      }
      final heading = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(line);
      if (heading != null) {
        final level = heading.group(1)!.length;
        final style = switch (level) {
          1 => styles.headlineMedium,
          2 => styles.titleLarge,
          _ => styles.titleMedium,
        };
        blocks.add(
          Padding(
            padding: level == 1
                ? const EdgeInsetsDirectional.only(
                    top: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                  )
                : const EdgeInsetsDirectional.only(
                    top: AppSpacing.xl,
                    bottom: AppSpacing.sm,
                  ),
            child: Text(heading.group(2)!, style: style),
          ),
        );
        i++;
        continue;
      }
      if (line.trimLeft().startsWith('- ')) {
        final items = <Widget>[];
        while (i < lines.length && lines[i].trimLeft().startsWith('- ')) {
          items.add(
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A drawn dot, not a spelled one: the l10n-literal lint
                  // treats any string handed to Text() as untranslated copy.
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: AppSpacing.sm,
                    ),
                    child: Icon(
                      Icons.circle,
                      size: AppSpacing.xs,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _inline(
                      lines[i].trimLeft().substring(2).trim(),
                      styles.bodyLarge,
                      colors,
                    ),
                  ),
                ],
              ),
            ),
          );
          i++;
        }
        blocks.add(
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items,
            ),
          ),
        );
        continue;
      }
      // Paragraph: consecutive non-blank, non-structural lines.
      final para = <String>[];
      while (i < lines.length &&
          lines[i].trim().isNotEmpty &&
          !lines[i].startsWith('#') &&
          !lines[i].trimLeft().startsWith('- ') &&
          !(lines[i].startsWith('---') &&
              lines[i].trim().replaceAll('-', '').isEmpty)) {
        para.add(lines[i].trim());
        i++;
      }
      blocks.add(
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
          child: _inline(para.join(' '), styles.bodyLarge, colors),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: blocks,
    );
  }

  /// **bold** → bold span; [label](target) → the label; `code` → plain.
  Widget _inline(String text, TextStyle base, AppColors colors) {
    final cleaned = text
        .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m.group(1)!)
        .replaceAll('`', '');
    final spans = <TextSpan>[];
    var bold = false;
    for (final part in cleaned.split('**')) {
      if (part.isNotEmpty) {
        spans.add(
          TextSpan(
            text: part,
            style: bold ? base.copyWith(fontWeight: FontWeight.w700) : base,
          ),
        );
      }
      bold = !bold;
    }
    return Text.rich(
      TextSpan(children: spans),
      style: base.copyWith(color: colors.onSurface),
    );
  }
}
