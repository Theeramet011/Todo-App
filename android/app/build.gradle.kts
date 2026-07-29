// ไฟล์นี้คือไฟล์ตั้งค่าหลัก (Build Configuration) สำหรับแอปพลิเคชันฝั่ง Android
// ทำหน้าที่กำหนดค่าต่างๆ เช่น เวอร์ชันของแอปพลิเคชัน, เวอร์ชันขั้นต่ำของ Android ที่รองรับ, 
// และปลั๊กอินต่างๆ ที่แอปต้องใช้ (เช่น Firebase, Kotlin, Flutter)
import java.io.FileInputStream
import java.util.Properties

// อ่านไฟล์ key.properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.taskmanager.todo_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true 
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // 🔥 แก้ไขจุดนี้: กลับมาใช้ kotlinOptions แบบมาตรฐานของ Kotlin DSL ที่ใช้ฟันหนูคู่ ""
    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // ส่วนนี้คือการตั้งค่าเริ่มต้นของแอปพลิเคชัน
        // รหัสประจำตัวของแอป (Application ID) ที่ใช้ระบุแอปของเราใน Play Store
        applicationId = "com.taskmanager.todo_app"
        // กำหนดเวอร์ชันขั้นต่ำ และเวอร์ชันเป้าหมายของ Android ที่แอปนี้รองรับ
        minSdk = flutter.minSdkVersion 
        targetSdk = flutter.targetSdkVersion
        // หมายเลขเวอร์ชันของแอปสำหรับการอัปเดต
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            val keyAliasProp = keystoreProperties.getProperty("keyAlias")
            val keyPasswordProp = keystoreProperties.getProperty("keyPassword")
            val storeFileProp = keystoreProperties.getProperty("storeFile")
            val storePasswordProp = keystoreProperties.getProperty("storePassword")

            if (keyAliasProp != null && keyPasswordProp != null && storeFileProp != null && storePasswordProp != null) {
                keyAlias = keyAliasProp
                keyPassword = keyPasswordProp
                storeFile = file(storeFileProp)
                storePassword = storePasswordProp
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
