// integration_test/primary_publish_path_test.dart
//
// Phase 24 QV (T031) — the ONE sanctioned integration test.
// Exercises the full primary-publish golden path end-to-end:
//   register → admin-approve user → publish listing → admin-approve listing
//   → public view listing → send inquiry
//
// ─── BACKEND PREREQUISITE (operator/runner must seed before executing) ─────────
//
// This test requires a live/staging Supabase backend (reachable via the
// dart-define values in .env.json). It is NOT a unit test and CANNOT pass
// without a seeded backend. Run as:
//
//   flutter test integration_test/primary_publish_path_test.dart \
//     --dart-define-from-file=.env.json
//
// Prerequisites the operator/runner MUST provision before this test runs:
//
//  1. ADMIN SESSION (service-role SQL or super-admin UI, NOT the app UI):
//     An admin user already exists with at minimum the permissions
//     `users.approve` AND `listings.approve`. The test drives admin approval
//     steps through the app UI logged in as that admin; its credentials are
//     supplied via dart-defines:
//       TEST_ADMIN_PHONE    — e.g. "+9630000000001" (pre-approved admin account)
//       TEST_ADMIN_PASSWORD
//
//  2. FRESH REGISTERABLE PHONE (synthetic-email pattern; must NOT already exist):
//       TEST_NEW_USER_PHONE    — e.g. "+9630099991234"
//       TEST_NEW_USER_PASSWORD
//     After the test the account and all its listings will be left in the DB.
//     To make the test re-runnable, delete the user before each run via
//     service-role SQL:
//       DELETE FROM auth.users WHERE phone = '<TEST_NEW_USER_PHONE>';
//     or use a different phone number each time.
//
//  3. DETERMINISTIC LISTING DATA:
//     The listing form submits a minimal listing. The location dropdowns
//     (governorate / city / area) must have at least one entry each in the
//     live DB. The test picks the first available entry in each dropdown.
//
//  4. NETWORK ACCESS:
//     The Supabase project URL and anon key must be available at runtime via
//     --dart-define-from-file=.env.json (memory project_dart_defines).
//     Without them Supabase.initialize is skipped and the app red-screens.
//
// NOTE: T032 (running this test green on the Pixel 8 Pro AVD with a seeded
// backend) is a SEPARATE task that stays PARTIAL until executed on-device.
// This file is T031 — it is analyze-clean and structurally correct, but its
// green outcome has NOT been verified here.
//
// ─── RESET PROCEDURE (idempotent re-run) ──────────────────────────────────────
//
//   -- Run via service-role client before each test execution:
//   DELETE FROM auth.users WHERE phone = '<TEST_NEW_USER_PHONE>';
//   -- This cascades to account_approval_requests and listings for that user.
//
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:alnujom/main.dart' as app;

// ── Dart-define shims for test credentials ─────────────────────────────────
// The runner supplies these via --dart-define or --dart-define-from-file.
// Defaults are empty; the test skips if absent so it never accidentally
// passes on a misconfigured CI environment.
const _kAdminPhone = String.fromEnvironment('TEST_ADMIN_PHONE');
const _kAdminPassword = String.fromEnvironment('TEST_ADMIN_PASSWORD');
const _kNewUserPhone = String.fromEnvironment('TEST_NEW_USER_PHONE');
const _kNewUserPassword = String.fromEnvironment('TEST_NEW_USER_PASSWORD');

// ── Timeout constants ───────────────────────────────────────────────────────
// Network round-trips to a remote Supabase project can be slow on an emulator.
// pumpAndSettle() does not accept a timeout parameter; use pump(duration) to
// give the network time before calling pumpAndSettle() without args.
const _kNetworkWait = Duration(seconds: 20);
const _kShortWait = Duration(seconds: 3);

