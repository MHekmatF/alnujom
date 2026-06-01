pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    // Phase 22: google-services plugin declared here (apply false) so the
    // app/build.gradle.kts can apply it conditionally only when
    // google-services.json is present.  This prevents a hard build failure when
    // Firebase is not configured (SC-003/SC-010/FR-024 degraded-mode requirement).
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
