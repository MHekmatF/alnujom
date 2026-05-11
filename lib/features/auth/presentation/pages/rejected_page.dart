import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class RejectedPage extends StatelessWidget {
  const RejectedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.rejected_title),
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
          child: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              final reason = state is Rejected ? state.reason : '';
              return Text(
                l10n.rejected_body_with_reason(reason),
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              );
            },
          ),
        ),
      ),
    );
  }
}
