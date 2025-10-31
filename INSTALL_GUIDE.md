# Guía de Instalación Completa - IPTV Player Pro

## Paso 1: Instalar Flutter SDK

### Opción A: Descarga Manual (Recomendada)

1. Ve a https://docs.flutter.dev/get-started/install/windows
2. Descarga "Flutter SDK" (archivo ZIP de ~1.5 GB)
3. **IMPORTANTE**: Espera a que la descarga termine completamente antes de extraer
4. Extrae el archivo en `C:\src\flutter`
5. Agrega Flutter al PATH:
   - Presiona Windows + R, escribe `sysdm.cpl` y presiona Enter
   - Ve a la pestaña "Opciones avanzadas"
   - Haz clic en "Variables de entorno"
   - En "Variables del sistema", busca "Path" y haz clic en "Editar"
   - Haz clic en "Nuevo" y agrega: `C:\src\flutter\bin`
   - Haz clic en "Aceptar" en todas las ventanas

6. **Reinicia PowerShell o la terminal**

7. Verifica la instalación:
```powershell
flutter doctor
```

### Opción B: Usando Chocolatey

Si tienes Chocolatey instalado:
```powershell
choco install flutter
```

## Paso 2: Instalar Dependencias de Windows

Flutter doctor te indicará qué necesitas instalar:

### Visual Studio 2022 (Community Edition - Gratis)

1. Descarga desde: https://visualstudio.microsoft.com/downloads/
2. Durante la instalación, selecciona:
   - **"Desarrollo para el escritorio con C++"**
   - **Windows SDK**

### Git for Windows (si no lo tienes)

1. Descarga desde: https://git-scm.com/download/win
2. Instala con las opciones predeterminadas

## Paso 3: Configurar el Proyecto

1. Abre PowerShell o Terminal en la carpeta del proyecto:
```powershell
cd C:\Users\root\Desktop\IPTV\iptv_player
```

2. Instala las dependencias de Flutter:
```powershell
flutter pub get
```

3. Genera el código de Isar (base de datos):
```powershell
flutter pub run build_runner build --delete-conflicting-outputs
```

Este paso puede tardar varios minutos la primera vez.

## Paso 4: Ejecutar la Aplicación

### En modo desarrollo:
```powershell
flutter run -d windows
```

La aplicación se compilará y ejecutará. La primera compilación puede tardar 5-10 minutos.

### En modo release (más rápido):
```powershell
flutter run -d windows --release
```

## Paso 5: Compilar Ejecutable

Para crear un ejecutable standalone:

```powershell
flutter build windows --release
```

El ejecutable estará en:
```
C:\Users\root\Desktop\IPTV\iptv_player\build\windows\x64\runner\Release\
```

Puedes copiar toda la carpeta `Release` a cualquier lugar y ejecutar `iptv_player.exe`

## Paso 6: Crear Paquete MSIX (Opcional)

Para crear un paquete instalable para Windows:

1. Edita `pubspec.yaml` y actualiza la sección `msix_config`:
   - Cambia `publisher_display_name` a tu nombre
   - Cambia `identity_name` a un identificador único

2. Genera el certificado (primera vez):
```powershell
flutter pub run msix:create --certificate-path C:\cert.pfx --certificate-password 1234
```

3. Crea el paquete MSIX:
```powershell
flutter pub run msix:create
```

El archivo MSIX estará en:
```
C:\Users\root\Desktop\IPTV\iptv_player\build\windows\x64\runner\Release\iptv_player.msix
```

## Solución de Problemas Comunes

### Error: "flutter: command not found"
- **Solución**: Reinicia tu terminal o PowerShell después de agregar Flutter al PATH
- Verifica que Flutter está en el PATH: `echo $env:Path`

### Error: "Waiting for another flutter command to release the startup lock"
- **Solución**:
```powershell
taskkill /F /IM dart.exe
```

### Error al compilar Isar
```powershell
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

### Error: "No se encuentra Visual Studio"
- Asegúrate de instalar Visual Studio 2022 con "Desarrollo para escritorio con C++"
- Ejecuta `flutter doctor` para verificar

### Error: "Failed to load dynamic library"
- Ejecuta en modo release: `flutter run -d windows --release`

### La app no reproduce video
- Verifica que la URL del canal sea válida
- Algunos canales requieren VPN
- Prueba con una playlist de ejemplo primero

## Recursos Adicionales

- Documentación de Flutter: https://docs.flutter.dev/
- Flutter para Windows: https://docs.flutter.dev/platform-integration/windows/building
- media_kit: https://pub.dev/packages/media_kit
- Isar Database: https://isar.dev/

## Comandos Útiles

```powershell
# Ver dispositivos disponibles
flutter devices

# Limpiar build anterior
flutter clean

# Actualizar dependencias
flutter pub upgrade

# Ver logs en tiempo real
flutter logs

# Analizar el código
flutter analyze

# Ejecutar tests
flutter test
```

## Próximos Pasos Después de Instalar

1. **Agregar una playlist de prueba**:
   - Busca en internet "free iptv m3u playlist"
   - Copia la URL
   - Agrégala en la app

2. **Personalizar la app**:
   - Cambia el nombre en `pubspec.yaml`
   - Agrega tu logo en `assets/icon.png`
   - Modifica los colores en `main.dart`

3. **Contribuir**:
   - Reporta bugs
   - Sugiere nuevas características
   - Comparte playlists de prueba (públicas)

## Estructura de Archivos Importante

```
iptv_player/
├── lib/
│   ├── main.dart                    # Punto de entrada
│   ├── models/                      # Modelos de datos
│   ├── services/                    # Lógica de negocio
│   └── screens/                     # Interfaces de usuario
├── assets/                          # Imágenes y recursos
├── pubspec.yaml                     # Configuración del proyecto
└── README.md                        # Documentación
```

## Contacto y Soporte

Si encuentras problemas:
1. Revisa esta guía completa
2. Ejecuta `flutter doctor -v` y revisa los errores
3. Busca el error en Google/Stack Overflow
4. Abre un issue en el repositorio con los detalles del error

¡Disfruta de tu nueva app IPTV! 📺
