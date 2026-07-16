# Al Nujom — UI/UX Pass · CHANGELOG

_Autonomous UI/UX quality pass driven by the `ui-ux-pro-max` skill, on branch
`035-redesign-ground-up`. One entry per screen touched: gaps found → changes made → skill rules
applied. All changes are front-end / token-clean / RTL-safe; no behavior, backend, or DB changes._

Persisted design system: `design-system/al-nujom/MASTER.md` + per-page files under
`design-system/al-nujom/pages/`.

---


## bottom nav + FAB + states  · `b6afccb`
_Files (5):_ `main_bottom_nav.dart`, `publish_fab.dart`, `empty_state.dart`, `error_state.dart`, `loading_state.dart`

**Changes made:**
- main_bottom_nav.dart: added `package:flutter/services.dart` import
- main_bottom_nav.dart: wrapped the _NavTab InkWell in Semantics(button:true, selected:selected, label:label, excludeSemantics:true) and fired HapticFeedback.selectionClick() before the unchanged onTap() (routing untouched)
- main_bottom_nav.dart (medium): split shared `fg` into iconColor (selected=primary / inactive=textMuted) and labelColor (selected=primary / inactive=onSurfaceVariant) so the 10.5px label clears the small-text contrast bar while the inactive icon keeps its quiet tint
- publish_fab.dart: added services.dart, ../theme/radii.dart, and _widget_support.dart imports
- publish_fab.dart: gave the extended FAB a token-clean pill via shape: RoundedRectangleBorder(borderRadius: appRadius(AppRadii.pill))
- publish_fab.dart: added tooltip: l10n.nav_publish and HapticFeedback.selectionClick() before the unchanged pushNamed (routing untouched)
- empty_state.dart: wrapped the headline Text in Semantics(header:true) (no visual change)
- error_state.dart: wrapped the title Text in Semantics(header:true) (no visual change)
- loading_state.dart: made _SweepGradientTransform.transform direction-aware — RTL flips the horizontal translation sign so the shimmer sweeps with the reading direction

## listing card (3 modes)  · `b021835`
_Files (2):_ `listing_view_mode_switcher.dart`, `ds_listing_card.dart`

**Changes made:**
- switcher (safe, a11y/touch-target): wrapped the 32dp density-picker Container in AppTapTarget so the PopupMenuButton hit region is >=48dp while the visible chip stays 32dp (no layout shift, gesture still owned by PopupMenuButton)
- switcher (medium, icon-consistency): added flutter_lucide import and swapped Material Icons.view_agenda/day/list_outlined for LucideIcons.gallery_vertical/rows_2/list in _iconFor (all 3 constants verified present in flutter_lucide 1.11.0)
- card (safe, contrast): added _purposeForeground(context) per-purpose on-color (onPrimary/onSuccess/onAccent/onTertiary) and passed foreground: on both purpose StatusPill call sites (_imageBadges + _compactBadge fallback), fixing white-on-gold investment pill
- card (safe, spacing): widened comfortable content gutter from EdgeInsetsDirectional.fromSTEB(xs,sm,xs,xs) to (md,sm,md,md)
- card (medium, i18n): added intl import; localized meta line — _metaLine builds l10n + NumberFormat.decimalPattern(locale) and _metaText(l10n,numFmt) now uses l10n.spec_rooms_label / l10n.spec_area_unit with locale-formatted numerals instead of hardcoded 'غرف'/'م²'
- card (medium, radius): added optional BorderRadiusGeometry borderRadius param to _image (clip uses borderRadius ?? appRadius(radius), backward-compatible); compact call now passes const BorderRadiusDirectional.horizontal(start: Radius.circular(AppRadii.lg)) so leading corners match the lg card clip and text-adjacent end corners stay square (RTL-safe)

## home feed  · `7d4baa7`
_Files (7):_ `hero_search_bar.dart`, `home_page.dart`, `home_popular_searches.dart`, `home_transaction_toggle.dart`, `home_categories_section.dart`, `home_verified_rail.dart`, `home_trust_strip.dart`

