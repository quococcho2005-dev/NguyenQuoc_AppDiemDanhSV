import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects {
    repositories {
        google()
        mavenCentral()
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
subprojects {
    project.evaluationDependsOn(":app")
}

// These plugin releases declare different Java bytecode levels. Keep their
// Kotlin tasks at the same level as their respective Android Java tasks.
subprojects {
    plugins.withId("com.android.library") {
        when (project.name) {
            "tflite_flutter", "google_mlkit_commons" ->
                tasks.withType<KotlinCompile>().configureEach {
                    compilerOptions.jvmTarget.set(JvmTarget.JVM_11)
                }
            "image_picker_android" ->
                tasks.withType<KotlinCompile>().configureEach {
                    compilerOptions.jvmTarget.set(JvmTarget.JVM_17)
                }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
