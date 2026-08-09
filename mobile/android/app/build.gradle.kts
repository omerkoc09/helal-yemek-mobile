import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Release imzalama bilgileri android/key.properties'ten okunur (gitignore'lı).
// Dosya yoksa build KIRILMAZ, debug imzasına düşer — böylece keystore'u olmayan
// geliştirici/CI ortamları da çalışmaya devam eder.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}
val hasReleaseKeystore = keystorePropertiesFile.exists()

// Maps SDK anahtarı android/maps.properties'ten okunur (gitignore'lı, key.properties
// ile aynı desen). Manifest'e manifestPlaceholders üzerinden enjekte edilir.
//
// NEDEN: anahtar önce manifest'e gömülüydü ve git'e commit edilmişti. Mobil SDK
// anahtarının APK içinde bulunması kaçınılmazdır (Google'ın koruma önerisi de
// gizlemek değil, paket adı + SHA-1 ile KISITLAMAKTIR); asıl sorun anahtarın
// kaynak kodda durup backend anahtarıyla aynı olmasıydı. Artık platform başına
// ayrı, kısıtlanmış anahtar kullanılıyor.
//
// Dosya yoksa build KIRILMAZ: boş değer yazılır, harita boş görünür ama derleme
// ve testler çalışmaya devam eder (CI ve yeni geliştirici ortamları için).
val mapsPropertiesFile = rootProject.file("maps.properties")
val mapsProperties = Properties().apply {
    if (mapsPropertiesFile.exists()) {
        load(FileInputStream(mapsPropertiesFile))
    }
}
val mapsApiKey = mapsProperties.getProperty("mapsApiKey") ?: ""

android {
    namespace = "com.itimat.itimat"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.itimat.itimat"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // AndroidManifest.xml içindeki ${MAPS_API_KEY} bununla değiştirilir.
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // key.properties varsa gerçek release imzası, yoksa debug'a düşer.
            // UYARI: debug imzalı APK Play Store'a YÜKLENEMEZ.
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
}
