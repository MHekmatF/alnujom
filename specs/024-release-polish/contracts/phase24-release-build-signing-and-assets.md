# Contract — Release build: signing, icon, splash, version (RB)

**Owner phase**: RB. **Principles**: III (key never committed), VI (themed splash), XI (Android-only), II (config checked in, secrets excepted). **No Dart symbol.**

## Signing (`android/app/build.gradle.kts`)

- Replace `release { signingConfig = signingConfigs.getByName("debug") }` (+ TODO) with a real `release` `signingConfig` reading from **`android/key.properties`** (gitignored): `storeFile`, `storePassword`, `keyAlias`, `keyPassword`. Keystore file lives **outside the repo** (ADR-0001).
- **Fail closed**: if `key.properties` (or the keystore) is absent, the **release build fails** — it MUST NOT fall back to debug signing (FR-003). (Debug/profile builds are unaffected; the existing `if (file("google-services.json").exists())` guard is the established conditional-on-gitignored-file pattern.)
- `android/.gitignore` MUST list `key.properties` and `*.jks`/`*.keystore`.

## Icon + splash

- `flutter_launcher_icons` (dev) — config in `pubspec.yaml`; source art `assets/branding/icon*.png`; generates `mipmap-*` + Android **adaptive icon** (foreground/background) into `android/app/src/main/res/**`.
- `flutter_native_splash` (dev) — config in `pubspec.yaml` with **light + dark** (`color` + `color_dark` / `image` + `image_dark`); generates `drawable*` + `values`/`values-night` (FR-002).

## Version

- `pubspec.yaml` `version: 1.0.0+N` (already `1.0.0+1`); the build number `+N` may increment per build without changing `1.0.0` (data-model §1 tiebreaker).

## Invariants (verified — SC-001/SC-008)

- Signed `1.0.0` APK installs + boots on a **fresh** device, icon + splash correct in light **and** dark.
- A release build with no key **fails** (no debug-signed artifact).
- `git` shows **no** keystore / `key.properties` / passwords committed.
- Release build shows **no** debug banner (`debugShowCheckedModeBanner: false` already set) and **no** `kDesignToolsEnabled` palette tester.
