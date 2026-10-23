import java.security.MessageDigest
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "tech.ahmadjz.greymushaf"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "tech.ahmadjz.greymushaf"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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

// Never ship a partial bundle or metrics prepared for different assets.
val verifyMushafBundle by tasks.registering {
    doLast {
        val assets = file("../../assets/mushaf")
        val metrics = file("../../assets/mushaf/metrics.json")
        check(metrics.isFile) { "Missing mushaf metrics: run flutter test tool/prepare_metrics.dart" }
        val json = groovy.json.JsonSlurper()
        val numbers = json.parse(File(assets, "pages.json")) as List<*>
        check(numbers == (1..604).toList()) { "Partial mushaf: run bundle_mushaf.py --all" }
        val data = json.parse(metrics) as Map<*, *>
        check(data["wordMetricsSchema"] == 1) {
            "Missing prepared word metrics: run flutter test tool/prepare_metrics.dart"
        }
        val hashes = data["sha256"] as Map<*, *>
        val properties = Properties().apply {
            file("../local.properties").inputStream().use { load(it) }
        }
        val sdk = properties.getProperty("flutter.sdk")
        val version = json.parse(File("$sdk/bin/cache/flutter.version.json")) as Map<*, *>
        val identity = listOf("frameworkRevision", "engineRevision").associateWith { version[it] }
        check(identity.values.all { it is String && it.isNotEmpty() } && data["flutter"] == identity) {
            "Stale Flutter engine/framework metrics: run flutter test tool/prepare_metrics.dart"
        }
        val required = (1..604).flatMap { listOf("$it.json", "p$it.ttf") } +
            listOf("pages.json", "fonts.json", "basmallah.json", "surah-name-v4.ttf")
        fun sha256(file: File): String = MessageDigest.getInstance("SHA-256")
            .digest(file.readBytes()).joinToString("") { "%02x".format(it) }
        for (name in required) {
            val asset = File(assets, name)
            check(asset.isFile && hashes[name] == sha256(asset)) {
                "Stale/missing mushaf asset $name: regenerate bundle and Flutter metrics"
            }
        }
        check(data["shapingSource"] == sha256(file("../../lib/bundle_metrics.dart"))) {
            "Stale shaping metrics: run flutter test tool/prepare_metrics.dart"
        }
    }
}
tasks.matching { it.name.startsWith("compileFlutterBuild") }.configureEach {
    dependsOn(verifyMushafBundle)
}
