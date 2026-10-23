plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nantiingatkanaku.nanti_ingatkan_aku"

    // PRD §6.2 — pinned instead of inherited from `flutter.*` so that a Flutter
    // upgrade cannot silently move the platform contract.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // `flutter_local_notifications` schedules with `java.time`, which is
        // only native from API 26; desugaring keeps the plugin AAR working
        // regardless of its own minSdk (§7.6).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.nantiingatkanaku.nanti_ingatkan_aku"
        // PRD §6.2 — Android 8.0 (API 26) and up.
        minSdk = 26
        targetSdk = 36
        multiDexEnabled = true
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
