plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.github.qcbf.jotcalc"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.qcbf.jotcalc"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
}

androidComponents {
    onVariants(selector().withBuildType("release")) { variant ->
        // Compress native libraries in APKs and let Android extract them during installation.
        variant.packaging.jniLibs.useLegacyPackaging.set(true)
    }
}

flutter {
    source = "../.."
}