bool get _credentialsMissing =>
    _kAdminPhone.isEmpty ||
    _kAdminPassword.isEmpty ||
    _kNewUserPhone.isEmpty ||
    _kNewUserPassword.isEmpty;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Primary publish path (golden path 1)', () {
    // ── Phase 1: Register a new user ───────────────────────────────────────
    testWidgets(
      '1. new user can register and reaches pending-approval screen',
      (tester) async {
        if (_credentialsMissing) {
          markTestSkipped(
            'TEST_ADMIN_PHONE / TEST_ADMIN_PASSWORD / '
            'TEST_NEW_USER_PHONE / TEST_NEW_USER_PASSWORD not provided',
          );
          return;
        }

        unawaited(app.main());
        // Wait for bootstrap (DI + Supabase init + locale load).
        await tester.pump(_kNetworkWait);
        await tester.pumpAndSettle();

        // ── Navigate to login, then register ───────────────────────────
        // The app may open on the home feed or directly on login/onboarding.
        // If we see a "Sign in to publish" empty-state button on the home feed,
        // tap it to get to login; otherwise look for the login page directly.
        //
        // TODO(qv): add Key('home_sign_in_to_publish_button') to the empty-state
        // OutlinedButton in home_page.dart so this navigation is key-stable.
        final signInToPublish = find.text('Sign in to publish');
        if (signInToPublish.evaluate().isNotEmpty) {
          await tester.tap(signInToPublish.first);
          await tester.pumpAndSettle();
        }

        // On the login page tap the "Create Account" text-button.
        // l10n.login_no_account is the "don't have an account?" link that
        // navigates to /register via context.push(AppRoutes.register).
        // TODO(qv): add Key('login_go_to_register_button') to that TextButton
        // in login_page.dart for a stable finder.
        final goToRegister = find.widgetWithText(TextButton, 'Create Account');
        if (goToRegister.evaluate().isNotEmpty) {
          await tester.tap(goToRegister.first);
          await tester.pumpAndSettle();
        }

        // ── Fill registration form ──────────────────────────────────────
        // Phone field — l10n.register_phone_label.
        // TODO(qv): add Key('register_phone_field') to the phone TextFormField
        // in register_page.dart for a stable finder.
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Phone number').first,
          _kNewUserPhone,
        );
        // Password field — l10n.register_password_label.
        // TODO(qv): add Key('register_password_field') to the password field.
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Password').first,
          _kNewUserPassword,
        );

        // Submit — l10n.register_submit = "Create Account" (FilledButton).
        await tester.tap(
          find.widgetWithText(FilledButton, 'Create Account').first,
        );
        await tester.pump(_kNetworkWait);
        await tester.pumpAndSettle();

        // ── Assert: pending-approval screen ────────────────────────────
        // After registration a new user is redirected to the pending-approval
        // page (l10n.pending_approval_title = "Account Pending Approval").
        // TODO(qv): add Key('pending_approval_scaffold') to PendingApprovalPage
        // so this assertion does not rely solely on text matching.
        expect(
          find.text('Account Pending Approval'), // l10n.pending_approval_title
          findsOneWidget,
          reason: 'Newly registered user should see the pending-approval page.',
        );
      },
    );

    // ── Phase 2: Admin approves the new user ───────────────────────────────
    // The admin uses the app UI to approve the pending account.
    // We sign out the new user (via the sign-out action on the pending-approval
    // page) and sign in as admin.
    testWidgets(
      '2. admin can log in and approve the pending user',
      (tester) async {
        if (_credentialsMissing) {
          markTestSkipped('credentials missing');
          return;
        }

        unawaited(app.main());
        await tester.pump(_kNetworkWait);
        await tester.pumpAndSettle();

        // Sign out any existing session.
        await signOutIfNeeded(tester);

        // Log in as admin.
        await loginAs(tester, _kAdminPhone, _kAdminPassword);

        // Navigate to the admin home from the home feed.
        // The home page has an admin-icon navigation action in the AppBar.
        // TODO(qv): add Key('admin_home_nav_action') to the admin IconButton on
        // home_page.dart so this navigation is key-stable.
        await tester.tap(
          find.byIcon(Icons.admin_panel_settings_outlined).first,
        );
        await tester.pumpAndSettle();

        // Tap the "Pending Approvals" tile on the admin home grid.
        // l10n.admin_tile_account_approvals = "Pending Approvals".
        // TODO(qv): add Key('admin_tile_account_approvals') to DashboardTile
        // when section.counterKey == 'pendingUsers'.
        await tester.tap(find.text('Pending Approvals').first);
        await tester.pump(_kNetworkWait);
        await tester.pumpAndSettle();

        // The AccountApprovalsPage shows a card per pending user.
        // Tap the Approve FilledButton (l10n.admin_action_approve = "Approve").
        // TODO(qv): add Key('approve_user_button_<userId>') to the FilledButton
        // in _RequestCard in account_approvals_page.dart for targeted approval.
        await tester.tap(
          find.widgetWithText(FilledButton, 'Approve').first,
        );
        await tester.pump(_kNetworkWait);
        await tester.pumpAndSettle();

        // The approved user's phone number should no longer appear in the queue.
        expect(
          find.text(_kNewUserPhone),
          findsNothing,
          reason: 'Approved user should no longer appear in the pending queue.',
        );
      },
    );

    // ── Phase 3: Approved user publishes a listing ─────────────────────────
    testWidgets(
      '3. approved user can create and submit a listing for review',
      (tester) async {
        if (_credentialsMissing) {
          markTestSkipped('credentials missing');
          return;
        }

        unawaited(app.main());
        await tester.pump(_kNetworkWait);
        await tester.pumpAndSettle();

        // Sign out admin, log in as the newly-approved user.
        await signOutIfNeeded(tester);
        await loginAs(tester, _kNewUserPhone, _kNewUserPassword);

        // After approval the user should reach the home feed (not pending page).
        // The FAB (Icons.add_home_outlined) is shown for approved publishers.
        // TODO(qv): add Key('create_listing_fab') to the FAB in home_page.dart.
        await tester.tap(find.byIcon(Icons.add_home_outlined).first);
        await tester.pumpAndSettle();

        // ── Fill listing form (multi-step wizard) ───────────────────────
        // Step 1 (Basics) — enter a title.
        // TODO(qv): add Key('listing_title_field') to the title TextFormField
        // in step_basics.dart.
        final titleField = find.widgetWithText(TextFormField, 'Title');
        if (titleField.evaluate().isNotEmpty) {
          await tester.enterText(titleField.first, 'QV Test Listing');
        }

        // Advance through wizard steps.
        // TODO(qv): add Key('listing_form_next_button') to each step-navigation
        // FilledButton in listing_form_page.dart for stable advancement.
        await tapNextOrContinue(tester);
        await tapNextOrContinue(tester);
        await tapNextOrContinue(tester);
        await tapNextOrContinue(tester);
        await tapNextOrContinue(tester);
        await tapNextOrContinue(tester);

        // Final step — tap the submit FilledButton.
        // TODO(qv): add Key('listing_form_submit_button') to the submit
        // FilledButton on the review step in listing_form_page.dart.
        final submitBtn = find.widgetWithText(FilledButton, 'Submit listing');
        if (submitBtn.evaluate().isNotEmpty) {
          await tester.tap(submitBtn.first);
          await tester.pump(_kNetworkWait);
          await tester.pumpAndSettle();
        }

        // Success snackbar: l10n.listingFormSubmitSuccess.
        expect(
          find.text('Listing submitted for review.'),
          findsOneWidget,
          reason: 'Submit should show the success snackbar.',
        );
      },
    );

    // ── Phase 4: Admin approves the listing ────────────────────────────────
    testWidgets(
      '4. admin can approve the submitted listing',
      (tester) async {
        if (_credentialsMissing) {
          markTestSkipped('credentials missing');
          return;
        }

        unawaited(app.main());
        await tester.pump(_kNetworkWait);
        await tester.pumpAndSettle();

        await signOutIfNeeded(tester);
        await loginAs(tester, _kAdminPhone, _kAdminPassword);

        // Navigate to admin home.
        await tester.tap(
          find.byIcon(Icons.admin_panel_settings_outlined).first,
        );
        await tester.pumpAndSettle();

        // Tap the "Pending review" tile — l10n.adminTilePendingReview.
        // TODO(qv): add Key('admin_tile_listing_review') to the DashboardTile
        // for the listing-review section.
        await tester.tap(find.text('Pending review').first);
        await tester.pump(_kNetworkWait);
        await tester.pumpAndSettle();

        // Tap the first card in the pending-review queue (PendingQueueCard).
        // TODO(qv): add Key('pending_queue_card_<id>') to PendingQueueCard in
        // pending_queue_card.dart for targeted selection.
        await tester.tap(find.byType(Card).first);
        await tester.pump(_kNetworkWait);
        await tester.pumpAndSettle();

        // On the listing preview page, tap the Approve button.
        // l10n.adminPreviewCtaApprove = "Approve" (FilledButton in _StickyBottomBar).
        // TODO(qv): add Key('listing_preview_approve_button') to the FilledButton
        // in _StickyBottomBar in listing_preview_page.dart.
        await tester.tap(
          find.widgetWithText(FilledButton, 'Approve').first,
        );
        await tester.pumpAndSettle();

        // Approve-confirmation dialog appears.
        // l10n.adminApproveDialogConfirm = "Approve" (the last FilledButton in the
        // dialog, since the page's bottom bar is behind the dialog overlay).
        await tester.tap(
          find.widgetWithText(FilledButton, 'Approve').last,
        );
        await tester.pump(_kNetworkWait);
        await tester.pumpAndSettle();

        // A SnackBar with l10n.adminToastApproveSuccess is shown.
        expect(
          find.byType(SnackBar),
          findsOneWidget,
          reason: 'Approve should show a success SnackBar.',
        );
      },
    );

    // ── Phase 5: Public user views the approved listing ────────────────────
    testWidgets(
      '5. approved listing appears in the public feed and opens correctly',
      (tester) async {
        if (_credentialsMissing) {
          markTestSkipped('credentials missing');
          return;
        }

        unawaited(app.main());
        await tester.pump(_kNetworkWait);
        await tester.pumpAndSettle();

        // Sign out so we browse as an unauthenticated visitor.
        await signOutIfNeeded(tester);
        await tester.pump(_kNetworkWait);
        await tester.pumpAndSettle();

        // The approved listing should appear in the home feed.
        // TODO(qv): add Key('home_listing_card_<id>') to HomeListingCardTile
        // so the target card can be found by stable key rather than title text.
        expect(
          find.text('QV Test Listing'),
          findsAtLeast(1),
          reason: 'Approved listing should appear in the public home feed.',
        );

        await tester.tap(find.text('QV Test Listing').first);
        await tester.pump(_kNetworkWait);
        await tester.pumpAndSettle();

        // Listing details page displays the title (headlineSmall typography token).
        expect(
          find.text('QV Test Listing'),
          findsAtLeast(1),
          reason: 'Listing details page should display the listing title.',
        );
      },
    );

    // ── Phase 6: Non-publisher sends an inquiry ─────────────────────────────
    // Note: the ContactBlock collapses (self-contact guard — FR-001d) when the
    // signed-in user IS the publisher. We log in as admin (a different account)
    // to exercise the Send Inquiry CTA (l10n.cta_send_inquiry).
    testWidgets(
      '6. non-publisher can send an inquiry from the listing details page',
      (tester) async {
        if (_credentialsMissing) {
          markTestSkipped('credentials missing');
          return;
        }

        unawaited(app.main());
        await tester.pump(_kNetworkWait);
        await tester.pumpAndSettle();

        // Sign in as admin — a different account from the publisher.
        await signOutIfNeeded(tester);
        await loginAs(tester, _kAdminPhone, _kAdminPassword);

        await tester.pump(_kNetworkWait);
        await tester.pumpAndSettle();

        // Navigate to the approved listing.
        expect(
          find.text('QV Test Listing'),
          findsAtLeast(1),
          reason: 'Listing must be present in the feed.',
        );
        await tester.tap(find.text('QV Test Listing').first);
        await tester.pump(_kNetworkWait);
        await tester.pumpAndSettle();

        // Tap the "Send inquiry" OutlinedButton — l10n.cta_send_inquiry.
        // TODO(qv): add Key('cta_send_inquiry_button') to the OutlinedButton.icon
        // in contact_block.dart for a stable finder.
        await tester.tap(
          find.widgetWithText(OutlinedButton, 'Send inquiry').first,
        );
        await tester.pumpAndSettle();

        // The InquiryFormSheet bottom sheet should be visible.
        // l10n.inquiry_form_title = "Send Inquiry".
        expect(
          find.text('Send Inquiry'),
          findsOneWidget,
          reason: 'Inquiry form bottom sheet should be visible.',
        );

        // Fill in the inquiry form fields.
        // Name — l10n.inquiry_form_name_label = "Your name".
        // TODO(qv): add Key('inquiry_name_field') to the name TextField in
        // _SheetBody in inquiry_form_sheet.dart.
        await tester.enterText(
          find.widgetWithText(TextField, 'Your name').first,
          'QV Integration Tester',
        );
        // Phone — l10n.inquiry_form_phone_label.
        // TODO(qv): add Key('inquiry_phone_field').
        await tester.enterText(
          find.widgetWithText(TextField, 'Phone number').first,
          _kAdminPhone,
        );
        // Message — l10n.inquiry_form_message_label.
        // TODO(qv): add Key('inquiry_message_field').
        await tester.enterText(
          find.widgetWithText(TextField, 'Message').first,
          'QV automated integration test inquiry — please ignore.',
        );
        await tester.pumpAndSettle();

        // Submit — l10n.inquiry_form_submit_button = "Send" (ElevatedButton).
        // TODO(qv): add Key('inquiry_submit_button') to the ElevatedButton.
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Send').first,
        );
        await tester.pump(_kNetworkWait);
        await tester.pumpAndSettle();

        // The sheet dismisses on InquiryFormSubmittedSuccess
        // (Navigator.of(context).pop(true)).
        expect(
          find.text('Send Inquiry'),
          findsNothing,
          reason:
              'Inquiry form sheet should close after successful submission.',
        );
      },
    );
  });
}

