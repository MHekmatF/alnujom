// lib/features/agency/presentation/pages/agency_edit_profile_page.dart
//
// Phase 19 follow-up (spec/019-agencies) — agency profile editing + logo/cover
// upload. The original wave shipped no image-upload UI anywhere in the agency
// feature (create was name + contact only). This page lets an agency owner edit
// the profile text fields AND pick/upload a logo + cover image to the public
// `agency-assets` bucket; the returned public URLs are stored via
// update_agency_profile and rendered by the badge + public profile.
//
// The page loads its OWN agency via loadMyAgency() rather than a GoRouter
// `extra` payload: picking an image launches an external activity, and on a
// low-RAM device the app/route can be recreated on return with no `extra` (it
// is not part of the URI) — which previously red-screened on `state.extra as
// Agency`. Self-loading is robust to that recreation. Phase 2 tokens only.
//
// Phase 28 (premium-worth pass) — purely visual retrofit: AppTextField,
// AppButton, AppToast, AppSpinner. Behavior unchanged.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/agency.dart';
import '../../domain/repositories/agency_repository.dart';

class AgencyEditProfilePage extends StatefulWidget {
  const AgencyEditProfilePage({super.key});

  @override
  State<AgencyEditProfilePage> createState() => _AgencyEditProfilePageState();
}

class _AgencyEditProfilePageState extends State<AgencyEditProfilePage> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _address = TextEditingController();

  Agency? _agency;
  String? _logoUrl;
  String? _coverUrl;
  bool _loading = true;
  bool _loadFailed = false;
  bool _uploadingLogo = false;
  bool _uploadingCover = false;
  bool _saving = false;

  bool get _busy => _saving || _uploadingLogo || _uploadingCover;

  @override
  void initState() {
    super.initState();
    _loadAgency();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _loadAgency() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    final result = await getIt<AgencyRepository>().loadMyAgency();
    if (!mounted) return;
    switch (result) {
      case Success(:final value):
        if (value == null) {
          setState(() {
            _loading = false;
            _loadFailed = true;
          });
        } else {
          _name.text = value.name;
          _description.text = value.description ?? '';
          _phone.text = value.phone ?? '';
          _whatsapp.text = value.whatsapp ?? '';
          _address.text = value.address ?? '';
          setState(() {
            _agency = value;
            _logoUrl = value.logoPath;
            _coverUrl = value.coverPath;
            _loading = false;
          });
        }
      case FailureResult():
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
    }
  }

  String _contentTypeFor(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Shared logo/cover picker → uploads to agency-assets → stores the public URL.
  Future<void> _pickAsset({required bool isCover}) async {
    final agency = _agency;
    if (agency == null) return;
    final l10n = AppLocalizations.of(context)!;
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: isCover ? 1600 : 1024,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() {
      if (isCover) {
        _uploadingCover = true;
      } else {
        _uploadingLogo = true;
      }
    });
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
      final prefix = isCover ? 'cover' : 'logo';
      final filename =
          '${prefix}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final result = await getIt<AgencyRepository>().uploadAgencyAsset(
        agencyId: agency.id,
        filename: filename,
        bytes: bytes,
        contentType: _contentTypeFor(ext),
      );
      if (!mounted) return;
      switch (result) {
        case Success(:final value):
          // Persist the image immediately (not only on the form's Save button):
          // the picked URL would otherwise be lost if the user leaves without
          // saving, or if the page is recreated after the gallery round-trip on
          // a low-RAM device. Passing null for the other field leaves it
          // unchanged (the RPC COALESCEs).
          final persist = await getIt<AgencyRepository>().updateProfile(
            agencyId: agency.id,
            logoPath: isCover ? null : value,
            coverPath: isCover ? value : null,
          );
          if (!mounted) return;
          setState(() {
            if (isCover) {
              _coverUrl = value;
              _uploadingCover = false;
            } else {
              _logoUrl = value;
              _uploadingLogo = false;
            }
          });
          if (persist is FailureResult) {
            AppToast.error(context, l10n.agency_action_failed);
          }
        case FailureResult():
          setState(() {
            _uploadingCover = false;
            _uploadingLogo = false;
          });
          AppToast.error(context, l10n.agency_action_failed);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _uploadingCover = false;
        _uploadingLogo = false;
      });
      AppToast.error(context, l10n.agency_action_failed);
    }
  }

  Future<void> _save() async {
    final agency = _agency;
    if (agency == null) return;
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    String? orNull(TextEditingController c) {
      final v = c.text.trim();
      return v.isEmpty ? null : v;
    }

    final result = await getIt<AgencyRepository>().updateProfile(
      agencyId: agency.id,
      name: orNull(_name),
      description: orNull(_description),
      phone: orNull(_phone),
      whatsapp: orNull(_whatsapp),
      address: orNull(_address),
      logoPath: _logoUrl,
      coverPath: _coverUrl,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case Success():
        navigator.pop(true);
      case FailureResult():
        AppToast.error(context, l10n.agency_action_failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    Widget body;
    if (_loading) {
      body = const AppSpinner.page();
    } else if (_agency == null || _loadFailed) {
      body = Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.agency_generic_error, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              AppButton.filledPrimary(
                label: l10n.action_retry,
                onPressed: _loadAgency,
              ),
            ],
          ),
        ),
      );
    } else {
      body = AbsorbPointer(
        absorbing: _saving,
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover image (wide banner).
              _CoverPicker(
                url: _coverUrl,
                uploading: _uploadingCover,
                label: l10n.agency_cover_label,
                onPick: _busy ? null : () => _pickAsset(isCover: true),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Logo (square).
              Center(
                child: _LogoPicker(
                  url: _logoUrl,
                  uploading: _uploadingLogo,
                  label: l10n.agency_logo_label,
                  onPick: _busy ? null : () => _pickAsset(isCover: false),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(controller: _name, label: l10n.agency_name_label),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _description,
                label: l10n.agency_description_label,
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _phone,
                label: l10n.agency_phone_label,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _whatsapp,
                label: l10n.agency_whatsapp_label,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _address,
                label: l10n.agency_address_label,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton.filledPrimary(
                label: l10n.agency_save_button,
                expanded: true,
                loading: _saving,
                onPressed: _busy ? null : _save,
              ),
            ],
          ),
        ),
      );
    }

    return DcCrownScaffold(
      title: l10n.agency_edit_button,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.shellHome),
      ),
      body: body,
    );
  }
}

