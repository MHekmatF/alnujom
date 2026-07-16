import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../l10n/app_localizations.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/auth_status_message.dart';

class RejectedPage extends StatelessWidget {
  const RejectedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DcCrownScaffold(
      title: l10n.rejected_title,
      dense: true,
      body: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final reason = state is Rejected ? state.reason : '';
            return AuthStatusMessage(
              icon: LucideIcons.circle_x,
              tone: AuthStatusTone.error,
              title: l10n.rejected_title,
              message: l10n.rejected_body_with_reason(reason),
              action: AppButton(
                label: l10n.sign_out,
                variant: AppButtonVariant.outlined,
                onPressed: () =>
                    context.read<AuthBloc>().add(const LogoutRequested()),
              ),
            );
          },
        ),
      ),
    );
  }
}