// ── Test helpers ──────────────────────────────────────────────────────────────

/// Logs in as [phone] / [password] via the login page.
///
/// Navigates to the login page if necessary, fills the form, and taps Sign In.
Future<void> loginAs(
  WidgetTester tester,
  String phone,
  String password,
) async {
  // If already on the home feed navigate to login via the empty-state action.
  // TODO(qv): add Key('home_login_nav_button') on the home-page login action.
  if (find.text('Sign In').evaluate().isEmpty) {
    final signInToPublish = find.text('Sign in to publish');
    if (signInToPublish.evaluate().isNotEmpty) {
      await tester.tap(signInToPublish.first);
      await tester.pumpAndSettle();
    }
  }

  // Phone — l10n.login_phone_label = "Phone number".
  // TODO(qv): add Key('login_phone_field') in login_page.dart.
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Phone number').first,
    phone,
  );
  // Password — l10n.login_password_label = "Password".
  // TODO(qv): add Key('login_password_field') in login_page.dart.
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password').first,
    password,
  );

  // Submit — l10n.login_submit = "Sign In" (FilledButton).
  await tester.tap(find.widgetWithText(FilledButton, 'Sign In').first);
  await tester.pump(_kNetworkWait);
  await tester.pumpAndSettle();
}

/// Signs out the currently-signed-in user if a sign-out action is visible.
///
/// Looks for the "Sign out" TextButton present on the PendingApprovalPage and
/// other screens.
///
/// TODO(qv): add Key('sign_out_button') to any accessible sign-out widget so
/// this helper is key-stable across pages.
Future<void> signOutIfNeeded(WidgetTester tester) async {
  final signOut = find.text('Sign out'); // l10n.sign_out
  if (signOut.evaluate().isNotEmpty) {
    await tester.tap(signOut.first);
    await tester.pump(_kShortWait);
    await tester.pumpAndSettle();
  }
}

/// Advances one step in the multi-step listing form by tapping the first
/// recognizable "Next" / "Continue" FilledButton found.
///
/// If no such button is found, pumps once to let animations settle.
///
/// TODO(qv): add Key('listing_form_next_button') to each step-navigation
/// FilledButton in listing_form_page.dart for stable, label-independent
/// advancement.
Future<void> tapNextOrContinue(WidgetTester tester) async {
  for (final label in <String>['Next', 'Continue', 'Next step']) {
    final btn = find.widgetWithText(FilledButton, label);
    if (btn.evaluate().isNotEmpty) {
      await tester.tap(btn.first);
      await tester.pumpAndSettle();
      return;
    }
  }
  await tester.pump(const Duration(milliseconds: 500));
}
