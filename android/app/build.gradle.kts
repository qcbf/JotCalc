import groovy.json.JsonException
import groovy.json.JsonSlurper
import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val localConfigFile = rootProject.file("../local.json")
val keystoreProperties = when {
    keystorePropertiesFile.isFile -> Properties().apply {
        keystorePropertiesFile.inputStream().use(::load)
    }
    localConfigFile.isFile -> {
        val localConfig = try {
            JsonSlurper().parse(localConfigFile, "UTF-8") as? Map<*, *>
        } catch (_: JsonException) {
            null
        } ?: throw GradleException("local.json must contain a valid JSON object.")

        localConfig["Keystore"]?.let { settings ->
            val keystore = settings as? Map<*, *>
                ?: throw GradleException("Keystore in local.json must be an object.")

            fun stringField(name: String, default: String? = null): String =
                (keystore[name] ?: default) as? String
                    ?: throw GradleException("Keystore.$name in local.json must be a string.")

            val path = stringField("Path", "f.keystore")
            val password = stringField("Password")
            Properties().apply {
                setProperty("storeFile", localConfigFile.toPath().resolveSibling(path).toString())
                setProperty("storePassword", password)
                setProperty("keyAlias", stringField("AliasName"))
                setProperty("keyPassword", stringField("KeyPassword", "").ifEmpty { password })
            }
        }
    }
    else -> null
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

    signingConfigs {
        if (keystoreProperties != null) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = if (keystoreProperties != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
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
