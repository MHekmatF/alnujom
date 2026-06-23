import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../widgets/auth_status_message.dart';

class SuspendedPage extends StatelessWidget {
  const SuspendedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(l10n.suspended_title),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: colors.primary),
            onPressed: () =>
                context.read<AuthBloc>().add(const LogoutRequested()),
            child: Text(l10n.sign_out),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
          child: AuthStatusMessage(
            icon: LucideIcons.ban,
            tone: AuthStatusTone.warning,
            title: l10n.suspended_title,
            message: l10n.suspended_body,
          ),
        ),
      ),
    );
  }
}
