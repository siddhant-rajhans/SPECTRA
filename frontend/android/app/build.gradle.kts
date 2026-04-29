plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.hearclear.hearclear"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.hearclear.hearclear"
        // record + tflite_flutter need API 24+; YAMNet inference is much faster on
        // recent NPUs, so we target the latest stable Android SDK.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signing with the debug keys for now, so `flutter run --release`
            // works on the test Pixel. Replace with a real keystore before any
            // Play Store / OTA distribution.
            signingConfig = signingConfigs.getByName("debug")

            // Disable R8 shrinking for the cochlear implant test build. TFLite
            // ships optional GPU/NNAPI delegate classes that R8 can't always
            // resolve; once we ship a real release we'll re-enable this with
            // the proguard-rules.pro below in place.
            isMinifyEnabled = false
            isShrinkResources = false

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
