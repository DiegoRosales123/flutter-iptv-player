# Comandos de Instalación - IPTV Player Pro

## 1. Descargar Flutter SDK

### Opción A: Descarga Manual (Más Rápida)
Ve a tu navegador y descarga desde:
```
https://docs.flutter.dev/get-started/install/windows
```
Haz clic en el botón azul "flutter_windows_3.24.5-stable.zip" (~1.5 GB)

### Opción B: Con PowerShell (puede ser lento)
```powershell
# Descarga Flutter (esto puede tardar mucho tiempo)
Invoke-WebRequest -Uri "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip" -OutFile "$env:USERPROFILE\Downloads\flutter.zip"
```

## 2. Extraer Flutter

Una vez descargado, extrae Flutter:

```powershell
# Crear directorio
New-Item -Path "C:\src" -ItemType Directory -Force

# Extraer Flutter (espera a que termine la descarga primero!)
Expand-Archive -Path "$env:USERPROFILE\Downloads\flutter.zip" -DestinationPath "C:\src\" -Force
```

## 3. Agregar Flutter al PATH

```powershell
# Agregar Flutter al PATH del usuario actual
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$flutterPath = "C:\src\flutter\bin"

if ($userPath -notlike "*$flutterPath*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$flutterPath", "User")
    Write-Host "Flutter agregado al PATH. Cierra y abre PowerShell nuevamente."
}
```

**IMPORTANTE: Después de ejecutar esto, cierra y abre PowerShell nuevamente**

## 4. Verificar Instalación de Flutter

Abre una nueva ventana de PowerShell y ejecuta:

```powershell
flutter doctor
```

Esto te dirá qué más necesitas instalar.

## 5. Instalar Visual Studio 2022 (Necesario)

Descarga e instala desde:
```
https://visualstudio.microsoft.com/vs/community/
```

Durante la instalación, selecciona:
- ✅ "Desarrollo para el escritorio con C++"
- ✅ Windows SDK

## 6. Configurar el Proyecto IPTV Player

```powershell
# Ir a la carpeta del proyecto
cd C:\Users\root\Desktop\IPTV\iptv_player

# Instalar dependencias
flutter pub get

# Generar código de base de datos (puede tardar)
flutter pub run build_runner build --delete-conflicting-outputs
```

## 7. Ejecutar la Aplicación

```powershell
# Ejecutar en modo desarrollo
flutter run -d windows

# O ejecutar en modo release (más rápido)
flutter run -d windows --release
```

## 8. Compilar Ejecutable Final

```powershell
# Compilar la aplicación
flutter build windows --release

# El ejecutable estará en:
# build\windows\x64\runner\Release\iptv_player.exe
```

## Comandos Útiles

```powershell
# Limpiar builds anteriores
flutter clean

# Ver dispositivos disponibles
flutter devices

# Actualizar Flutter
flutter upgrade

# Ver logs
flutter logs

# Analizar código
flutter analyze
```

## Si Flutter ya está instalado en otra ubicación

```powershell
# Verificar dónde está Flutter
where.exe flutter

# Ver versión
flutter --version
```

## Solución Rápida de Problemas

### "flutter no se reconoce como comando"
```powershell
# Verifica el PATH
$env:Path -split ';' | Select-String flutter

# Si no aparece, vuelve a ejecutar el paso 3 y reinicia PowerShell
```

### Error de permisos al extraer
```powershell
# Ejecuta PowerShell como Administrador (clic derecho -> Ejecutar como administrador)
```

### Descarga interrumpida
```powershell
# Elimina el archivo parcial
Remove-Item "$env:USERPROFILE\Downloads\flutter.zip" -Force

# Vuelve a descargar
```

## Resumen de Pasos (Copy-Paste Rápido)

```powershell
# 1. Descargar Flutter manualmente desde el navegador
# https://docs.flutter.dev/get-started/install/windows

# 2. Extraer (cambia la ruta si descargaste en otro lugar)
New-Item -Path "C:\src" -ItemType Directory -Force
Expand-Archive -Path "$env:USERPROFILE\Downloads\flutter_windows_3.24.5-stable.zip" -DestinationPath "C:\src\" -Force

# 3. Agregar al PATH
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
[Environment]::SetEnvironmentVariable("Path", "$userPath;C:\src\flutter\bin", "User")

# 4. REINICIAR POWERSHELL, luego:
flutter doctor

# 5. Configurar proyecto
cd C:\Users\root\Desktop\IPTV\iptv_player
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs

# 6. Ejecutar
flutter run -d windows --release
```

## URLs de Descarga Directa

- **Flutter SDK**: https://docs.flutter.dev/get-started/install/windows
- **Visual Studio 2022**: https://visualstudio.microsoft.com/vs/community/
- **Git for Windows**: https://git-scm.com/download/win

¡Listo! Después de estos pasos, tu aplicación IPTV estará funcionando. 🚀
