// lib/features/agency/presentation/pages/agency_edit_profile_page.dart
//
// Phase 19 follow-up (spec/019-agencies) — agency profile editing + logo upload.
// The original wave shipped no image-upload UI anywhere in the agency feature
// (create was name + contact only). This page lets an agency owner edit the
// profile text fields AND pick/upload a logo to the public `agency-assets`
// bucket; the returned public URL is stored via update_agency_profile and
// rendered by the badge + public profile. Phase 2 tokens; strings via l10n.
//
// The page loads its OWN agency via loadMyAgency() rather than relying on a
// GoRouter `extra` payload: picking an image launches an external activity,
// and on a low-RAM device the app/route can be recreated on return with no
// `extra` (it is not part of the URI) — which previously red-screened on
// `state.extra as Agency`. Self-loading is robust to that recreation.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
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
  bool _loading = true;
  bool _loadFailed = false;
  bool _uploading = false;
  bool _saving = false;

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

  Future<void> _pickLogo() async {
    final agency = _agency;
    if (agency == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
      final filename = 'logo_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final result = await getIt<AgencyRepository>().uploadAgencyAsset(
        agencyId: agency.id,
        filename: filename,
        bytes: bytes,
        contentType: _contentTypeFor(ext),
      );
      if (!mounted) return;
      switch (result) {
        case Success(:final value):
          setState(() {
            _logoUrl = value;
            _uploading = false;
          });
        case FailureResult():
          setState(() => _uploading = false);
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.agency_action_failed)),
          );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploading = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.agency_action_failed)),
      );
    }
  }

  Future<void> _save() async {
    final agency = _agency;
    if (agency == null) return;
    final messenger = ScaffoldMessenger.of(context);
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
    );
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case Success():
        navigator.pop(true);
      case FailureResult():
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.agency_action_failed)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_agency == null || _loadFailed) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.agency_generic_error, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: _loadAgency,
                child: Text(l10n.action_retry),
              ),
            ],
          ),
        ),
      );
    } else {
      final hasLogo = _logoUrl != null && _logoUrl!.isNotEmpty;
      body = AbsorbPointer(
        absorbing: _saving,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      child: SizedBox(
                        width: AppSpacing.xxxl + AppSpacing.xl,
                        height: AppSpacing.xxxl + AppSpacing.xl,
                        child: _uploading
                            ? Container(
                                color: scheme.surfaceContainerHighest,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : hasLogo
                                ? CachedNetworkImage(
                                    imageUrl: _logoUrl!,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        _logoFallback(scheme),
                                  )
                                : _logoFallback(scheme),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton.icon(
                      onPressed: _uploading ? null : _pickLogo,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(l10n.agency_logo_label),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _field(_name, l10n.agency_name_label),
              const SizedBox(height: AppSpacing.md),
              _field(_description, l10n.agency_description_label, maxLines: 3),
              const SizedBox(height: AppSpacing.md),
              _field(_phone, l10n.agency_phone_label,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: AppSpacing.md),
              _field(_whatsapp, l10n.agency_whatsapp_label,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: AppSpacing.md),
              _field(_address, l10n.agency_address_label),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: (_saving || _uploading) ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: AppSpacing.lg,
                        height: AppSpacing.lg,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.agency_save_button),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.agency_edit_button)),
      body: body,
    );
  }

  Widget _logoFallback(ColorScheme scheme) => Container(
        color: scheme.surfaceContainerHighest,
        child: Icon(Icons.business_outlined, color: scheme.onSurfaceVariant),
      );

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
