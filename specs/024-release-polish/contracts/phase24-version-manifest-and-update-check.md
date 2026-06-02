# Contract — Version manifest & in-app update check (UP)

**Owner phase**: UP. **Principles**: IX (domain Supabase-free), V/VI (localized + themed prompt), XI.

## Manifest object (Supabase Storage — public read)

JSON schema in `data-model.md` §1 (`latest_version` REQUIRED semver; optional `latest_build`, `min_supported_version` [forward-stated, ignored in v1], `download.telegram_url`/`website_url`, `release_notes.{ar,en}`). Uploaded by the operator (R-216); the client only reads it.

## Symbols UP exports (new — what `app.dart` consumes)

```dart
// domain
abstract interface class AppUpdateRepository {
  Future<Result<UpdateAvailability>> checkForUpdate(); // never throws
}
sealed class UpdateAvailability {}           // UpdateAvailable(VersionManifest) | UpToDate | CheckFailed
class AppVersion { int compareTo(AppVersion other); /* semver-first, build tiebreaker */ }

// presentation
class AppUpdateCubit extends Cubit<AppUpdateState> { Future<void> check(); }
// widgets/update_prompt_dialog.dart — showUpdatePrompt(BuildContext, VersionManifest)
```

`app.dart` calls `getIt<AppUpdateCubit>().check()` once on cold start and shows the dialog on `UpdateAvailable`.

## Behaviour invariants (verified)

- **Compare**: prompt iff `latest_version > installed` (semver), or equal-semver AND `latest_build > installed_build` (R-210).
- **Prompt**: localized title/body + **Update** (`url_launcher` → `telegram_url` ?? `website_url`) + **Later** (dismiss for session); shown **once per cold start**; re-shows next cold start until updated; **no persisted dismissed-version state** (R-211, FR-009).
- **Fail-silent**: unreachable / malformed / missing `latest_version` / same-or-older ⇒ `CheckFailed`/`UpToDate` ⇒ **no prompt, no error toast, no crash** (FR-010).
- **Source**: Supabase Storage via the existing `SupabaseClientWrapper`; **no Cloudflare/Google CDN** (R-209). `min_supported_version` parsed but not enforced (forward-stated).
- **Domain purity**: `domain/` imports no `supabase_flutter`/`package_info_plus`; those live in `data/` (`SupabaseManifestDatasource`, `PackageInfoVersionSource`).
- **l10n**: every prompt string in both ARBs + `_DebugAppLocalizations` (FR-015); four-combination correct (FR-016).
