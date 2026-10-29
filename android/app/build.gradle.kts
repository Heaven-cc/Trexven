import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties().apply {
    val propertiesFile = rootProject.file("key.properties")
    if (propertiesFile.isFile) {
        propertiesFile.inputStream().use { load(it) }
    }
}

// Environment variables override android/key.properties; neither belongs in Git.
val releaseSigning = mapOf(
    "storeFile" to "TREXVEN_KEYSTORE_PATH",
    "storePassword" to "TREXVEN_KEYSTORE_PASSWORD",
    "keyAlias" to "TREXVEN_KEY_ALIAS",
    "keyPassword" to "TREXVEN_KEY_PASSWORD",
).mapValues { (property, environment) ->
    System.getenv(environment)?.takeIf { it.isNotBlank() }
        ?: keystoreProperties.getProperty(property)?.takeIf { it.isNotBlank() }
}
val releaseKeystoreFile = releaseSigning["storeFile"]?.let { rootProject.file(it) }

// Defer validation until a release build, so IDE sync and debug need no release key.
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    doFirst {
        val missing = releaseSigning.filterValues { it == null }.keys
        check(missing.isEmpty()) {
            "Release signing requires ${missing.joinToString()} in android/key.properties " +
                "or the corresponding TREXVEN_* environment variables. No debug fallback is allowed."
        }
        check(releaseKeystoreFile?.isFile == true) {
            "Release keystore not found. Check storeFile in android/key.properties " +
                "or TREXVEN_KEYSTORE_PATH."
        }
    }
}

android {
    namespace = "com.trexven.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.trexven.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = releaseKeystoreFile
            storePassword = releaseSigning["storePassword"]
            keyAlias = releaseSigning["keyAlias"]
            keyPassword = releaseSigning["keyPassword"]
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
