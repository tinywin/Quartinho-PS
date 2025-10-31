plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services") // 🔥 importante pro Firebase
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.mobile"
    compileSdk = 36 // ✅ Atualizado para SDK 36 (requerido por plugins)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Habilita Java 17 + desugaring (necessário p/ algumas libs)
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = 36 // ✅ Atualizado também
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ⚙️ Facebook placeholders
        manifestPlaceholders["facebookAppId"] = "SEU_FACEBOOK_APP_ID"
        manifestPlaceholders["facebookClientToken"] = "SEU_FACEBOOK_CLIENT_TOKEN"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 🔹 Firebase BoM (controla as versões automaticamente)
    implementation(platform("com.google.firebase:firebase-bom:34.4.0"))

    // 🔹 SDKs Firebase que você usa
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-messaging")

    // 🔹 Se você usa login Google ou Facebook
    implementation("com.google.android.gms:play-services-auth:21.1.0") // Google Sign-In
    implementation("com.facebook.android:facebook-android-sdk:17.0.1") // Facebook Login

    // 🔹 Necessário pra recursos de linguagem mais novos
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
