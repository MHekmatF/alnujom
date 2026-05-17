import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../localization/locale_cubit.dart';
import '../localization/app_strings.dart';

class LocaleToggleAction extends StatelessWidget {
  const LocaleToggleAction({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context).loc;
    final locale = context.watch<LocaleCubit>().state;
    return IconButton(
      tooltip: '${l10n.localeToggleLabel} (${locale.languageCode})',
      icon: const Icon(Icons.language_outlined),
      onPressed: () => unawaited(context.read<LocaleCubit>().toggle()),
    );
  }
}
