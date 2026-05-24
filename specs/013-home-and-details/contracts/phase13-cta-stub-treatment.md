# Contract: CTA Stub Treatment (Q1=A + Q2=A + Q3=A)

**Paths**: `lib/features/home/presentation/widgets/*.dart` + `lib/features/listing_details/presentation/widgets/*.dart`
**Implements**: FR-013 (Q1=A), FR-021 (Q2=A), FR-028 (Q3=A reserved keys)
**Verifies**: SC-029, SC-030, SC-031

## Unified stub treatment

Phase 13 stubs **8 surfaces** that later phases will wire:

| # | Surface | Q | Coming-soon ARB key | Tap behavior |
|---|---|---|---|---|
| 1 | `_HeroSearchBar` | Q1=A | `home_search_coming_soon` | Snackbar; NO navigation |
| 2 | Each of 8 `_PropertyTypeShortcutRow` chips | Q1=A | `home_property_shortcut_coming_soon` (parameterized over the type label) | Snackbar; NO navigation |
| 3 | `_ContactBlock` Call CTA | Q2=A | `contact_call_coming_soon` | Snackbar; NO `tel:` launch |
| 4 | `_ContactBlock` WhatsApp CTA | Q2=A | `contact_whatsapp_coming_soon` | Snackbar; NO `wa.me/` launch |
| 5 | `_ContactBlock` Send-inquiry CTA | Q2=A | `contact_inquiry_coming_soon` | Snackbar; NO inquiry form |
| 6 | `_PerListingActionBlock` Favorite CTA | Q2=A | `action_favorite_coming_soon` | Snackbar; NO favorites mutation |
| 7 | `_PerListingActionBlock` Share CTA | Q2=A | `action_share_coming_soon` | Snackbar; NO OS share sheet |
| 8 | `_PerListingActionBlock` Report CTA | Q2=A | `action_report_coming_soon` | Snackbar; NO report submission |

## Tap-handler implementation pattern

```dart
void _showComingSoon(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,  // per Phase 2 design token
    ),
  );
}

// Usage in _HeroSearchBar:
onTap: () {
  FocusScope.of(context).unfocus();  // dismiss keyboard if open
  _showComingSoon(context, AppLocalizations.of(context).homeSearchComingSoon);
},

// Usage in property-type chip:
onTap: () {
  _showComingSoon(
    context,
    AppLocalizations.of(context).homePropertyShortcutComingSoon(
      AppLocalizations.of(context).propertyType_apartment,  // or whichever key matches the chip
    ),
  );
},

// Usage in any Q2=A CTA (e.g., Call):
onPressed: () {
  _showComingSoon(context, AppLocalizations.of(context).contactCallComingSoon);
},
```

## Q3=A reserved keys (forward-state)

Phase 13's ARB delta includes two keys that Phase 13 itself does NOT surface — they are reserved for the first future-phase consumer of an auth-required CTA:

- `auth_required_please_sign_in` — snackbar message body
- `auth_required_sign_in_action` — snackbar action button label

When a later phase (Phase 16 inquiry wiring; future favorites/reports phases) wires an auth-required CTA, the wired tap-handler MUST:

```dart
onPressed: () {
  final authStatus = context.read<AuthBloc>().state.status;
  if (authStatus == AuthStatus.anonymous) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).authRequiredPleaseSignIn),
        action: SnackBarAction(
          label: AppLocalizations.of(context).authRequiredSignInAction,
          onPressed: () => context.go(AppRoutes.login),
        ),
      ),
    );
  } else {
    // Perform the wired action.
  }
};
```

This pattern is the project-wide UX convention; the wiring phase's plan/spec MUST cite Q3=A by reference.

## Verification

### Manual (per SC-029, SC-030)

For each of the 8 surfaces, tap the surface on the Infinix Note 8 in `ar` AND `en` and confirm the localized snackbar appears AND no navigation / external launch / Supabase mutation occurs.

### Grep (per SC-030)

```bash
grep -RE "url_launcher\.launch.*tel:" lib/features/listing_details/presentation/
# Expected: 0 matches.

grep -RE "url_launcher\.launch.*wa\.me|url_launcher\.launch.*api\.whatsapp" lib/features/listing_details/presentation/
# Expected: 0 matches.

grep -R "share_plus" pubspec.yaml
# Expected: 0 matches. (Per FR-033, share_plus is NOT added in Phase 13.)

grep -RE "from\('favorites'\)|from\('inquiries'\)|from\('reports'\)" lib/features/listing_details/
# Expected: 0 matches. (No mutation on future-phase tables in Phase 13.)
```

### Inspection (per SC-031)

Confirm the two Q3=A keys are present in BOTH `lib/l10n/app_ar.arb` AND `lib/l10n/app_en.arb` even though Phase 13 itself does not surface them. This is the forward-state contract.

## Constitution compliance

- **V** (l10n): every snackbar message flows through `AppLocalizations`.
- **VI** (design tokens): snackbar shape per Phase 2 floating-snackbar behavior token.
- **IX** (Supabase isolation): stub tap-handlers contain ZERO Supabase calls.
- **XII** (no hidden product decisions): the 8 stubs are documented; the Q3=A forward-state convention is documented; rejected alternatives in spec.md Clarifications cover the rationale.
