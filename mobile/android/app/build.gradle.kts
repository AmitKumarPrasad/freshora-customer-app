import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Local dev machine keystore (Windows) takes priority; falls back to the key.properties
// that CI writes to android/ when ANDROID_KEYSTORE_BASE64 secrets are configured.
val localSigningPropertiesFile = File(
    "${System.getenv("LOCALAPPDATA")}/TalegaonFreshSigning/key.properties"
)
val ciSigningPropertiesFile = rootProject.file("key.properties")
val signingPropertiesFile = when {
    localSigningPropertiesFile.isFile -> localSigningPropertiesFile
    ciSigningPropertiesFile.isFile -> ciSigningPropertiesFile
    else -> null
}
val signingProperties = signingPropertiesFile?.let {
    Properties().apply { it.inputStream().use { input -> load(input) } }
}

android {
    namespace = "com.freshora.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.freshora.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signingProperties != null) {
            create("release") {
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
                storeFile = file(signingProperties.getProperty("storeFile"))
                storePassword = signingProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Falls back to the debug cert when no signing properties are available
            // (e.g. CI runs without the ANDROID_KEYSTORE_BASE64 secret configured).
            signingConfig = if (signingProperties != null) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
