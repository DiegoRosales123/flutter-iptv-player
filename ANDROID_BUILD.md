# 📱 Guía de Compilación para Android

Esta guía te ayudará a compilar IPTV Player Pro para Android.

## 📋 Requisitos Previos

1. **Flutter SDK** instalado (versión 3.0.0 o superior)
2. **Android Studio** con:
   - Android SDK (API 21 o superior)
   - Android SDK Command-line Tools
   - Android SDK Build-Tools
3. **Java Development Kit (JDK)** (versión 17 o superior recomendada)
4. Un dispositivo Android o emulador configurado

## 🔧 Configuración Inicial

### 1. Verificar instalación de Flutter

```bash
flutter doctor
```

Asegúrate de que todos los componentes necesarios estén instalados.

### 2. Configurar variables de entorno

Añade estas variables a tu sistema:

- `ANDROID_HOME`: ruta a tu SDK de Android
- `JAVA_HOME`: ruta a tu JDK

### 3. Aceptar licencias de Android

```bash
flutter doctor --android-licenses
```

## 🏗️ Compilar la Aplicación

### Modo Debug (para pruebas)

```bash
# Asegúrate de estar en el directorio del proyecto
cd flutter-iptv-player

# Obtener dependencias
flutter pub get

# Conecta tu dispositivo Android o inicia un emulador

# Compilar y ejecutar
flutter run
```

### Modo Release (APK para distribución)

```bash
# Generar APK
flutter build apk --release

# El APK se generará en: build/app/outputs/flutter-apk/app-release.apk
```

### App Bundle (para Google Play Store)

```bash
# Generar App Bundle
flutter build appbundle --release

# El archivo se generará en: build/app/outputs/bundle/release/app-release.aab
```

## 📦 Instalar APK en Dispositivo

### Vía ADB (Android Debug Bridge)

```bash
# Instalar el APK generado
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Vía Flutter

```bash
# Instalar directamente
flutter install
```

## 🔐 Firmar la Aplicación (Opcional para Release)

### 1. Crear un keystore

```bash
keytool -genkey -v -keystore ~/iptv-player-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias iptvplayer
```

### 2. Configurar key.properties

Crea un archivo `android/key.properties`:

```properties
storePassword=tu_password_store
keyPassword=tu_password_key
keyAlias=iptvplayer
storeFile=/ruta/a/iptv-player-key.jks
```

### 3. Actualizar build.gradle

Edita `android/app/build.gradle` y añade:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    ...
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

## 📱 Características de la Versión Android

- ✅ Diseño responsivo optimizado para móviles y tablets
- ✅ Navegación mediante Drawer (menú lateral)
- ✅ Soporte para pantallas de diferentes tamaños
- ✅ Optimización de rendimiento
- ✅ Soporte multi-idioma (Español, Inglés, Chino, Ruso)
- ✅ Wake Lock para prevenir que la pantalla se apague durante reproducción
- ✅ Soporte para HTTP y HTTPS (cleartext traffic habilitado)

## 🎨 Diseño Responsivo

La aplicación se adapta automáticamente a diferentes tamaños de pantalla:

- **Móvil** (< 650px): Layout vertical con menú lateral (Drawer)
- **Tablet** (650-1100px): Layout adaptativo con elementos más grandes
- **Desktop** (> 1100px): Layout horizontal completo

## 🔧 Resolución de Problemas

### Error: "Gradle version incompatible"

Actualiza la versión de Gradle en `android/gradle/wrapper/gradle-wrapper.properties`:

```properties
distributionUrl=https\://services.gradle.org/distributions/gradle-8.3-all.zip
```

### Error: "SDK location not found"

Crea un archivo `android/local.properties`:

```properties
sdk.dir=C:\\Users\\TuUsuario\\AppData\\Local\\Android\\sdk
```

(Ajusta la ruta según tu instalación)

### Error de permisos de Internet

Verifica que `android/app/src/main/AndroidManifest.xml` contenga:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
```

### App se cierra al reproducir video

Asegúrate de tener los permisos necesarios:

```xml
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
```

## 📊 Requisitos del Dispositivo

### Mínimos
- Android 5.0 (API 21) o superior
- 2 GB de RAM
- 100 MB de espacio libre

### Recomendados
- Android 8.0 (API 26) o superior
- 4 GB de RAM
- 200 MB de espacio libre
- Conexión a Internet estable

## 🚀 Optimización de Rendimiento

Para mejorar el rendimiento en Android:

```bash
# Compilar con optimizaciones
flutter build apk --release --split-per-abi
```

Esto generará APKs separados para cada arquitectura (ARM, ARM64, x86, x86_64), reduciendo el tamaño de descarga.

## 📝 Notas Adicionales

- La aplicación usa `media_kit` para reproducción de video, que es compatible con Android
- El diseño responsivo se activa automáticamente según el tamaño de pantalla
- Los permisos de Internet están preconfigurados
- El Wake Lock mantiene la pantalla encendida durante la reproducción

## 🆘 Soporte

Si encuentras problemas:

1. Ejecuta `flutter doctor -v` y revisa los mensajes
2. Limpia el proyecto: `flutter clean && flutter pub get`
3. Revisa los logs: `flutter logs`
4. Abre un issue en GitHub con los detalles del problema

---

**¡Feliz desarrollo! 🎉**
