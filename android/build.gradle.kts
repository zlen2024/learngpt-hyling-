import org.gradle.api.file.Directory
import org.gradle.api.tasks.Delete


buildscript {
    repositories {
        google()
        mavenCentral()
        // Must add the Huawei Maven repo here so the AGCP classpath can be found!
        maven { url = uri("https://developer.huawei.com/repo/") }
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.9.1")
        // Add the AppGallery Connect plugin configuration (AGCP).
        classpath("com.huawei.agconnect:agcp:1.9.1.301") // Use latest version
    }
}


allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://developer.huawei.com/repo/") }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
