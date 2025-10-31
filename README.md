# IPTV Player Pro

Una aplicación profesional de reproducción IPTV construida con Flutter, inspirada en TiviMate.

## Características

- Reproducción de canales IPTV en vivo
- Soporte para playlists M3U/M3U8
- Gestión de múltiples playlists
- Sistema de favoritos
- Búsqueda y filtrado de canales
- Organización por grupos/categorías
- Reproductor de video con controles personalizados
- Base de datos local para almacenamiento persistente
- Interfaz moderna y responsive
- Soporte para autenticación (Xtream Codes API)

## Tecnologías Utilizadas

- **Flutter**: Framework de UI multiplataforma
- **media_kit**: Reproductor de video basado en libmpv/FFmpeg
- **Isar**: Base de datos NoSQL local de alta velocidad
- **Material Design 3**: Diseño moderno y adaptable

## Requisitos Previos

### Instalar Flutter

1. Descarga Flutter SDK desde: https://docs.flutter.dev/get-started/install/windows
2. Extrae el archivo ZIP en `C:\src\flutter`
3. Agrega Flutter al PATH del sistema:
   - Busca "Variables de entorno" en Windows
   - Edita la variable PATH
   - Agrega: `C:\src\flutter\bin`

4. Verifica la instalación:
```bash
flutter doctor
```

### Instalar Dependencias de Windows

```bash
flutter doctor
```

Esto te indicará qué necesitas instalar:
- Visual Studio 2022 (con "Desktop development with C++")
- Windows SDK

## Instalación del Proyecto

1. Clona o descarga este proyecto

2. Navega a la carpeta del proyecto:
```bash
cd C:\Users\root\Desktop\IPTV\iptv_player
```

3. Instala las dependencias:
```bash
flutter pub get
```

4. Genera el código de Isar:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## Ejecutar la Aplicación

### En modo desarrollo:
```bash
flutter run -d windows
```

### Construir para Windows:
```bash
flutter build windows
```

El ejecutable estará en: `build\windows\runner\Release\`

## Empaquetar como MSIX (Windows Store)

1. Configura el archivo `pubspec.yaml` con tu información:
   - publisher_display_name
   - identity_name
   - logo_path

2. Genera el paquete MSIX:
```bash
flutter pub run msix:create
```

El paquete MSIX estará en: `build\windows\runner\Release\`

## Uso

### Agregar una Playlist

1. Haz clic en el icono de "+" en la pantalla principal
2. Ingresa los siguientes datos:
   - Nombre de la playlist
   - URL del archivo M3U/M3U8
   - (Opcional) Usuario y contraseña si tu servicio lo requiere

### Ejemplo de URL M3U:
```
http://example.com/playlist.m3u
```

### Ejemplo con autenticación Xtream:
```
URL: http://server.com:8080/get.php
Usuario: tu_usuario
Contraseña: tu_contraseña
```

### Reproducir un Canal

1. Busca o filtra el canal deseado
2. Haz clic en el canal
3. El reproductor se abrirá automáticamente
4. Toca la pantalla para mostrar/ocultar controles

## Estructura del Proyecto

```
lib/
├── models/           # Modelos de datos (Channel, Playlist, Profile)
├── services/         # Servicios (Database, M3U Parser)
├── screens/          # Pantallas de la aplicación
│   ├── home_screen.dart
│   ├── video_player_screen.dart
│   └── playlist_manager_screen.dart
└── main.dart         # Punto de entrada de la aplicación
```

## Características Pendientes

- [ ] Sistema de perfiles de usuario con UI
- [ ] EPG (Guía electrónica de programación)
- [ ] Grabación de canales
- [ ] Timeshift (pausa en vivo)
- [ ] Modo Picture-in-Picture
- [ ] Controles parentales
- [ ] Temas personalizables
- [ ] Sincronización en la nube
- [ ] Soporte para subtítulos
- [ ] Audio multicanal

## Solución de Problemas

### Error: "flutter: command not found"
- Verifica que Flutter esté en tu PATH
- Reinicia tu terminal o PowerShell

### Error al compilar Isar
```bash
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

### Error de reproducción de video
- Asegúrate de que la URL del canal sea válida
- Verifica tu conexión a internet
- Algunos canales pueden requerir VPN

## Licencia

Este proyecto es de código abierto y está disponible bajo la licencia MIT.

## Créditos

Inspirado en TiviMate IPTV Player y el Proyecto esta Creado por mi(Diego)
