plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle Plugin (MUST be last)
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.calendar_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // REQUIRED for flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.calendar_app"

        // ✅ MUST be 21+ for notifications
        minSdk = flutter.minSdkVersion

        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")

            // ✅ Disable R8/Proguard (prevents Missing type parameter crash)
            isMinifyEnabled = false
            isShrinkResources = false

            // Keep this for safety if you enable minify later
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    // REQUIRED for Java 8+ time APIs used by notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}
