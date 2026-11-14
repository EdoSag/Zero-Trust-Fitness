// ZT Fitness for Wear OS (F10): a companion to the phone app. It shows
// today's Heart Points, steps and water in two tiles and a small app, and
// adds water. The numbers come from the unlocked phone over the Wear OS Data
// Layer; the watch never holds the account's keys.
plugins {
    id("com.android.application")
    id("kotlin-android")
}

// Same version name as the phone app (pubspec.yaml). Play needs every APK
// in a listing to have its own versionCode, so the watch's sits above the
// phone's: 1,000,000 + the phone build number (-PztBuild=, set by CI).
val pubspecVersion: String =
    rootProject.file("../pubspec.yaml").readLines()
        .first { it.startsWith("version:") }
        .substringAfter("version:").trim()
val ztBuild: Int =
    (findProperty("ztBuild") as String?)?.toInt()
        ?: pubspecVersion.substringAfter('+', "1").toInt()

android {
    namespace = "dev.sagron.zerotrustfitness.wear"
    compileSdk = 36

    defaultConfig {
        // The same id as the phone app: Wear OS pairs them by package name.
        applicationId = "dev.sagron.zerotrustfitness"
        minSdk = 30
        // Google Play: Wear OS apps must target Android 15 (API 35) or higher
        // since 31 August 2026.
        targetSdk = 35
        versionCode = 1_000_000 + ztBuild
        versionName = pubspecVersion.substringBefore('+')
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        create("release") {
            // Same key as the phone app; CI exports these (see the APK workflow).
            if (System.getenv("CI") != null) {
                storeFile = file(System.getenv("CM_BUILD_DIR") + "/codemagic.keystore")
                storePassword = System.getenv("CM_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("CM_KEY_ALIAS")
                keyPassword = System.getenv("CM_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    implementation("com.google.android.gms:play-services-wearable:19.0.0")
    implementation("androidx.wear.tiles:tiles:1.4.1")
    implementation("androidx.wear.protolayout:protolayout:1.2.1")
    implementation("androidx.wear.protolayout:protolayout-material:1.2.1")
    implementation("com.google.guava:guava:33.3.1-android")
}
