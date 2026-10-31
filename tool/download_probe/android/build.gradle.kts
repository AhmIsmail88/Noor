plugins { id("com.android.application") version "9.1.0" }

layout.buildDirectory.set(file("../../../build/download_probe/android"))
android {
    namespace = "com.noor.player.downloadprobe"
    compileSdk = 36
    defaultConfig {
        applicationId = "com.noor.player.downloadprobe"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "0.1-probe"
        ndk { abiFilters += "arm64-v8a" }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    packaging { jniLibs { useLegacyPackaging = true } }
}
dependencies {
    implementation("io.github.junkfood02.youtubedl-android:library:0.18.1")
    implementation("io.github.junkfood02.youtubedl-android:ffmpeg:0.18.1")
}
