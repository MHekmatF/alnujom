import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Phase 22: Apply the google-services plugin ONLY when google-services.json is
// present in the app directory.  When the file is absent (e.g. CI without
// Firebase, Syria-sanction degraded mode) the plugin is skipped entirely and
// the build succeeds with NoopPushMessagingService bound (SC-003/SC-010/FR-024).
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Phase 24 RB — Fail-closed release signing (R-213, FR-003).
// Reads android/key.properties (gitignored; keystore stored outside the repo).
// If the file is absent the release build FAILS — there is NO debug-signed fallback.
// (Mirrors the existing google-services.json conditional-on-gitignored-file pattern above,
// but inverted: absent key.properties is an ERROR, not a degraded-mode path.)
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().also { props ->
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { props.load(it) }
    }
}

android {
    namespace = "com.alnujom.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Phase 29 (F1): core library desugaring is required by
        // flutter_local_notifications (java.time on minSdk < 26).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.alnujom.app"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // Fail closed: each property access throws if key.properties is absent
            // or the key is missing — the release build will not proceed unsigned.
            storeFile = file(
                keystoreProperties.getProperty("storeFile")
                    ?: error("Release signing: 'storeFile' not found in android/key.properties")
            )
            storePassword = keystoreProperties.getProperty("storePassword")
                ?: error("Release signing: 'storePassword' not found in android/key.properties")
            keyAlias = keystoreProperties.getProperty("keyAlias")
                ?: error("Release signing: 'keyAlias' not found in android/key.properties")
            keyPassword = keystoreProperties.getProperty("keyPassword")
                ?: error("Release signing: 'keyPassword' not found in android/key.properties")
        }
    }

    buildTypes {
        release {
            // Phase 24 RB: fail-closed signing — no debug fallback (R-213, FR-003).
            // A release build WITHOUT a valid android/key.properties (and keystore)
            // will fail at configuration time (see signingConfigs above).
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Phase 29 (F1): required when isCoreLibraryDesugaringEnabled = true
    // (backs java.time used by flutter_local_notifications zonedSchedule).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
