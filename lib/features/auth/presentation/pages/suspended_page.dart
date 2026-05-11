import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';

class SuspendedPage extends StatelessWidget {
  const SuspendedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.suspended_title),
        actions: [
          TextButton(
            onPressed: () =>
                context.read<AuthBloc>().add(const LogoutRequested()),
            child: Text(l10n.sign_out),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            l10n.suspended_body,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
