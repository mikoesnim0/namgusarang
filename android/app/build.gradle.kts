plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

import java.util.Properties

val localProps = Properties()
val localPropsFile = rootProject.file("local.properties")
if (localPropsFile.exists()) {
    localProps.load(localPropsFile.inputStream())
}
val kakaoKey = (localProps["kakao.native_app_key"] as String?) ?: ""

android {
    namespace = "com.doyakmin.hangookji.namgu"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.doyakmin.hangookji.namgu"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Kakao native app key injection (keep secrets in android/local.properties)
        // Add: kakao.native_app_key=YOUR_NATIVE_APP_KEY
        resValue("string", "kakao_app_key", kakaoKey)
        manifestPlaceholders["kakaoScheme"] = "kakao$kakaoKey"
    }

    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    val hasReleaseKeystore = keystorePropertiesFile.exists()

    if (hasReleaseKeystore) {
        keystoreProperties.load(keystorePropertiesFile.inputStream())
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // If android/key.properties exists, we sign with the release keystore.
            // Otherwise we fall back to debug so local release builds still work.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
    if (kakaoKey.isNotBlank()) {
        dartDefines = listOf("KAKAO_NATIVE_APP_KEY=$kakaoKey")
    }
}
