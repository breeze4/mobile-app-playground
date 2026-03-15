plugins {
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.10" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.1.10" apply false
    id("com.google.android.libraries.mapsplatform.secrets-gradle-plugin") version "2.0.1" apply false
}

// Load .env into local.properties (secrets-gradle-plugin reads local.properties)
val envFile = rootProject.file(".env")
if (envFile.exists()) {
    val localProps = rootProject.file("local.properties")
    val props = java.util.Properties()
    if (localProps.exists()) props.load(localProps.inputStream())
    envFile.readLines().forEach { line ->
        val trimmed = line.trim()
        if (trimmed.isNotEmpty() && !trimmed.startsWith("#") && trimmed.contains("=")) {
            val (key, value) = trimmed.split("=", limit = 2)
            props.setProperty(key.trim(), value.trim())
        }
    }
    props.store(localProps.outputStream(), null)
}