**Changes made:**
- Edit1 (safe) hero_search_bar.dart: _actionSize 40 -> kAppMinTouchTarget (48dp); wrapped the solid-primary filter _RoundAction in Tooltip(message: l10n.search_filters_button) to add the missing accessible label (assistant already had one).
- Edit2 (safe) home_page.dart: _HomeHeaderBell._size 42 -> kAppMinTouchTarget; also bumped _HomeAvatar._size 46 -> kAppMinTouchTarget for header symmetry (both 48dp); refreshed the three stale 42px/46px doc comments to 48px.
- Edit3 (medium) home_popular_searches.dart: chip rail height scale(40) -> scale(kAppMinTouchTarget) (still text-scaled).
- Edit4 (medium) home_transaction_toggle.dart: wrapped _Segment label Padding in ConstrainedBox(minHeight: kAppMinTouchTarget) + Center so each quick-filter segment is >=48dp tall; pill visual + onTap unchanged.
- Edit5 (safe) home_categories_section.dart: _SeeAllButton now uses a directionality-aware chevron (rtl -> chevron_left, ltr -> chevron_right) and a Container(minHeight: kAppMinTouchTarget, AlignmentDirectional.center) for a >=48dp target.
- Edit6 (safe) home_verified_rail.dart: (a) see-all InkWell child wrapped in Container(minHeight: kAppMinTouchTarget, AlignmentDirectional.center); (b) rail SizedBox height 214 -> MediaQuery.textScalerOf(context).scale(214) to avoid clipping at large text.
- Edit7 (safe) home_trust_strip.dart: sub-line color colors.textMuted -> colors.onSurfaceVariant for reliable 4.5:1 contrast on the verifiedContainer tint.
- Edit8 (high -> SAFE ALTERNATIVE) home_page.dart: did NOT reorder the rail wall; instead inserted a const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)) breather before the Latest-listings section. Its header already uses the accent-rule _SectionHeader, so no header change needed.

**Deferred (in REVIEW.md):** Edit9 (medium) home_page.dart motion polish: wrap HeroSearchBar/HomePopularSearc

## search + filters  · `be3f31d`
_Files (2):_ `search_page.dart`, `search_filter_sheet.dart`

**Changes made:**
- search_page: initial state now shows _SearchSkeleton instead of bare Center(Text) placeholder (no blank-screen flash)
- search_page: failure(empty) now renders shared branded ErrorState (title=search_error_title, message=search_error_message, network variant, onRetry→SearchRefreshRequested); deleted unused _ErrorView; added error_state.dart import
- search_page: _SearchSkeleton is mode-aware (comfortable 300 / balanced 272 / compact 128 via ListingViewModePref) so it resembles the DsListingCard it swaps to
- search_page: _EmptyView token-cleaned — AppColors.primary tint/icon, AppTextStyles.titleLarge title, subtitle bodyMedium+textMuted (removed Theme.of colorScheme/textTheme)
- search_page: Arabic-hint banner token-cleaned — colors.surfaceVariant + appRadius(md) rounded card + bodyMedium/onSurfaceVariant (removed surfaceContainerHighest + default Text)
- search_page: _FilterPill raised to 48dp min touch target (removed _height=38; constraints minHeight kAppMinTouchTarget + AlignmentDirectional.center) and wrapped in Semantics(button:true, selected:selected)
- search_page: _SortAndFiltersRow 'Sort:' label → labelMedium+textMuted, spacer 4→AppSpacing.xs, rail start→AppSpacing.lg (aligned with header/input/chips)
- search_page: _DisplayModeBar rail start→AppSpacing.lg to match the same 16dp rail
- search_page: added useSafeArea:true to the filter-sheet showModalBottomSheet call
- filter_sheet: pinned Reset/Apply footer — Form>Column[Expanded(SingleChildScrollView(sections)), footer] with top hairline (Border top colors.divider) + SafeArea bottom + appPadding; action row onApply/pop/reset unchanged
- filter_sheet: removed the manually-rendered _buildHandle (theme bottomSheetTheme provides the single drag handle) — also removed a non-token color + raw BorderRadius.circular
- filter_sheet: tokenized inter-section spacing (16→AppSpacing.lg, in-section 8→AppSpacing.sm) and inserted AppSpacing.xl gaps between the 3 logical groups (spacing-only grouping, no new copy)
- filter_sheet: purpose & property-type Wraps spacing 8→AppSpacing.sm + added runSpacing:AppSpacing.sm (fixes 8-chip vertical-collision defect)
- filter_sheet: title → AppTextStyles.titleLarge; every section label → AppTextStyles.labelLarge (removed all Theme.of textTheme bypasses)
- filter_sheet: wrapped the 3 location + currency DropdownButtons in a new branded _sheetDropdownFrame (card fill + outline + md radius + DropdownButtonHideUnderline); value/items/onChanged untouched
- filter_sheet: location label now shows appInlineSpinner while _loadingGovernorates (previously silently disabled with no feedback)
- filter_sheet: removed the duplicated outer 'Price range' / 'Area size' labels (RangeSliderField header already renders label + live range)

