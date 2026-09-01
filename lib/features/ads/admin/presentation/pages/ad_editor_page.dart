// Phase 21 (spec/021-ads-banners) — T026
// AdEditorPage: create (ad == null) or edit (ad != null) an ad.
// Fields: title, image pick+upload, optional ar+en caption (both-or-neither),
// link picker, schedule picker, placement+priority picker, active toggle.
// Save → CreateAd (new) or UpdateAd (edit).
// Image flow: pick → compress → UploadAdImage → store returned path.
// Constitution IX: zero supabase_flutter imports.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/radii.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../core/widgets/_widget_support.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_spinner.dart';
import '../../../../../core/widgets/app_toggle.dart';
import '../../../../../core/widgets/app_toast.dart';
import '../../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../../core/widgets/press_scale.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../domain/entities/ad.dart';
import '../../../domain/entities/ad_link.dart';
import '../../../domain/entities/ad_placement_assignment.dart';
import '../bloc/ads_admin_cubit.dart';
import '../widgets/link_target_picker.dart';
import '../widgets/placement_picker.dart';
import '../widgets/schedule_picker.dart';

class AdEditorPage extends StatefulWidget {
  const AdEditorPage({super.key, this.ad});

  /// Non-null when editing an existing ad; null when creating.
  final Ad? ad;

  @override
  State<AdEditorPage> createState() => _AdEditorPageState();
}

class _AdEditorPageState extends State<AdEditorPage> {
  final _formKey = GlobalKey<FormState>();

  // Form field state
  late final TextEditingController _titleController;
  late final TextEditingController _captionArController;
  late final TextEditingController _captionEnController;

  late AdLinkKind _linkKind;
  late String _linkValue;
  DateTime? _startAt;
  DateTime? _endAt;
  late bool _isActive;
  late List<AdPlacementAssignment> _placements;

  // Image state
  /// The current storage path (set after upload or from existing ad.imagePath).
  String? _imagePath;
  Uint8List? _imagePreviewBytes; // preview from the just-picked image

  bool _isSaving = false;

  bool get _isEditing => widget.ad != null;

  @override
  void initState() {
    super.initState();
    final ad = widget.ad;
    _titleController = TextEditingController(text: ad?.title ?? '');
    _captionArController = TextEditingController(text: ad?.captionAr ?? '');
    _captionEnController = TextEditingController(text: ad?.captionEn ?? '');
    _linkKind = ad?.linkKind ?? AdLinkKind.external;
    _linkValue = ad?.linkValue ?? '';
    _startAt = ad?.startAt;
    _endAt = ad?.endAt;
    _isActive = ad?.isActive ?? true;
    _placements = List.from(ad?.placements ?? const <AdPlacementAssignment>[]);
    _imagePath = ad?.imagePath;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _captionArController.dispose();
    _captionEnController.dispose();
    super.dispose();
  }

  // ── Image pick+upload ─────────────────────────────────────────────────────

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final rawBytes = await picked.readAsBytes();

    // Compress to JPEG, max 1200 px wide, 80 % quality — mirrors listing_form.
    final compressed = await FlutterImageCompress.compressWithList(
      rawBytes,
      minWidth: 1200,
      minHeight: 1,
      quality: 80,
      format: CompressFormat.jpeg,
    );

    setState(() {
      _imagePreviewBytes = Uint8List.fromList(compressed);
    });

    if (!mounted) return;

    // Upload via the cubit; listen for AdsAdminImageUploaded in the listener.
    // Intentionally unawaited — the result comes via BlocConsumer listener.
    unawaited(
      context.read<AdsAdminCubit>().uploadImage(
        bytes: Uint8List.fromList(compressed),
        contentType: 'image/jpeg',
      ),
    );
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final l10n = AppLocalizations.of(context)!;

    // Schedule validation
    if (_startAt != null && _endAt != null && !_startAt!.isBefore(_endAt!)) {
      AppToast.warning(context, l10n.scheduleStartMustBeforeEnd);
      return;
    }

    // Image required
    if (_imagePath == null || _imagePath!.isEmpty) {
      AppToast.warning(context, l10n.adsAdminImageRequired);
      return;
    }

