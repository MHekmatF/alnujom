// Plan A27 — the terms of service the app asks people to accept.
//
// Must equal the "Version" line at the top of docs/legal/terms-of-service.md.
// Bump it when the document changes materially; `profiles.terms_version`
// records what each person accepted, so a newer value here is how a future
// "please accept the new terms" step will know whom to ask.
const String kTermsVersion = '2026-09-05';
