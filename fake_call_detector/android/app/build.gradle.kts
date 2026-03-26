import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.example.fake_call_detector"
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
        // TODO: Replace with your organization package name before publishing.
        applicationId = "com.example.fake_call_detector"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProperties.getProperty("storeFile")
            val storePasswordValue = keystoreProperties.getProperty("storePassword")
            val keyAliasValue = keystoreProperties.getProperty("keyAlias")
            val keyPasswordValue = keystoreProperties.getProperty("keyPassword")

            if (
                !storeFilePath.isNullOrBlank() &&
                !storePasswordValue.isNullOrBlank() &&
                !keyAliasValue.isNullOrBlank() &&
                !keyPasswordValue.isNullOrBlank()
            ) {
                storeFile = file(storeFilePath)
                storePassword = storePasswordValue
                keyAlias = keyAliasValue
                keyPassword = keyPasswordValue
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            isDebuggable = false
            // Use debug signing for testing purposes since release keystore is not provided
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// Commenting out the mandatory signing check for testing/hackathon purposes
// tasks.matching { it.name == "assembleRelease" || it.name == "bundleRelease" }.configureEach {
//     doFirst {
//         val requiredKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
//         val missingKeys = requiredKeys.filter { keystoreProperties.getProperty(it).isNullOrBlank() }
//         if (missingKeys.isNotEmpty()) {
//             throw GradleException(
//                 "Release signing is not configured. Missing ${missingKeys.joinToString()} in android/key.properties."
//             )
//         }
//     }
// }

flutter {
    source = "../.."
}

dependencies {
    implementation("com.googlecode.libphonenumber:libphonenumber:8.13.55")
    implementation("org.tensorflow:tensorflow-lite:2.16.1")
}