    // Both-or-neither caption validation
    final arFilled = _captionArController.text.trim().isNotEmpty;
    final enFilled = _captionEnController.text.trim().isNotEmpty;
    if (arFilled != enFilled) {
      AppToast.warning(context, l10n.adsAdminCaptionBothOrNeither);
      return;
    }

    final captionAr = arFilled ? _captionArController.text.trim() : null;
    final captionEn = enFilled ? _captionEnController.text.trim() : null;

    final placementMaps = _placements
        .map(
          (a) => <String, dynamic>{
            'placement_key': a.placement.wireValue,
            'priority': a.priority,
          },
        )
        .toList();

    final cubit = context.read<AdsAdminCubit>();

    if (_isEditing) {
      await cubit.updateAd(
        adId: widget.ad!.id,
        title: _titleController.text.trim(),
        imagePath: _imagePath!,
        captionAr: captionAr,
        captionEn: captionEn,
        linkKind: _linkKind.wireValue,
        linkValue: _linkValue.trim(),
        startAt: _startAt,
        endAt: _endAt,
        isActive: _isActive,
        placements: placementMaps,
      );
    } else {
      await cubit.createAd(
        title: _titleController.text.trim(),
        imagePath: _imagePath!,
        captionAr: captionAr,
        captionEn: captionEn,
        linkKind: _linkKind.wireValue,
        linkValue: _linkValue.trim(),
        startAt: _startAt,
        endAt: _endAt,
        isActive: _isActive,
        placements: placementMaps,
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocConsumer<AdsAdminCubit, AdsAdminState>(
      listener: (ctx, state) {
        if (state is AdsAdminSaving) {
          setState(() => _isSaving = true);
        } else {
          setState(() => _isSaving = false);
        }

        if (state is AdsAdminImageUploaded) {
          setState(() => _imagePath = state.imagePath);
        }

        if (state is AdsAdminSaveSuccess) {
          Navigator.of(ctx).pop();
        }

        if (state is AdsAdminError) {
          AppToast.error(ctx, state.failure.message);
        }
      },
      builder: (ctx, state) {
        final styles = AppTextStyles.of(ctx);
        final colors = AppColors.of(ctx);
        return DcCrownScaffold(
          title: _isEditing ? l10n.adsAdminEditTitle : l10n.adsAdminCreateTitle,
          dense: true,
          leading: DcCrownIconButton(
            icon: Icons.arrow_forward,
            onTap: () => ctx.canPop() ? ctx.pop() : ctx.go(AppRoutes.shellHome),
          ),
          actions: [
            if (_isSaving)
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                child: AppSpinner(
                  size: AppSpacing.lg,
                  color: colors.onBrandHeader,
                ),
              )
            else
              // Batch-2: a stock TextButton hand-repainted onto the crown
              // became the DS DcCrownTextButton (the crown's own action idiom).
              DcCrownTextButton(label: l10n.saveLabel, onTap: _save),
          ],
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
              children: [
                // ── Title ───────────────────────────────────────────────────
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: l10n.adsAdminTitleFieldLabel,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10n.adsAdminTitleRequired
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Image ────────────────────────────────────────────────
                Text(l10n.adsAdminImageLabel, style: styles.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                _ImagePickerArea(
                  imagePreviewBytes: _imagePreviewBytes,
                  existingImagePath: _imagePath,
                  isSaving: _isSaving,
                  onPickTapped: _pickAndUploadImage,
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Optional bilingual captions ──────────────────────────
                Text(l10n.adsAdminCaptionLabel, style: styles.labelLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.adsAdminCaptionBothOrNeitherHint,
                  style: styles.bodyMedium.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _captionArController,
                  decoration: InputDecoration(
                    labelText: l10n.adsAdminCaptionArLabel,
                  ),
                  textDirection: TextDirection.rtl,
                  validator: (v) {
                    final arFilled = (v ?? '').trim().isNotEmpty;
                    final enFilled = _captionEnController.text
                        .trim()
                        .isNotEmpty;
                    if (!arFilled && enFilled) {
                      return l10n.adsAdminCaptionBothOrNeither;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _captionEnController,
                  decoration: InputDecoration(
                    labelText: l10n.adsAdminCaptionEnLabel,
                  ),
                  validator: (v) {
                    final enFilled = (v ?? '').trim().isNotEmpty;
                    final arFilled = _captionArController.text
                        .trim()
                        .isNotEmpty;
                    if (!enFilled && arFilled) {
                      return l10n.adsAdminCaptionBothOrNeither;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Link target ──────────────────────────────────────────
                LinkTargetPicker(
                  initialKind: _linkKind,
                  initialValue: _linkValue,
                  onChanged: (kind, value) {
                    setState(() {
                      _linkKind = kind;
                      _linkValue = value;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Schedule ─────────────────────────────────────────────
                SchedulePicker(
                  startAt: _startAt,
                  endAt: _endAt,
                  onStartChanged: (dt) => setState(() => _startAt = dt),
                  onEndChanged: (dt) => setState(() => _endAt = dt),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Placements ───────────────────────────────────────────
                PlacementPicker(
                  value: _placements,
                  onChanged: (updated) => setState(() => _placements = updated),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Active toggle ────────────────────────────────────────
                _ActiveSwitchRow(
                  label: l10n.adsAdminActiveToggleLabel,
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Image picker area ─────────────────────────────────────────────────────────

class _ImagePickerArea extends StatelessWidget {
  const _ImagePickerArea({
    required this.imagePreviewBytes,
    required this.existingImagePath,
    required this.isSaving,
    required this.onPickTapped,
  });

  final Uint8List? imagePreviewBytes;
  final String? existingImagePath;
  final bool isSaving;
  final VoidCallback onPickTapped;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    final hasImage =
        imagePreviewBytes != null || (existingImagePath?.isNotEmpty ?? false);

    return GestureDetector(
      onTap: isSaving ? null : onPickTapped,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: appRadius(AppRadii.sm),
          border: Border.all(color: colors.outline),
        ),
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  if (imagePreviewBytes != null)
                    ClipRRect(
                      borderRadius: appRadius(AppRadii.sm),
                      child: Image.memory(
                        imagePreviewBytes!,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Center(
                      child: Icon(
                        LucideIcons.image,
                        size: AppSpacing.xxxl,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  // Upload indicator overlay
                  if (isSaving)
                    Container(
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: 0.7),
                        borderRadius: appRadius(AppRadii.sm),
                      ),
                      child: const AppSpinner(),
                    ),
                  // Tap to replace overlay
                  if (!isSaving)
                    PositionedDirectional(
                      bottom: AppSpacing.sm,
                      end: AppSpacing.sm,
                      child: AppButton(
                        label: l10n.adsAdminImageReplaceLabel,
                        variant: AppButtonVariant.tonal,
                        size: AppButtonSize.dense,
                        onPressed: onPickTapped,
                      ),
                    ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.image_plus,
                    size: AppSpacing.xxl + AppSpacing.sm,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.adsAdminImagePickLabel,
                    style: styles.bodyMedium.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Active toggle row ─────────────────────────────────────────────────────────

/// Branded replacement for the stock [SwitchListTile] — tinted icon circle +
/// label on a hairline surface with a trailing [Switch]. Tapping the row
/// toggles, mirroring the original tile behavior.
class _ActiveSwitchRow extends StatelessWidget {
  const _ActiveSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return PressScale(
      child: AppSurface(
        radius: AppRadii.lg,
        onTap: () => onChanged(!value),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: AppSpacing.xxl + AppSpacing.sm,
              height: AppSpacing.xxl + AppSpacing.sm,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary.withValues(alpha: 0.12),
              ),
              child: Icon(
                LucideIcons.megaphone,
                color: colors.primary,
                size: AppSpacing.lg,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: styles.bodyLarge)),
            const SizedBox(width: AppSpacing.sm),
            // Batch-2: the bare Material Switch -> the DS AppToggle, so all
            // four internal toggle rows share one active-state treatment.
            AppToggle(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
