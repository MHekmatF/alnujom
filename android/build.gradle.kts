allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // Trust the local cache for dynamic ("1.2+") versions for a year.
    //
    // WHY — the release build broke on 2026-09-03 with "no versions of
    // androidx.test:rules are available", having worked twice the same morning.
    // Nothing had changed: `dl.google.com` — which `maven.google.com` redirects
    // to — answers **404 for every path** from this network, master-index.xml
    // included, while Maven Central answers 200. Google's Maven is not reachable
    // from here.
    //
    // Flutter's `integration_test` plugin asks for `androidx.test:rules:1.2+`
    // and `androidx.test.espresso:espresso-core:3.3+`. Both are already in the
    // Gradle cache (1.2.0 and 3.3.0) and both satisfy those ranges — but a
    // dynamic version carries a 24-hour freshness check, so once a day Gradle
    // goes looking for a newer one, cannot reach the repository, and fails the
    // whole build rather than using what it has.
    //
    // Lengthening the cache alone is not enough — the cache holds the *jars*,
    // not the "which versions exist" listing a range needs, and that listing has
    // to come from the repository. So the ranges are pinned to the exact
    // versions already on disk, which both satisfy them. With a concrete
    // coordinate Gradle looks it up locally and never asks the network.
    //
    // These two artifacts are Espresso test infrastructure. They are compiled
    // into the instrumentation APK, never the release one, so pinning them
    // cannot change what ships. Raise the numbers when integration tests need
    // something newer — and expect to need a working route to Google's Maven on
    // the day you do.
    configurations.all {
        resolutionStrategy {
            cacheDynamicVersionsFor(365, "days")
            cacheChangingModulesFor(365, "days")
            force("androidx.test:rules:1.2.0")
            force("androidx.test.espresso:espresso-core:3.3.0")
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
