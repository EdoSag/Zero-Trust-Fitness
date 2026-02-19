pluginManagement {
  val flutterSdkPath =
      run {
          val properties = java.util.Properties()
          val localPropertiesFile = file("local.properties")
          if (localPropertiesFile.exists()) {
              localPropertiesFile.inputStream().use { properties.load(it) }
          }

          val flutterSdkFromProperties = properties.getProperty("flutter.sdk")
          val flutterSdkFromEnv = System.getenv("FLUTTER_ROOT")
          val resolvedFlutterSdkPath = flutterSdkFromProperties ?: flutterSdkFromEnv

          require(resolvedFlutterSdkPath != null) {
              "Flutter SDK path is not configured. Set flutter.sdk in android/local.properties or define FLUTTER_ROOT."
          }
          resolvedFlutterSdkPath
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
    
}

include(":app")
