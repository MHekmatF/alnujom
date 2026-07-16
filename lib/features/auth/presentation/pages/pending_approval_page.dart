import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../l10n/app_localizations.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../widgets/auth_status_message.dart';

class PendingApprovalPage extends StatelessWidget {
  const PendingApprovalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DcCrownScaffold(
      title: l10n.pending_approval_title,
      dense: true,
      actions: [
        DcCrownTextButton(
          label: l10n.sign_out,
          onTap: () => context.read<AuthBloc>().add(const LogoutRequested()),
        ),
      ],
      body: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: AuthStatusMessage(
          icon: LucideIcons.clock,
          title: l10n.pending_approval_title,
          message: l10n.pending_approval_body,
        ),
      ),
    );
  }
}