class _LogoPicker extends StatelessWidget {
  const _LogoPicker({
    required this.url,
    required this.uploading,
    required this.label,
    required this.onPick,
  });

  final String? url;
  final bool uploading;
  final String label;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasImage = url != null && url!.isNotEmpty;
    return Column(
      children: [
        ClipRRect(
          borderRadius: appRadius(AppRadii.md),
          child: SizedBox(
            width: AppSpacing.xxxl + AppSpacing.xl,
            height: AppSpacing.xxxl + AppSpacing.xl,
            child: uploading
                ? ColoredBox(
                    color: colors.surfaceVariant,
                    child: const AppSpinner(),
                  )
                : hasImage
                ? CachedNetworkImage(
                    imageUrl: url!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _fallback(colors),
                  )
                : _fallback(colors),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: label,
          variant: AppButtonVariant.text,
          icon: LucideIcons.camera,
          onPressed: onPick,
        ),
      ],
    );
  }

  Widget _fallback(AppColors colors) => ColoredBox(
    color: colors.surfaceVariant,
    child: Icon(LucideIcons.building_2, color: colors.textMuted),
  );
}

class _CoverPicker extends StatelessWidget {
  const _CoverPicker({
    required this.url,
    required this.uploading,
    required this.label,
    required this.onPick,
  });

  final String? url;
  final bool uploading;
  final String label;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasImage = url != null && url!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: appRadius(AppRadii.md),
          child: SizedBox(
            height: AppSpacing.xxxl + AppSpacing.xxxl,
            child: uploading
                ? ColoredBox(
                    color: colors.surfaceVariant,
                    child: const AppSpinner(),
                  )
                : hasImage
                ? CachedNetworkImage(
                    imageUrl: url!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _fallback(colors),
                  )
                : _fallback(colors),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: label,
          variant: AppButtonVariant.text,
          icon: LucideIcons.image,
          onPressed: onPick,
        ),
      ],
    );
  }

  Widget _fallback(AppColors colors) => ColoredBox(
    color: colors.surfaceVariant,
    child: Icon(LucideIcons.images, color: colors.textMuted),
  );
}
