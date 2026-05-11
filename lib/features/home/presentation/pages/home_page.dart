import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

/// Placeholder home page (Phase 5 T041).
///
/// Renders the user's full name and a sign-out affordance.
/// US2 (T079) appends the Profile tile; US4 (T072) appends the Admin tile.
/// Both slots live in [_buildTiles] so parallel edits touch disjoint lines.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final profile = switch (state) {
          Authenticated(:final profile) => profile,
          _ => null,
        };
        final displayName = profile?.fullName ?? profile?.username ?? '—';

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.home_title),
            actions: [
              TextButton(
                onPressed: () =>
                    context.read<AuthBloc>().add(const LogoutRequested()),
                child: Text(l10n.sign_out),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.home_signed_in_as(displayName),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                // US2 (T079) inserts Profile tile here.
                // US4 (T072) inserts Admin tile here (only when profile.isAdmin).
              ],
            ),
          ),
        );
      },
    );
  }
}