**Deferred (in REVIEW.md):** Convert the 4 bare DropdownButton to DropdownButtonFormField (search-filters spe; Introduce 3 group headers (Basics / Documentation & verification / Property deta

## listing detail  · `6d9ffd6`
_Files (6):_ `listing_details_page.dart`, `contact_block.dart`, `similar_listings_carousel.dart`, `seller_reviews_section.dart`, `affordability_calculator.dart`, `per_listing_action_block.dart`

**Changes made:**
- listing_details_page.dart: added top photoTopScrim gradient (Positioned.fill + IgnorePointer) as 2nd Stack child over the gallery, with gradients.dart import — legibility for over-photo affordances (medium)
- listing_details_page.dart: SliverAppBar made transparent (backgroundColor/surfaceTintColor Colors.transparent, scrolledUnderElevation 0, elevation 0) + foregroundColor onPhoto so the back arrow reads over the scrim (medium)
- listing_details_page.dart: 360 pill InkWell wrapped in ConstrainedBox(minHeight kAppMinTouchTarget)+Center for a 48dp tap slot (safe)
- listing_details_page.dart: wrapped gallery GestureDetector in Semantics(button/label mediaGalleryVideoPlay) gated on videoMedia (safe)
- listing_details_page.dart: _PurposeTagChip label color primary -> onPrimaryContainer for AA pairing (safe)
- contact_block.dart: split the 3-up secondary row into 2+1 (Call+Message share row one, Request-viewing full-width beneath) — same handlers/visibility, no truncation (medium)
- contact_block.dart: contact_section_title color onSurfaceVariant -> onSurface in both agent-card and fallback branches (safe)
- similar_listings_carousel.dart: section header titleLarge -> titleMedium (safe)
- seller_reviews_section.dart: section header titleLarge -> titleMedium (safe)
- affordability_calculator.dart: AnimatedSize duration -> AppMotion.base + curve AppMotion.curve, added motion.dart import (safe)
- per_listing_action_block.dart: _ActionButton Icon size 20 -> AppSpacing.xl (safe)

## map view  · `8868db1`
_Files (4):_ `map_page.dart`, `marker_pins.dart`, `map_refresh_button.dart`, `marker_preview_popover.dart`

**Changes made:**
- map_page.dart: added `import 'package:flutter/services.dart';` for HapticFeedback
- map_page.dart (safe): build MarkerPreviewPopover before the Stack with a reduced-motion-guarded fadeIn+slideY entrance (AppMotion.base/emphasized); render via Positioned with bottom raised AppSpacing.lg -> AppSpacing.xxxl so the OSM attribution stays visible
- map_page.dart (medium): CenterOnMyLocationFab now renders only when selectedMarker==null (removes FAB-over-popover collision) and bottom:80 replaced with token sum AppSpacing.xxxl + AppSpacing.xxl
- map_page.dart (safe): _buildMarker wrapped pin in Semantics(button:true, label: title or l10n.map_marker_semantics_label) and added HapticFeedback.selectionClick() alongside the unchanged MarkerTapped dispatch
- map_page.dart (safe): added _MapLoadingBody (Semantics label l10n.map_loading_label, liveRegion) and used it for MapInitial + MapLoading arms (spinner visual unchanged)
- marker_pins.dart (safe): added elevation.dart import; ClusterBadge bespoke inline BoxShadow replaced with AppElevation.of(context).level1
- map_refresh_button.dart (safe): added flutter_lucide import; Icons.refresh -> LucideIcons.refresh_cw
- marker_preview_popover.dart (safe): added flutter_lucide import; Icons.info_outline -> LucideIcons.info, Icons.close -> LucideIcons.x, Icons.image_not_supported_outlined -> LucideIcons.image_off

## favorites  · `6dbd1d0`
_Files (3):_ `favorites_sort_bar.dart`, `favorites_page.dart`, `favorite_card.dart`

**Changes made:**
- sort_bar: removed isDense:true from the sort DropdownButton (restores 48dp touch target)
- sort_bar: added HapticFeedback.selectionClick() in onChanged before the unchanged FavoritesPageSortChanged dispatch (+ flutter/services.dart import)
- sort_bar: wrapped header Padding in a Container with a BorderDirectional bottom hairline (colors.divider) for section separation
- page: added ListView.builder bottom padding EdgeInsetsDirectional.only(bottom: AppSpacing.xxxl + AppSpacing.xl) so last card clears FAB + compare bar
- page: rebuilt _FavoritesSkeleton to mirror FavoriteCard (card fill, AppRadii.lg, outline border, elevation.level2, clipped 16:10 image, price/title/specs shimmer lines) + added colors/elevation/radii/_widget_support imports
- favorite_card: unified location row icon + text color from colors.textMuted to colors.onSurfaceVariant to match adjacent PropertySpecsRow

## chat + assistant  · `cd4902b`
_Files (3):_ `conversations_list_page.dart`, `chat_thread_page.dart`, `assistant_page.dart`

**Changes made:**
- conversations_list: replaced AppSpinner.page() loading branch with a 6-row skeleton ListView + new _ConversationSkeleton widget (added loading_state import, removed now-unused app_spinner import)
- conversations_list: wrapped each _ConversationTile in StaggeredListItem(index: i) for subtle fade+slide entrance (added staggered_list_item import)
- chat_thread: added l10n + footerColor to _MessageBubble; incoming footer time now uses onSurfaceVariant (was onSurface@0.7)
- chat_thread: wrapped read-receipt tick in Semantics(label: chatMessageRead/chatMessageSent) and bumped size AppSpacing.md -> AppSpacing.lg
- chat_thread: composer field vertical padding AppSpacing.xs -> AppSpacing.sm
- chat_thread: composer top separator colors.outline -> colors.divider
- chat_thread: send button now a ValueListenableBuilder -> enabled(primary)/disabled(surfaceVariant) by trimmed text, PressScale(enabled:canSend), onTap null when empty, Icons.send mirrored under RTL via Transform.scale (added press_scale import)
- assistant: added flutter/services.dart import for HapticFeedback
- assistant: _onSend fires HapticFeedback.selectionClick() after the empty-guard
- assistant: _TypingBubble reads l10n and wraps _AssistantBubble in Semantics(label: assistantTyping, container: true)
- assistant: _QuickReplies chips now sm vertical padding + ConstrainedBox(minHeight xxl)+Center (~48dp) + selection haptic before onTap, and a labelMedium/textMuted lead-in Text(assistantTrySuggestions) above the chip Wrap
- assistant: send IconButton.filled wrapped in ValueListenableBuilder -> onPressed null when field empty (disabled visual)

## profile  · `71413a7`
_Files (2):_ `profile_page.dart`, `profile_private_page.dart`

**Changes made:**
- profile_page.dart: replaced bare _NullProfileState with shared ErrorState (variant network, title=profileLoadErrorTitle, same message + same onRetry->ProfileCubit.load); added error_state.dart import; deleted the now-unused _NullProfileState class
- profile_page.dart: removed the redundant AppBar `actions` Edit TextButton so the full-width header Edit button is the single Edit CTA (route AppRoutes.profileEdit still reachable via header)
- profile_page.dart: wrapped the three body blocks (identity header idx0, Account section idx1, Sign out idx2) in StaggeredListItem for the reduced-motion-guarded staggered entrance; added staggered_list_item.dart import
- profile_page.dart: wrapped _ProfileSwitchRow's Material in PressScale so Data-saver row matches the tap feedback of _ProfileRow/Sign out (PressScale already imported; onChanged/Switch unchanged)
- profile_private_page.dart: replaced the bare Material TextField in _ContactField with DS AppTextField (same controller/label/keyboardType); added app_text_field.dart import
- profile_private_page.dart: added optional `subtitle` to _PrivateSection (muted bodyMedium under the header) and passed l10n.profilePrivateSecurityNote to the Private Identity section as a trust/reassurance line

## reels  · `939c287`
_Files (2):_ `reels_feed_page.dart`, `reel_player.dart`

**Changes made:**
- reels_feed_page: wrapped initial/loading, failure, empty branches in ColoredBox(colors.surface) so info states read on an opaque themed surface instead of the scrim (contrast, medium)
- reels_feed_page: 'View listing' CTA made full-width via expanded:true (safe)
- reels_feed_page: CTA arrow chosen by Directionality (arrow_left in RTL / arrow_right in LTR) (safe)
- reels_feed_page: rebuilt _ReelsTopBar with muted/onToggleMute params + trailing persistent glass mute chip (volume_off/volume_2) reflecting+toggling existing state; added _ReelChipButton helper (48dp photoOverlay circle, onPhoto icon, elevation.level1, Semantics button) (medium)
- reels_feed_page: added canPop-guarded leading close chip (directional back arrow, Navigator.maybePop, l10n.reels_close) — high, implemented per founder decision
- reels_feed_page: loaded-branch Stack now builds _ReelsTopBar(muted:_muted,onToggleMute:_toggleMute); ReelPlayer caller passes muteToggleSemanticLabel: reels_mute_toggle
- reel_player: added required muteToggleSemanticLabel param and wrapped tap-to-mute GestureDetector in Semantics(button:true,label:) (medium a11y)
- reel_player: replaced no-op AnimatedOpacity(opacity:1) with TweenAnimationBuilder<double>(0->1) for a real 200ms poster->video fade-in, reduced-motion guarded (medium motion)

## onboarding + splash  · `5517072`
_Files (2):_ `onboarding_page.dart`, `splash_page.dart`

**Changes made:**
- onboarding_page.dart: CTA now reads onboarding_next on non-final steps, onboarding_get_started only on last step (step >= total - 1); onPressed=nextStep() unchanged (safe)
- onboarding_page.dart: progress dots animated via AnimatedContainer (AppMotion.base/curve) + wrapped in Semantics(label: l10n.stepCounter(step+1, total)) with inner ExcludeSemantics (safe)
- onboarding_page.dart: _SlideBackground Image.asset now excludeFromSemantics + frameBuilder AnimatedOpacity decode fade (AppMotion.base) (safe)
- onboarding_page.dart: strengthened top scrim gradient stops 0.45->0.6 and 0.15->0.2 (bottom 0.88 unchanged), still derived from scrim token (safe)
- onboarding_page.dart: headline+body wrapped in AnimatedSwitcher (AppMotion.slow) keyed on step, layoutBuilder Stack aligned AlignmentDirectional.centerStart for RTL (medium)
- onboarding_page.dart: added import '../../../../core/theme/motion.dart' for AppMotion
- splash_page.dart: wrapped splash logo in Semantics(label: appTitle, image: true) + excludeFromSemantics on inner Image; added import '../../../../l10n/app_localizations.dart' (safe)

**Deferred (in REVIEW.md):** onboarding_page.dart high-risk overflow-safe re-parent of the bottom Column (Spa

## login + guest  · `ca93628`
_Files (1):_ `login_page.dart`

**Changes made:**
- Added imports: flutter_animate, flutter_lucide, core/theme/motion.dart, core/widgets/reduce_motion.dart (alphabetical within existing groups).
- Edit 1 (safe): wrapped the _errorText message in Semantics(liveRegion:true, container:true) with a leading LucideIcons.circle_alert glyph (size AppSpacing.lg, colors.error) in a centered Row + Flexible Text — screen readers now announce login failures and the signal is no longer color-only. Same _errorText string/conditional.
- Edit 4 (medium): added `bool _obscure = true;` state and a show/hide affordance via authFieldDecoration(context, suffixIcon: IconButton(...)) toggling _obscure; icon LucideIcons.eye/eye_off, tooltip l10n.password_show/password_hide; obscureText now bound to _obscure.
- Edit 3 (medium): added a reduced-motion-aware entrance on the logo/headline/subtitle cluster only — extracted into a `header` Column (crossAxisAlignment.stretch to preserve layout) and, when !reduceMotion(context), applied .animate().fadeIn(AppMotion.slow).slideY(begin:0.06,end:0,duration:AppMotion.slow,curve:AppMotion.curve). Fields untouched.
- Edit 2 (medium): promoted the guest path to a token-clean outlined AppButton (variant.outlined, expanded, icon LucideIcons.store) placed directly under the primary Sign In CTA, with the Register text link moved below it; replaced the muted Material Icons.storefront_outlined/size:18 TextButton.icon. onPressed targets unchanged (guest->context.go(home), register->context.push(register)). Action gaps raised sm->md for clearer grouping.

## auth status screens  · `5d1f2ca`
_Files (4):_ `auth_status_message.dart`, `rejected_page.dart`, `suspended_page.dart`, `reset_password_page.dart`

**Changes made:**
- auth_status_message.dart: wrapped the centred Column in StaggeredListItem(index: 0) for the app-standard reduced-motion-aware fade+slide entrance; added core/widgets/staggered_list_item.dart import
- auth_status_message.dart: changed the message paragraph colour from colors.textMuted to colors.onSurfaceVariant (higher-contrast secondary ink)
- auth_status_message.dart: tone-tinted the warning/error badge circle via colors.warning/error.withValues(alpha: 0.12) instead of neutral surfaceVariant; neutral tone unchanged
- auth_status_message.dart: wrapped the title Text in Semantics(header: true) for a screen-reader h1 landmark
- auth_status_message.dart: added optional 'final Widget? action' constructor param, rendered below the message after an AppSpacing.xl gap (defaults null, pending/publisher-pending unchanged)
- rejected_page.dart: passed an in-content outlined 'Sign Out' AppButton to AuthStatusMessage.action reusing the existing LogoutRequested event + sign_out key; removed the now-redundant AppBar TextButton; added core/widgets/app_button.dart import
- suspended_page.dart: same as rejected — in-content outlined 'Sign Out' AppButton via action (LogoutRequested + sign_out), removed the redundant AppBar TextButton; added app_button import
- reset_password_page.dart: replaced the bespoke _GenericResponse with AuthStatusMessage(icon: LucideIcons.mail_check, message: reset_password_generic_response) and deleted the _GenericResponse class; added ../widgets/auth_status_message.dart import

## create/edit listing  · `0e155f2`
_Files (11):_ `media_thumbnail.dart`, `media_picker.dart`, `express_form_fields.dart`, `listing_express_form_page.dart`, `step_review.dart`, `price_preview_subline.dart`, `listing_detail_form_page.dart`, `step_basics.dart`, `step_details.dart`, `step_prices.dart`, `step_visibility.dart`

**Changes made:**
- media_thumbnail.dart (safe/RTL): main + ordering badges switched from raw Positioned(right/left) to PositionedDirectional(end/start) so they mirror in Arabic.
- media_picker.dart (safe/empty-state): _EmptyState now shows mediaEmptyStateTitle (titleMedium/onSurface) + mediaEmptyStateHint (bodyMedium/textMuted) instead of the misused reorder hint.
- express_form_fields.dart (safe/a11y+contrast): _PurposePill wrapped in Semantics(button+selected+label), onTap fires HapticFeedback.selectionClick(), idle label color textMuted -> onSurfaceVariant.
- listing_express_form_page.dart (safe/contrast): _ExpressHint zap icon + text recolored to onPrimaryContainer over the primaryContainer fill.
- step_review.dart (safe/touch-target): _ChecklistRow wrapped in ConstrainedBox(minHeight: kAppMinTouchTarget) so the jump-to-field row is >=48dp.
- price_preview_subline.dart (safe/typography): moved off Theme.textTheme onto AppTextStyles (bodyMedium/textMuted label + titleMedium/onSurface value) with an AppSpacing.xs gap between label and value.
- listing_express_form_page.dart + listing_detail_form_page.dart (safe/elevation): both fixed _SubmitBar footers add boxShadow: elevation.level1 (import elevation.dart) to match the Classic _BottomNav lift.
- listing_express_form_page.dart + listing_detail_form_page.dart (medium/error-state): split the loadInProgress||!isReady guard so a failed draft-create shows state.lastSaveError ?? listingFormLoadingMessage instead of an infinite spinner.
- step_basics / step_prices / step_details / step_visibility (medium/consistency): every bare InputDecoration(border: OutlineInputBorder()) routed through the shared expressDecoration(context) (with error:/collapseHeight: where applicable); step_location AppTextField left untouched.
- express_form_fields.dart (medium/inline-error): added local _amountError/_areaError/_phoneError, wired via PriceValidator/AreaSizeValidator/PhoneValidator (already used by Detail) into expressDecoration error:; dispatched FieldChanged events unchanged (phone still dispatches raw v).

## my listings + publisher  · `89aa814`
_Files (4):_ `my_listings_page.dart`, `listing_card.dart`, `status_filter_chip_row.dart`, `publisher_dashboard_page.dart`

**Changes made:**
- listing_card.dart (safe): untitled fallback title now uses l10n.myListingsUntitledListing instead of the misused myListingsEmptyTitle
- listing_card.dart (safe): prefixed the created-date line with a muted LucideIcons.calendar (size AppSpacing.md, colors.textMuted) inside a Row to match the expiry row's icon+label idiom
- status_filter_chip_row.dart (safe): wrapped the row in a DecoratedBox with a BorderDirectional bottom hairline (colors.outline); switched padding to EdgeInsetsDirectional.symmetric; added HapticFeedback.selectionClick() before ChangeStatusFilter (added flutter/services.dart + core/theme/colors.dart imports)
- publisher_dashboard_page.dart (safe): replaced raw SizedBox(height: 240) around the summary ErrorState with height: AppSpacing.xxxl * 5 (== 240)
- my_listings_page.dart (medium): replaced the bare AppSpinner.page() initial-load branch with a new _MyListingsSkeleton (5x LoadingState.card in a non-scrollable ListView); added loading_state.dart import; kept AppSpinner import for the pagination footer
- my_listings_page.dart (medium): wrapped the ListView.builder _ListingRow in StaggeredListItem(index: index, child: ...) for a subtle reduced-motion-aware entrance; pagination footer spinner left unwrapped; added staggered_list_item.dart import
- my_listings_page.dart (medium): differentiated the empty state — _EmptyBody now takes statusFilter; filtered-empty renders funnel_x + myListingsFilteredEmptyTitle + a 'Show all' CTA that dispatches the existing ChangeStatusFilter(null); truly-empty adds the myListingsEmptyBody supporting line

## comparison  · `25170d5`
_Files (3):_ `comparison_page.dart`, `compare_bottom_bar.dart`, `compare_toggle_button.dart`

**Changes made:**
- comparison_page.dart _PropertyColumn: difference now encoded by weight AND hue (differ=primary+w700, match=onSurface+w500) so it isn't colour-only
- comparison_page.dart _EmptyHint: replaced bespoke Center/Column with shared EmptyState (icon scale, headline comparisonEmptyTitle, body comparisonEmptyHint); dropped now-unused colors param + removed unused local colors in ComparisonPage.build; added empty_state import
- comparison_page.dart _ComparisonBody: wrapped each _PropertyColumn in StaggeredListItem (indexed loop) for a reduced-motion-aware fade/slide entrance; added staggered_list_item import
- comparison_page.dart _LabelColumn: row-label text colors.textMuted -> colors.onSurfaceVariant (>=4.5:1); leading icon left muted as decorative cue
- comparison_page.dart: inter-row separators colors.outline -> colors.divider in both _LabelColumn and _PropertyColumn (card outer border stays outline)
- comparison_page.dart _RemoveColumnButton: added HapticFeedback.selectionClick() on remove tap; added flutter/services import
- compare_bottom_bar.dart: inline clear now a 48dp SizedBox.square hit area wrapped in Tooltip(comparisonClearAll) instead of an xs-padded ~24dp icon
- compare_toggle_button.dart: blocked (cap-reached) tooltip now reads comparisonMaxReached instead of the misleading Add-to-compare; added HapticFeedback.selectionClick() on toggle; added flutter/services import

**Deferred (in REVIEW.md):** Swap raw AppBar for design-system AppAppBar in comparison_page.dart (variant wit

## notifications  · `6a159b4`
_Files (3):_ `notification_bell_action.dart`, `notification_tile.dart`, `notification_center_page.dart`

**Changes made:**
- bell_action: made _Badge token-clean (AppColors.of + AppTextStyles.labelMedium w700, dropped raw colorScheme/textTheme and inline fontSize:10; padding xs->xxs to keep it compact) [medium]
- bell_action: count-aware IconButton tooltip -> notification_unread_count_a11y(count) when count>0, else existing notification_bell_tooltip [safe]
- tile: wrapped unread dot in Semantics(label: notification_unread_a11y); dot Container unchanged [safe]
- tile: added _colorForType helper (approvals->success, rejections->error, else primary) for the leading glyph; read-row circle bg -> surfaceVariant, unread stays surface [medium]
- tile: added bottom hairline via DecoratedBox(BorderDirectional(bottom: BorderSide(color: colors.divider))) between InkWell and Padding; re-indented Row children for the new nesting level [medium]
- center: replaced AppSpinner.page() on initial/loading with new _NotificationsSkeleton (ListView.separated, avatar + 2 lines, second line FractionallySizedBox 0.5, NeverScrollable) [medium]
- center: wrapped each NotificationTile in StaggeredListItem(index: index, enabled: !state.isPaginating); onTap/resolver unchanged [medium]
- center: _DateHeader now shows Today/Yesterday for the two freshest buckets via _dateLabel() (notification_date_today/_yesterday), full localized date otherwise [safe]
- center: added body: notification_empty_state_body to the EmptyState [safe]
- center: mark-all-read TextButton -> TextButton.icon with Icons.done_all + HapticFeedback.selectionClick(); same markAllRead()/badge.clear() calls [safe]
- center: RefreshIndicator color: colors.primary (added local final colors after the empty-check) [safe]

## inquiries  · `cb2877b`
_Files (5):_ `inquiry_inbox_page.dart`, `admin_inquiry_oversight_page.dart`, `inquiry_detail_page.dart`, `admin_tier_banner.dart`, `inbox_skeleton.dart`

**Changes made:**
- Extracted the private _InboxSkeleton into a new shared public widget lib/.../widgets/inbox_skeleton.dart (verbatim tokens); removed now-unused loading_state.dart import from the inbox page (medium)
- inquiry_inbox_page: Loading branch now const InboxSkeleton() (medium)
- admin_inquiry_oversight_page: Loading branch AppSpinner.page() -> const InboxSkeleton() so admin skeletons like the publisher inbox; kept app_spinner import for the load-more sentinel (medium)
- admin_inquiry_oversight_page: bare Center(Text) empty branch -> EmptyState(icon: LucideIcons.inbox, headline: reused key) (safe)
- inquiry_inbox_page + admin: wrapped each row (_InquiryRowTile / _AdminInquiryRowTile) in StaggeredListItem(index, child) matching favorites idiom (medium)
- inquiry_inbox_page + admin: added leading unread dot (Container circle, colors.primary, EdgeInsetsDirectional margin) shown only when status == InquiryStatus.new_ (medium)
- inquiry_inbox_page + admin: listing-title line now leads with a muted LucideIcons.house glyph + xs gap, wrapped in Expanded to keep ellipsis (safe)
- admin_inquiry_oversight_page: AppBar icons Icons.filter_list -> LucideIcons.funnel and Icons.person_outlined -> LucideIcons.user (safe)
- admin_tier_banner: Icons.admin_panel_settings_outlined -> LucideIcons.shield_check, size/color unchanged (safe)
- inquiry_detail_page: message card now Column[ muted labelMedium l10n.inquiry_form_message_label, xs gap, bodyLarge message ] (safe)
- inquiry_detail_page: sender name titleMedium -> titleLarge (keeps w700) (safe)
- inquiry_detail_page: call affordance IconButton -> AppButton(tonal, dense, LucideIcons.phone, label reuses inquiry_detail_tap_to_call_action) with identical tel: launchUrl onPressed (medium)
- inquiry_detail_page: listing-ref Icon home_outlined -> LucideIcons.house and Add-to-CRM icon handshake_outlined -> LucideIcons.handshake (medium)
- inquiry_detail_page: wrapped listing-ref Row in ConstrainedBox(minHeight: kAppMinTouchTarget) for the 48dp target (safe)

## viewings  · `69a17b5`
_Files (2):_ `viewings_list_page.dart`, `request_viewing_sheet.dart`

**Changes made:**
- viewings_list_page: swapped imports — dropped unused app_spinner.dart, added loading_state.dart + staggered_list_item.dart
- viewings_list_page: initial/loading now render a 5-item LoadingState.card skeleton list (same lg padding + md gaps) instead of a bare AppSpinner.page() (medium)
- viewings_list_page: populated list wrapped in RefreshIndicator(color: colors.primary, onRefresh: existing cubit.load()) and each card wrapped in StaggeredListItem(index: i); added AlwaysScrollableScrollPhysics so pull works on short lists (medium + stagger safe)
- viewings_list_page: promoted the scheduled date/time row — clock icon colors.primary, 'when' text bodyLarge/onSurface/FontWeight.w600 (was bodyMedium/onSurfaceVariant) so rank reads title > time > note (safe)
- viewings_list_page: wrapped the _ViewingCard Column in Semantics(container: true) so each viewing reads as one grouped a11y item (safe)
- viewings_list_page: cancelled status pill label color textMuted -> onSurfaceVariant for >=4.5:1 contrast while staying the quietest pill (safe)
- request_viewing_sheet: added a trailing LucideIcons.chevron_down (size xl, colors.textMuted) affordance to _PickerField after the Expanded label, RTL-safe non-directional glyph (safe)

## settings + about  · `c471e89`
_Files (5):_ `about_support_page.dart`, `maintenance_screen.dart`, `support_contact_row.dart`, `app_settings_editor_page.dart`, `settings_section_header.dart`

**Changes made:**
- about_support_page.dart: added imports flutter/services.dart, core/widgets/empty_state.dart, core/widgets/staggered_list_item.dart
- about_support_page.dart: removed now-unused `colors`/`styles` locals from build() (still used by _LinkTile + _SettingsSection so imports stay live)
- about_support_page.dart: replaced bare centered Text empty branch with shared EmptyState(icon: Icons.support_agent, headline: about_empty_title, body: about_no_info)
- about_support_page.dart: built a local `sections` list (keeps existing if-conditionals) and wrapped each section in StaggeredListItem(index: i) for the subtle stagger entrance; ListView padding unchanged
- about_support_page.dart: added HapticFeedback.selectionClick() to _LinkTile.onTap before launchUrl (optional consistency tick; behavior unchanged)
- maintenance_screen.dart: added core/widgets/staggered_list_item.dart import
- maintenance_screen.dart: wrapped the min-size Column in StaggeredListItem(index: 0) and replaced the bare Icons.build_outlined with a primary-tinted circle Container glyph (matches EmptyState/ErrorState idiom); done as one combined block replacement, all children/behavior preserved
- support_contact_row.dart: added flutter/services.dart import and fired HapticFeedback.selectionClick() before the unawaited launchUrl (same externalApplication launch)
- app_settings_editor_page.dart: added core/widgets/error_state.dart import and replaced the bespoke Center/Column error branch (plain Text + raw FilledButton) with shared ErrorState(title: settingsEditorLoadError, onRetry: load()) — same retry target
- settings_section_header.dart: tokenized header — AppColors/AppTextStyles instead of Theme.of, EdgeInsetsDirectional.only instead of EdgeInsets.only, styles.titleMedium.copyWith(color: colors.primary, w700), Divider colored with colors.divider

## reports  · `83ee9ee`
_Files (4):_ `my_reports_page.dart`, `report_sheet.dart`, `reporter_status_banner.dart`, `report_status_chip.dart`

**Changes made:**
- my_reports_page.dart: replaced bare AppSpinner.page() initial-load with a _ReportsLoadingSkeleton (6x LoadingState.card list) matching other list surfaces (medium)
- my_reports_page.dart: wrapped each list row in StaggeredListItem(index:) for a subtle reduced-motion-aware entrance (safe)
- my_reports_page.dart: wrapped card Row in MergeSemantics (single a11y node) + added HapticFeedback.selectionClick() in onTap; kept the same context.push target (safe)
- my_reports_page.dart: added imports flutter/services.dart, loading_state.dart, staggered_list_item.dart
- report_sheet.dart: EdgeInsets.only(left/right) -> EdgeInsetsDirectional.only(start/end) for RTL convention (safe)
- report_sheet.dart: wrapped the mainAxisSize.min Column in SingleChildScrollView to prevent keyboard-open RenderFlex overflow (safe)
- report_sheet.dart: added muted report_sheet_subtitle reassurance line under the title (xs gap) + colors import/var (safe)
- reporter_status_banner.dart: deduped status - Expanded Text now uses status-free report_banner_status_label, colored ReportStatusChip is the single status signal; removed now-unused _statusLabel() and its report_status.dart import (medium)
- reporter_status_banner.dart: banner fill colors.card -> colors.surfaceVariant so it reads as a passive callout vs content cards (safe)
- report_status_chip.dart: added `ink` (dismissed -> onSurfaceVariant, else tint) for the label; background/border keep the muted tint (safe)

