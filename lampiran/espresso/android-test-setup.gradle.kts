// Merge these focused additions into apps/mobile/android/app/build.gradle.kts.
val bddTestRequested = project.hasProperty("perpusBddTest")
val m5TestRequested = project.hasProperty("perpusM5Test")
require(!(bddTestRequested && m5TestRequested))

android {
    defaultConfig {
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    buildTypes {
        getByName("debug") {
            when {
                bddTestRequested -> {
                    applicationIdSuffix = ".bddtest"
                    manifestPlaceholders["perpusAppLabel"] = "Perpus BDD Uji"
                }
                m5TestRequested -> {
                    applicationIdSuffix = ".m5test"
                    manifestPlaceholders["perpusAppLabel"] = "Perpus M5 Uji"
                }
            }
        }
    }
}

dependencies {
    // Match debug and instrumentation variants to avoid Gradle's variant consistency conflict.
    debugImplementation("androidx.test:core:1.7.0")
    debugImplementation("androidx.test:runner:1.7.0")
    debugImplementation("androidx.test.ext:junit:1.3.0")
    debugImplementation("androidx.test.espresso:espresso-core:3.7.0")
    androidTestImplementation("androidx.test:core:1.7.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.7.0")
}
