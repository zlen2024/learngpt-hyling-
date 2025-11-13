plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.huawei.agconnect")
}

android {
    namespace = "com.nel.hmsdemo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // ✅ Enable desugaring for flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.nel.hmsdemo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // ✅ Enable multidex (recommended for desugaring)
        multiDexEnabled = true
        
        ndk {
            abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a"))
        }
    }

    splits {
        abi {
            isEnable = false
        }
    }

    signingConfigs {
        create("release") {
            storeFile = file("hms_demo.jks")
            keyAlias = "hmsdemo"
            keyPassword = "020513"
            storePassword = "020513"
            // Note: v1SigningEnabled and v2SigningEnabled are typically true by default
            // for the Android Gradle Plugin versions that use Kotlin DSL.
            // Explicitly setting them for clarity:
            enableV1Signing = true
            enableV2Signing = true
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false  // Changed from shrinkResources to isShrinkResources
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") {
            signingConfig = signingConfigs.getByName("release")
            isDebuggable = true
        }
    }
}

dependencies {
    // ✅ Add desugaring library (REQUIRED for flutter_local_notifications)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.2")
    
    // Add the agconnect-core dependency for basic HMS functionality.
    // Use the latest stable version: 1.9.1.300
    implementation("com.huawei.agconnect:agconnect-core:1.9.1.300") 
    implementation("com.huawei.hms:base:6.12.0.300")  // Add HMS base
    implementation("com.huawei.hms:ml-computer-voice-tts:3.12.0.301")           
    implementation("com.huawei.hms:ml-computer-voice-asr:3.12.0.301")                    
    implementation("com.huawei.hms:ml-computer-voice-realtimetranscription:3.12.0.301") 
    //implementation("com.huawei.hms:ml-nlp-textembedding:3.12.0.301")   
    implementation("com.huawei.hms:ml-nlp-textembedding:3.11.0.302")
    implementation("com.huawei.hms:ml-computer-voice-tts-model-bee:3.6.0.300")
    //implementation("com.huawei.hms:ml-computer-nlp-textembedding:3.9.0.300")
    // Import the eagle voice package.
    implementation("com.huawei.hms:ml-computer-voice-asr-plugin:3.12.0.300")
    //implementation("com.huawei.hms:ml-computer-voice-asr-plugin:3.12.0.300")
}

flutter {
    source = "../.."
}