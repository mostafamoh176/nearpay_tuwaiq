allprojects {
    repositories {
        google()
        mavenCentral()
    }
    def props = new Properties()
    File localPropertiesFile = new File(rootDir, 'local.properties')
    if (localPropertiesFile.exists()) {
        props.load(new FileInputStream(localPropertiesFile))
    }
    maven {
        url = "https://gitlab.com/api/v4/projects/37026421/packages/maven"
        credentials(HttpHeaderCredentials) {
            name = 'Private-Token'
            value = nearpayPosGitlabReadToken //will be supported from Nearpay Product Team
        }
        authentication {
            header(HttpHeaderAuthentication)
        }
    }
    maven { url 'https://jitpack.io' }
    maven { url 'https://developer.huawei.com/repo/' }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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
