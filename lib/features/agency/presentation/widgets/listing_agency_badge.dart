// lib/features/agency/presentation/widgets/listing_agency_badge.dart
//
// Phase 19 (spec/019-agencies) Sub-Phase H (T061).
// Self-contained badge for the listing-details page: loads the listing's
// agency via LoadAgencyById (through AgencyVerificationCubit) and renders the
// verified [AgencyBadge] ONLY when the agency is approved. Renders nothing
// otherwise (no reflow). Hosts its own cubit so the details page stays
// Constitution-IX clean and the Favorite/Share/Report CTAs are untouched.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/spacing.dart';
import '../../domain/entities/agency_status.dart';
import '../bloc/agency_verification_cubit.dart';
import 'agency_badge.dart';

class ListingAgencyBadge extends StatelessWidget {
  const ListingAgencyBadge({super.key, required this.agencyId});

  /// The listing's agency_id; the badge loads + gates on its `approved` status.
  final String agencyId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AgencyVerificationCubit>(
      create: (_) => getIt<AgencyVerificationCubit>()..load(agencyId),
      child: const _ListingAgencyBadgeView(),
    );
  }
}

class _ListingAgencyBadgeView extends StatelessWidget {
  const _ListingAgencyBadgeView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AgencyVerificationCubit, AgencyVerificationState>(
      builder: (context, state) {
        if (state is! AgencyVerificationReady ||
            state.agency.status != AgencyStatus.approved) {
          return const SizedBox.shrink();
        }
        final agency = state.agency;
        return Padding(
          padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: AgencyBadge(
              agencyId: agency.id,
              agencyName: agency.name,
              logoUrl: agency.logoPath,
            ),
          ),
        );
      },
    );
  }
}
