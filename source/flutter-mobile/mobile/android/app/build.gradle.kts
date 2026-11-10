plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "in.crossfire.openola"
    // reactive_ble_mobile (and other plugins) compile against Android SDK 37, so the
    // app must compile against at least 37 (SDK levels are backward compatible).
    // Pinned explicitly rather than using flutter.compileSdkVersion (36 on this SDK).
    compileSdk = 37
    // Flutter always provisions the NDK (it strips debug symbols from the prebuilt
    // .so libraries shipped by plugins such as flutter_reactive_ble / mobile_scanner),
    // so this is required even though the app itself has no C/C++ code. Pin it to the
    // version Flutter expects; Android Studio's SDK Manager installs it on first build.
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    packaging {
        resources {
            excludes += setOf("META-INF/LICENSE.md", "META-INF/NOTICE.md")
        }
    }

    defaultConfig {
        applicationId = "in.crossfire.s1diag"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "edition"
    productFlavors {
        create("public") {
            dimension = "edition"
            manifestPlaceholders["appLabel"] = "OpenOLA"
        }
        create("super") {
            dimension = "edition"
            applicationIdSuffix = ".super"
            versionNameSuffix = "-super"
            manifestPlaceholders["appLabel"] = "OpenOLA Super"
        }
    }

    buildTypes {
        release {
            // Local development only. Configure your own release signing before publication.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Direct, in-app ADB client: classic authenticated TCP (port 5555),
    // Android 11+ pairing, shell, sync and package install. The host key is
    // generated per OpenOLA installation and kept in app-private storage.
    implementation("com.flyfishxu:kadb:2.1.5")
}
