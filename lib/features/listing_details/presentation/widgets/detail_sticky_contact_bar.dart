import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../features/inquiries/presentation/bloc/contact_cta_cubit.dart';
import '../../../../features/listing_form/domain/entities/listing.dart';
import '../../../../l10n/app_localizations.dart';
import 'contact_actions.dart';

/// The DC "Blue Crown" sticky contact bar pinned to the bottom of the listing
/// detail (`AlNujom.dc.html` §DETAIL): اتصال (tonal) · دردشة (outlined) · واتساب
/// (brand-green, wider). Reuses the shared [ContactActions] so it never
/// duplicates the launch/lead/chat logic the inline contact card also runs, and
/// self-hides when the viewer is the publisher.
class DetailStickyContactBar extends StatelessWidget {
  const DetailStickyContactBar({required this.listing, super.key});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ContactCtaCubit>(
      create: (_) => getIt<ContactCtaCubit>(param1: listing),
      child: BlocBuilder<ContactCtaCubit, ContactCtaState>(
        builder: (context, state) {
          if (state.isSelfContact) return const SizedBox.shrink();
          final l10n = AppLocalizations.of(context)!;
          final colors = AppColors.of(context);
          return DecoratedBox(
            decoration: BoxDecoration(
              color: colors.card,
              border: Border(top: BorderSide(color: colors.outline)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    if (state.showCall) ...[
                      Expanded(
                        flex: 4,
                        child: AppButton(
                          label: l10n.cta_call,
                          variant: AppButtonVariant.tonal,
                          icon: Icons.call,
                          expanded: true,
                          onPressed: () => ContactActions.call(
                            context,
                            listing,
                            state.phone!,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      flex: 4,
                      child: AppButton(
                        label: l10n.chatContactAction,
                        variant: AppButtonVariant.outlined,
                        icon: Icons.forum_outlined,
                        expanded: true,
                        onPressed: () =>
                            ContactActions.message(context, listing),
                      ),
                    ),
                    if (state.showWhatsApp) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        flex: 5,
                        child: AppButton(
                          label: l10n.cta_whatsapp,
                          variant: AppButtonVariant.whatsapp,
                          icon: LucideIcons.message_circle,
                          expanded: true,
                          onPressed: state.whatsappEnabled
                              ? () => ContactActions.whatsApp(
                                  context,
                                  listing,
                                  state.whatsapp!,
                                )
                              : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
