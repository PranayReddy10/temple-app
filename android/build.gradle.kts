allprojects {
    repositories {
        google()
        mavenCentral()
        // PhonePe publishes its Android SDK (IntentSDK) only here, not on
        // Maven Central; phonepe_payment_sdk needs it to build.
        maven { url = uri("https://phonepe.mycloudrepo.io/public/repositories/phonepe-intentsdk-android") }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Some plugins still compile against an old Android API (applovin_max and
// phonepe_payment_sdk hardcode 31), while the AndroidX libraries they pull in
// need 34+, which fails the build at :<plugin>:checkDebugAarMetadata. Raise
// any plugin compiling below 36 to 36. Only the SDK they compile against
// changes: minSdk and targetSdk, and so their behaviour on devices, do not.
// Registered here, before the plugins' own scripts run, so it runs before
// AGP finalises their settings.
subprojects {
    val raiseCompileSdk: Project.() -> Unit = {
        val android = extensions.findByName("android")
        if (android != null && plugins.hasPlugin("com.android.library")) {
            val current = (android.withGroovyBuilder { "getCompileSdkVersion"() } as? String)
                ?.removePrefix("android-")?.toIntOrNull() ?: 0
            if (current < 36) {
                android.withGroovyBuilder { "compileSdkVersion"(36) }
            }
        }
    }
    if (state.executed) raiseCompileSdk() else afterEvaluate { raiseCompileSdk() }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
