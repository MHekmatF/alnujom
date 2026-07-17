# QA E2E — R8/ProGuard keep rules for the release build (PERF-M5).
# The Flutter Gradle plugin already keeps the engine + embedding, but these
# explicit keeps guard against R8 stripping reflection-reached plugin code.

# Flutter engine + embedding.
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Firebase Cloud Messaging (Phase 22 push) — models + services reached reflectively.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# flutter_local_notifications (Phase 29 CRM reminders) — broadcast receivers.
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# Preserve annotations + generic signatures (JSON/reflection used by some plugins).
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
