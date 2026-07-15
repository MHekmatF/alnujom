import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../l10n/app_localizations.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../widgets/auth_status_message.dart';

class SuspendedPage extends StatelessWidget {
  const SuspendedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DcCrownScaffold(
      title: l10n.suspended_title,
      dense: true,
      body: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: AuthStatusMessage(
          icon: LucideIcons.ban,
          tone: AuthStatusTone.warning,
          title: l10n.suspended_title,
          message: l10n.suspended_body,
          action: AppButton(
            label: l10n.sign_out,
            variant: AppButtonVariant.outlined,
            onPressed: () =>
                context.read<AuthBloc>().add(const LogoutRequested()),
          ),
        ),
      ),
    );
  }
}
