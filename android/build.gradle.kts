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
// Workaround for old Flutter plugins that don't declare an `android.namespace`
// (required by AGP 8+). `telephony` 0.2.0 is discontinued and still ships a
// `package="..."` attribute in its AndroidManifest.xml instead — inject a
// namespace for any such subproject so Gradle configuration doesn't fail with
// "Namespace not specified". This must be registered before `:app` is
// evaluated below (evaluating `:app` cascades into evaluating the plugins).
subprojects {
    afterEvaluate {
        val androidExtension = project.extensions.findByName("android")
        if (androidExtension != null) {
            val currentNamespace = androidExtension.javaClass.methods
                .firstOrNull { it.name == "getNamespace" && it.parameterCount == 0 }
                ?.invoke(androidExtension) as? String
            if (currentNamespace.isNullOrBlank()) {
                val fallback = when (project.name) {
                    "telephony" -> "com.shounakmulay.telephony"
                    else -> "${project.group}.${project.name}".replace('-', '_')
                }
                androidExtension.javaClass.methods
                    .firstOrNull { it.name == "setNamespace" && it.parameterCount == 1 }
                    ?.invoke(androidExtension, fallback)
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
