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

    // Patch a namespace onto legacy plugins that don't declare one (AGP 8+ requires it).
    // This afterEvaluate MUST be registered before evaluationDependsOn(":app") below:
    // that call forces eager evaluation, after which afterEvaluate can no longer be added.
    afterEvaluate {
        val android = project.extensions.findByName("android")
        if (android != null) {
            try {
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                if (getNamespace.invoke(android) == null) {
                    setNamespace.invoke(android, project.group.toString())
                }
            } catch (e: Exception) {
                // Ignore if reflection fails or methods do not exist
            }

            // Force Java compatibility to 1.8 on the android extension so it matches the
            // Kotlin jvmTarget below. Legacy plugins pin Java to 1.8/11 while their Kotlin
            // defaults higher, which Gradle rejects as inconsistent JVM-target compatibility.
            // 1.8 is the safe floor: higher targets would require bumping each old plugin's
            // compileSdkVersion (Java 9+ source needs compileSdk 30+).
            try {
                val compileOptions = android.javaClass.getMethod("getCompileOptions").invoke(android)
                val setSource = compileOptions.javaClass.getMethod("setSourceCompatibility", Any::class.java)
                val setTarget = compileOptions.javaClass.getMethod("setTargetCompatibility", Any::class.java)
                setSource.invoke(compileOptions, JavaVersion.VERSION_1_8)
                setTarget.invoke(compileOptions, JavaVersion.VERSION_1_8)
            } catch (e: Exception) {
                // Ignore if reflection fails or methods do not exist
            }
        }
    }

    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8)
        }
    }

    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
