import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';

class BilingualDisplayNameField extends StatefulWidget {
  const BilingualDisplayNameField({
    super.key,
    this.initialArabic,
    this.initialEnglish,
    required this.onChanged,
  });

  final String? initialArabic;
  final String? initialEnglish;
  final void Function(({String? arabic, String? english}) value) onChanged;

  @override
  State<BilingualDisplayNameField> createState() =>
      _BilingualDisplayNameFieldState();
}

class _BilingualDisplayNameFieldState
    extends State<BilingualDisplayNameField> {
  late final TextEditingController _arController;
  late final TextEditingController _enController;

  @override
  void initState() {
    super.initState();
    _arController = TextEditingController(text: widget.initialArabic ?? '');
    _enController = TextEditingController(text: widget.initialEnglish ?? '');
  }

  @override
  void dispose() {
    _arController.dispose();
    _enController.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged((
      arabic: _arController.text.trim().isEmpty ? null : _arController.text,
      english: _enController.text.trim().isEmpty ? null : _enController.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Directionality(
          textDirection: TextDirection.rtl,
          child: TextFormField(
            controller: _arController,
            decoration: InputDecoration(labelText: l10n.displayNameArabicLabel),
            onChanged: (_) => _notify(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.arabicNameRequired;
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextFormField(
            controller: _enController,
            decoration: InputDecoration(labelText: l10n.displayNameEnglishLabel),
            onChanged: (_) => _notify(),
          ),
        ),
      ],
    );
  }
}
