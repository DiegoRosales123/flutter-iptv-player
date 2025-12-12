import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(context, AppLocalizations);
    if (localizations == null) {
      // Fallback to Spanish if localizations are not available yet
      return AppLocalizations(const Locale('es', 'ES'));
    }
    return localizations;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('es', 'ES'), // Español
    Locale('en', 'US'), // English
    Locale('zh', 'CN'), // 中文 (Chinese)
    Locale('ru', 'RU'), // Русский (Russian)
  ];

  static final Map<String, Map<String, String>> _localizedValues = {
    'es_ES': {
      // General
      'app_name': 'IPTV Player Pro',
      'loading': 'Cargando...',
      'error': 'Error',
      'ok': 'OK',
      'cancel': 'Cancelar',
      'save': 'Guardar',
      'delete': 'Eliminar',
      'edit': 'Editar',
      'add': 'Agregar',
      'search': 'Buscar',
      'settings': 'Configuración',
      'yes': 'Sí',
      'no': 'No',

      // Dashboard
      'dashboard': 'Inicio',
      'channels': 'Canales',
      'movies': 'Películas',
      'series': 'Series',
      'live_tv': 'TV EN VIVO',
      'continue_watching': 'Continuar Viendo',
      'my_favorites': 'Mis Favoritos',
      'playlists': 'Listas',
      'configuration': 'Configuración',
      'epg_guide': 'Guía EPG',

      // Player
      'play': 'Reproducir',
      'pause': 'Pausar',
      'stop': 'Detener',
      'fullscreen': 'Pantalla Completa',
      'exit_fullscreen': 'Salir de Pantalla Completa',
      'volume': 'Volumen',
      'audio_track': 'Pista de Audio',
      'subtitles': 'Subtítulos',
      'none': 'Ninguno',

      // Categories
      'all': 'Todo',
      'categories': 'Categorías',
      'by_category': 'Por Categoría',

      // Settings
      'language': 'Idioma',
      'theme': 'Tema',
      'dark_mode': 'Modo Oscuro',
      'light_mode': 'Modo Claro',
      'about': 'Acerca de',
      'version': 'Versión',

      // Profiles
      'profiles': 'Perfiles',
      'create_profile': 'Crear Perfil',
      'edit_profile': 'Editar Perfil',
      'delete_profile': 'Eliminar Perfil',
      'profile_name': 'Nombre del Perfil',

      // Playlists
      'add_playlist': 'Agregar Lista',
      'edit_playlist': 'Editar Lista',
      'delete_playlist': 'Eliminar Lista',
      'playlist_name': 'Nombre de la Lista',
      'playlist_url': 'URL de la Lista',
      'playlist_type': 'Tipo de Lista',
      'm3u_file': 'Archivo M3U',
      'xtream_codes': 'Xtream Codes',
      'username': 'Usuario',
      'password': 'Contraseña',
      'server_url': 'URL del Servidor',
      'playlist_management': 'Gestión de Playlists',
      'new_playlist': 'Nueva Playlist',
      'no_playlists': 'Sin playlists',
      'add_first_playlist': 'Agrega tu primera playlist IPTV\npara comenzar a ver contenido',
      'help': 'Ayuda',

      // Messages
      'no_channels': 'No hay canales disponibles',
      'no_movies': 'No hay películas disponibles',
      'no_series': 'No hay series disponibles',
      'no_favorites': 'No hay favoritos',
      'no_recent': 'No hay canales recientes',
      'playlist_updated': 'Lista actualizada',
      'coming_soon': 'Próximamente',
      'confirm_exit': '¿Estás seguro que deseas cerrar la aplicación?',
      'exit': 'Salir',

      // Time
      'now_playing': 'Reproduciendo ahora',
      'next': 'Siguiente',
      'previous': 'Anterior',

      // Sort
      'sort_by_added': 'Ordenar por Fecha',
      'sort_by_name': 'Ordenar por Nombre',
      'sort_by_rating': 'Ordenar por Calificación',

      // Details
      'overview': 'Sinopsis',
      'views': 'Vistas',
      'rating': 'Calificación',

      // Theme Selector
      'select_theme': 'Seleccionar Tema',
      'theme_original': 'Original',
      'theme_original_desc': 'Tema azul cyan con estilo moderno',
      'theme_netflix': 'Netflix Dark',
      'theme_netflix_desc': 'Tema oscuro estilo Netflix',
      'theme_applied': 'Tema aplicado',
      'close': 'Cerrar',

      // Series
      'season': 'temporada',
      'seasons': 'temporadas',

      // Playlist Dialog
      'add_new_playlist_subtitle': 'Agrega una nueva playlist IPTV',
      'modify_playlist_subtitle': 'Modifica los datos de tu playlist',
      'playlist_name_label': 'Nombre de la playlist',
      'playlist_name_hint': 'Mi IPTV',
      'playlist_name_validation': 'Ingresa un nombre',
      'playlist_url_label': 'URL de la playlist',
      'playlist_url_hint': 'https://ejemplo.com/playlist.m3u',
      'playlist_url_validation': 'Ingresa la URL',
      'url_validation_protocol': 'La URL debe comenzar con http:// o https://',
      'server_host_label': 'Host del servidor',
      'server_host_hint': 'http://servidor.com:8080',
      'server_host_validation': 'Ingresa el host',
      'protocol_validation': 'Debe comenzar con http:// o https://',
      'username_label': 'Usuario',
      'username_hint': 'miusuario',
      'username_validation': 'Ingresa el usuario',
      'password_label': 'Contraseña',
      'password_hint': 'Tu contraseña',
      'password_validation': 'Ingresa la contraseña',
      'verify_credentials': 'Verificar credenciales',
      'verifying': 'Verificando...',
      'complete_all_fields': 'Completa todos los campos',
      'credentials_verified': 'Credenciales verificadas',
      'credentials_invalid': 'Credenciales inválidas',
      'add': 'Agregar',
      'save': 'Guardar',

      // Help Dialog
      'supported_formats': 'Formatos soportados:',
      'supported_formats_desc': 'M3U, M3U8, Xtream Codes API',
      'xtream_url': 'URL Xtream:',
      'xtream_url_desc': 'El sistema detecta automáticamente credenciales y carga el EPG',
      'epg': 'EPG:',
      'epg_desc': 'La guía de programación se carga automáticamente si está disponible',
      'update': 'Actualizar:',
      'update_desc': 'Usa el botón de refresh para recargar los canales',
      'understood': 'Entendido',

      // Loading Dialog
      'loading_playlist': 'Cargando playlist...',
      'updating_playlist': 'Actualizando playlist...',
      'downloading_channels': 'Descargando y procesando canales...',

      // Date
      'never': 'Nunca',

      // Playlist Info Dialog
      'information': 'Información',
      'name': 'Nombre',
      'channels_count': 'Canales',
      'updated': 'Actualizado',
      'authentication': 'Autenticación',
      'yes': 'Sí',
      'no': 'No',
      'url': 'URL:',
      'authenticated': 'Autenticado',
      'active': 'Activa',
      'refresh': 'Actualizar',
      'more_options': 'Más opciones',
      'channels': 'canales',
    },
    'en_US': {
      // General
      'app_name': 'IPTV Player Pro',
      'loading': 'Loading...',
      'error': 'Error',
      'ok': 'OK',
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'add': 'Add',
      'search': 'Search',
      'settings': 'Settings',
      'yes': 'Yes',
      'no': 'No',

      // Dashboard
      'dashboard': 'Dashboard',
      'channels': 'Channels',
      'movies': 'Movies',
      'series': 'Series',
      'live_tv': 'LIVE TV',
      'continue_watching': 'Continue Watching',
      'my_favorites': 'My Favorites',
      'playlists': 'Playlists',
      'configuration': 'Configuration',
      'epg_guide': 'EPG Guide',

      // Player
      'play': 'Play',
      'pause': 'Pause',
      'stop': 'Stop',
      'fullscreen': 'Fullscreen',
      'exit_fullscreen': 'Exit Fullscreen',
      'volume': 'Volume',
      'audio_track': 'Audio Track',
      'subtitles': 'Subtitles',
      'none': 'None',

      // Categories
      'all': 'All',
      'categories': 'Categories',
      'by_category': 'By Category',

      // Settings
      'language': 'Language',
      'theme': 'Theme',
      'dark_mode': 'Dark Mode',
      'light_mode': 'Light Mode',
      'about': 'About',
      'version': 'Version',

      // Profiles
      'profiles': 'Profiles',
      'create_profile': 'Create Profile',
      'edit_profile': 'Edit Profile',
      'delete_profile': 'Delete Profile',
      'profile_name': 'Profile Name',

      // Playlists
      'add_playlist': 'Add Playlist',
      'edit_playlist': 'Edit Playlist',
      'delete_playlist': 'Delete Playlist',
      'playlist_name': 'Playlist Name',
      'playlist_url': 'Playlist URL',
      'playlist_type': 'Playlist Type',
      'm3u_file': 'M3U File',
      'xtream_codes': 'Xtream Codes',
      'username': 'Username',
      'password': 'Password',
      'server_url': 'Server URL',
      'playlist_management': 'Playlist Management',
      'new_playlist': 'New Playlist',
      'no_playlists': 'No playlists',
      'add_first_playlist': 'Add your first IPTV playlist\nto start watching content',
      'help': 'Help',

      // Messages
      'no_channels': 'No channels available',
      'no_movies': 'No movies available',
      'no_series': 'No series available',
      'no_favorites': 'No favorites',
      'no_recent': 'No recent channels',
      'playlist_updated': 'Playlist updated',
      'coming_soon': 'Coming soon',
      'confirm_exit': 'Are you sure you want to exit?',
      'exit': 'Exit',

      // Time
      'now_playing': 'Now Playing',
      'next': 'Next',
      'previous': 'Previous',

      // Sort
      'sort_by_added': 'Sort by Date Added',
      'sort_by_name': 'Sort by Name',
      'sort_by_rating': 'Sort by Rating',

      // Details
      'overview': 'Overview',
      'views': 'Views',
      'rating': 'Rating',

      // Theme Selector
      'select_theme': 'Select Theme',
      'theme_original': 'Original',
      'theme_original_desc': 'Modern cyan blue theme',
      'theme_netflix': 'Netflix Dark',
      'theme_netflix_desc': 'Netflix-style dark theme',
      'theme_applied': 'Theme applied',
      'close': 'Close',

      // Series
      'season': 'season',
      'seasons': 'seasons',

      // Playlist Dialog
      'add_new_playlist_subtitle': 'Add a new IPTV playlist',
      'modify_playlist_subtitle': 'Modify your playlist data',
      'playlist_name_label': 'Playlist name',
      'playlist_name_hint': 'My IPTV',
      'playlist_name_validation': 'Enter a name',
      'playlist_url_label': 'Playlist URL',
      'playlist_url_hint': 'https://example.com/playlist.m3u',
      'playlist_url_validation': 'Enter the URL',
      'url_validation_protocol': 'URL must start with http:// or https://',
      'server_host_label': 'Server host',
      'server_host_hint': 'http://server.com:8080',
      'server_host_validation': 'Enter the host',
      'protocol_validation': 'Must start with http:// or https://',
      'username_label': 'Username',
      'username_hint': 'myusername',
      'username_validation': 'Enter username',
      'password_label': 'Password',
      'password_hint': 'Your password',
      'password_validation': 'Enter password',
      'verify_credentials': 'Verify credentials',
      'verifying': 'Verifying...',
      'complete_all_fields': 'Complete all fields',
      'credentials_verified': 'Credentials verified',
      'credentials_invalid': 'Invalid credentials',
      'add': 'Add',
      'save': 'Save',

      // Help Dialog
      'supported_formats': 'Supported formats:',
      'supported_formats_desc': 'M3U, M3U8, Xtream Codes API',
      'xtream_url': 'Xtream URL:',
      'xtream_url_desc': 'System automatically detects credentials and loads EPG',
      'epg': 'EPG:',
      'epg_desc': 'Program guide loads automatically if available',
      'update': 'Update:',
      'update_desc': 'Use the refresh button to reload channels',
      'understood': 'Understood',

      // Loading Dialog
      'loading_playlist': 'Loading playlist...',
      'updating_playlist': 'Updating playlist...',
      'downloading_channels': 'Downloading and processing channels...',

      // Date
      'never': 'Never',

      // Playlist Info Dialog
      'information': 'Information',
      'name': 'Name',
      'channels_count': 'Channels',
      'updated': 'Updated',
      'authentication': 'Authentication',
      'yes': 'Yes',
      'no': 'No',
      'url': 'URL:',
      'authenticated': 'Authenticated',
      'active': 'Active',
      'refresh': 'Refresh',
      'more_options': 'More options',
      'channels': 'channels',
    },
    'zh_CN': {
      // General
      'app_name': 'IPTV Player Pro',
      'loading': '加载中...',
      'error': '错误',
      'ok': '确定',
      'cancel': '取消',
      'save': '保存',
      'delete': '删除',
      'edit': '编辑',
      'add': '添加',
      'search': '搜索',
      'settings': '设置',
      'yes': '是',
      'no': '否',

      // Dashboard
      'dashboard': '主页',
      'channels': '频道',
      'movies': '电影',
      'series': '剧集',
      'live_tv': '直播电视',
      'continue_watching': '继续观看',
      'my_favorites': '我的收藏',
      'playlists': '播放列表',
      'configuration': '配置',
      'epg_guide': '节目指南',

      // Player
      'play': '播放',
      'pause': '暂停',
      'stop': '停止',
      'fullscreen': '全屏',
      'exit_fullscreen': '退出全屏',
      'volume': '音量',
      'audio_track': '音轨',
      'subtitles': '字幕',
      'none': '无',

      // Categories
      'all': '全部',
      'categories': '分类',
      'by_category': '按分类',

      // Settings
      'language': '语言',
      'theme': '主题',
      'dark_mode': '深色模式',
      'light_mode': '浅色模式',
      'about': '关于',
      'version': '版本',

      // Profiles
      'profiles': '用户配置',
      'create_profile': '创建配置',
      'edit_profile': '编辑配置',
      'delete_profile': '删除配置',
      'profile_name': '配置名称',

      // Playlists
      'add_playlist': '添加列表',
      'edit_playlist': '编辑列表',
      'delete_playlist': '删除列表',
      'playlist_name': '列表名称',
      'playlist_url': '列表网址',
      'playlist_type': '列表类型',
      'm3u_file': 'M3U文件',
      'xtream_codes': 'Xtream代码',
      'username': '用户名',
      'password': '密码',
      'server_url': '服务器网址',
      'playlist_management': '播放列表管理',
      'new_playlist': '新播放列表',
      'no_playlists': '没有播放列表',
      'add_first_playlist': '添加您的第一个IPTV播放列表\n开始观看内容',
      'help': '帮助',

      // Messages
      'no_channels': '没有可用频道',
      'no_movies': '没有可用电影',
      'no_series': '没有可用剧集',
      'no_favorites': '没有收藏',
      'no_recent': '没有最近频道',
      'playlist_updated': '列表已更新',
      'coming_soon': '即将推出',
      'confirm_exit': '确定要退出应用程序吗？',
      'exit': '退出',

      // Time
      'now_playing': '正在播放',
      'next': '下一个',
      'previous': '上一个',

      // Sort
      'sort_by_added': '按添加日期排序',
      'sort_by_name': '按名称排序',
      'sort_by_rating': '按评分排序',

      // Details
      'overview': '概述',
      'views': '观看次数',
      'rating': '评分',

      // Theme Selector
      'select_theme': '选择主题',
      'theme_original': '原始',
      'theme_original_desc': '现代青色蓝色主题',
      'theme_netflix': 'Netflix 暗色',
      'theme_netflix_desc': 'Netflix风格的暗色主题',
      'theme_applied': '主题已应用',
      'close': '关闭',

      // Series
      'season': '季',
      'seasons': '季',

      // Playlist Dialog
      'add_new_playlist_subtitle': '添加新的IPTV播放列表',
      'modify_playlist_subtitle': '修改您的播放列表数据',
      'playlist_name_label': '播放列表名称',
      'playlist_name_hint': '我的IPTV',
      'playlist_name_validation': '请输入名称',
      'playlist_url_label': '播放列表网址',
      'playlist_url_hint': 'https://example.com/playlist.m3u',
      'playlist_url_validation': '请输入网址',
      'url_validation_protocol': '网址必须以http://或https://开头',
      'server_host_label': '服务器主机',
      'server_host_hint': 'http://server.com:8080',
      'server_host_validation': '请输入主机',
      'protocol_validation': '必须以http://或https://开头',
      'username_label': '用户名',
      'username_hint': '我的用户名',
      'username_validation': '请输入用户名',
      'password_label': '密码',
      'password_hint': '您的密码',
      'password_validation': '请输入密码',
      'verify_credentials': '验证凭据',
      'verifying': '验证中...',
      'complete_all_fields': '请填写所有字段',
      'credentials_verified': '凭据已验证',
      'credentials_invalid': '凭据无效',
      'add': '添加',
      'save': '保存',

      // Help Dialog
      'supported_formats': '支持的格式：',
      'supported_formats_desc': 'M3U、M3U8、Xtream Codes API',
      'xtream_url': 'Xtream网址：',
      'xtream_url_desc': '系统自动检测凭据并加载EPG',
      'epg': 'EPG：',
      'epg_desc': '如果可用，节目指南会自动加载',
      'update': '更新：',
      'update_desc': '使用刷新按钮重新加载频道',
      'understood': '明白了',

      // Loading Dialog
      'loading_playlist': '加载播放列表中...',
      'updating_playlist': '更新播放列表中...',
      'downloading_channels': '正在下载和处理频道...',

      // Date
      'never': '从未',

      // Playlist Info Dialog
      'information': '信息',
      'name': '名称',
      'channels_count': '频道',
      'updated': '更新时间',
      'authentication': '认证',
      'yes': '是',
      'no': '否',
      'url': '网址：',
      'authenticated': '已认证',
      'active': '活动',
      'refresh': '刷新',
      'more_options': '更多选项',
      'channels': '频道',
    },
    'ru_RU': {
      // General
      'app_name': 'IPTV Player Pro',
      'loading': 'Загрузка...',
      'error': 'Ошибка',
      'ok': 'OK',
      'cancel': 'Отмена',
      'save': 'Сохранить',
      'delete': 'Удалить',
      'edit': 'Редактировать',
      'add': 'Добавить',
      'search': 'Поиск',
      'settings': 'Настройки',
      'yes': 'Да',
      'no': 'Нет',

      // Dashboard
      'dashboard': 'Главная',
      'channels': 'Каналы',
      'movies': 'Фильмы',
      'series': 'Сериалы',
      'live_tv': 'ПРЯМОЙ ЭФИР',
      'continue_watching': 'Продолжить просмотр',
      'my_favorites': 'Избранное',
      'playlists': 'Плейлисты',
      'configuration': 'Конфигурация',
      'epg_guide': 'Программа передач',

      // Player
      'play': 'Воспроизвести',
      'pause': 'Пауза',
      'stop': 'Стоп',
      'fullscreen': 'Полный экран',
      'exit_fullscreen': 'Выйти из полноэкранного режима',
      'volume': 'Громкость',
      'audio_track': 'Аудиодорожка',
      'subtitles': 'Субтитры',
      'none': 'Нет',

      // Categories
      'all': 'Все',
      'categories': 'Категории',
      'by_category': 'По категориям',

      // Settings
      'language': 'Язык',
      'theme': 'Тема',
      'dark_mode': 'Темный режим',
      'light_mode': 'Светлый режим',
      'about': 'О программе',
      'version': 'Версия',

      // Profiles
      'profiles': 'Профили',
      'create_profile': 'Создать профиль',
      'edit_profile': 'Редактировать профиль',
      'delete_profile': 'Удалить профиль',
      'profile_name': 'Имя профиля',

      // Playlists
      'add_playlist': 'Добавить плейлист',
      'edit_playlist': 'Редактировать плейлист',
      'delete_playlist': 'Удалить плейлист',
      'playlist_name': 'Название плейлиста',
      'playlist_url': 'URL плейлиста',
      'playlist_type': 'Тип плейлиста',
      'm3u_file': 'Файл M3U',
      'xtream_codes': 'Xtream Codes',
      'username': 'Имя пользователя',
      'password': 'Пароль',
      'server_url': 'URL сервера',
      'playlist_management': 'Управление плейлистами',
      'new_playlist': 'Новый плейлист',
      'no_playlists': 'Нет плейлистов',
      'add_first_playlist': 'Добавьте свой первый IPTV плейлист\nчтобы начать просмотр',
      'help': 'Помощь',

      // Messages
      'no_channels': 'Нет доступных каналов',
      'no_movies': 'Нет доступных фильмов',
      'no_series': 'Нет доступных сериалов',
      'no_favorites': 'Нет избранного',
      'no_recent': 'Нет недавних каналов',
      'playlist_updated': 'Плейлист обновлен',
      'coming_soon': 'Скоро',
      'confirm_exit': 'Вы уверены, что хотите выйти?',
      'exit': 'Выход',

      // Time
      'now_playing': 'Сейчас играет',
      'next': 'Следующий',
      'previous': 'Предыдущий',

      // Sort
      'sort_by_added': 'Сортировать по дате добавления',
      'sort_by_name': 'Сортировать по названию',
      'sort_by_rating': 'Сортировать по рейтингу',

      // Details
      'overview': 'Обзор',
      'views': 'Просмотры',
      'rating': 'Рейтинг',

      // Theme Selector
      'select_theme': 'Выбрать тему',
      'theme_original': 'Оригинальная',
      'theme_original_desc': 'Современная голубая тема',
      'theme_netflix': 'Netflix Темная',
      'theme_netflix_desc': 'Темная тема в стиле Netflix',
      'theme_applied': 'Тема применена',
      'close': 'Закрыть',

      // Series
      'season': 'сезон',
      'seasons': 'сезона',

      // Playlist Dialog
      'add_new_playlist_subtitle': 'Добавить новый IPTV плейлист',
      'modify_playlist_subtitle': 'Изменить данные плейлиста',
      'playlist_name_label': 'Название плейлиста',
      'playlist_name_hint': 'Мой IPTV',
      'playlist_name_validation': 'Введите название',
      'playlist_url_label': 'URL плейлиста',
      'playlist_url_hint': 'https://example.com/playlist.m3u',
      'playlist_url_validation': 'Введите URL',
      'url_validation_protocol': 'URL должен начинаться с http:// или https://',
      'server_host_label': 'Хост сервера',
      'server_host_hint': 'http://server.com:8080',
      'server_host_validation': 'Введите хост',
      'protocol_validation': 'Должен начинаться с http:// или https://',
      'username_label': 'Имя пользователя',
      'username_hint': 'моеимя',
      'username_validation': 'Введите имя пользователя',
      'password_label': 'Пароль',
      'password_hint': 'Ваш пароль',
      'password_validation': 'Введите пароль',
      'verify_credentials': 'Проверить учетные данные',
      'verifying': 'Проверка...',
      'complete_all_fields': 'Заполните все поля',
      'credentials_verified': 'Учетные данные проверены',
      'credentials_invalid': 'Неверные учетные данные',
      'add': 'Добавить',
      'save': 'Сохранить',

      // Help Dialog
      'supported_formats': 'Поддерживаемые форматы:',
      'supported_formats_desc': 'M3U, M3U8, Xtream Codes API',
      'xtream_url': 'URL Xtream:',
      'xtream_url_desc': 'Система автоматически определяет учетные данные и загружает EPG',
      'epg': 'EPG:',
      'epg_desc': 'Программа передач загружается автоматически, если доступна',
      'update': 'Обновить:',
      'update_desc': 'Используйте кнопку обновления для перезагрузки каналов',
      'understood': 'Понятно',

      // Loading Dialog
      'loading_playlist': 'Загрузка плейлиста...',
      'updating_playlist': 'Обновление плейлиста...',
      'downloading_channels': 'Загрузка и обработка каналов...',

      // Date
      'never': 'Никогда',

      // Playlist Info Dialog
      'information': 'Информация',
      'name': 'Название',
      'channels_count': 'Каналы',
      'updated': 'Обновлено',
      'authentication': 'Аутентификация',
      'yes': 'Да',
      'no': 'Нет',
      'url': 'URL:',
      'authenticated': 'Аутентифицирован',
      'active': 'Активный',
      'refresh': 'Обновить',
      'more_options': 'Дополнительные параметры',
      'channels': 'каналы',
    },
  };

  String translate(String key) {
    // Try with full locale (e.g., 'en_US')
    String languageCode = '${locale.languageCode}_${locale.countryCode}';
    String? value = _localizedValues[languageCode]?[key];

    // If not found, try with just language code + default country
    if (value == null) {
      final Map<String, String> defaultCountries = {
        'en': 'en_US',
        'es': 'es_ES',
        'zh': 'zh_CN',
        'ru': 'ru_RU',
      };
      final defaultLocale = defaultCountries[locale.languageCode];
      if (defaultLocale != null) {
        value = _localizedValues[defaultLocale]?[key];
      }
    }

    return value ?? key;
  }

  // Getters for common translations
  String get appName => translate('app_name');
  String get loading => translate('loading');
  String get error => translate('error');
  String get ok => translate('ok');
  String get cancel => translate('cancel');
  String get save => translate('save');
  String get delete => translate('delete');
  String get edit => translate('edit');
  String get add => translate('add');
  String get search => translate('search');
  String get settings => translate('settings');
  String get yes => translate('yes');
  String get no => translate('no');

  String get dashboard => translate('dashboard');
  String get channels => translate('channels');
  String get movies => translate('movies');
  String get series => translate('series');
  String get liveTV => translate('live_tv');
  String get continueWatching => translate('continue_watching');
  String get myFavorites => translate('my_favorites');
  String get playlists => translate('playlists');
  String get configuration => translate('configuration');
  String get epgGuide => translate('epg_guide');

  String get play => translate('play');
  String get pause => translate('pause');
  String get stop => translate('stop');
  String get fullscreen => translate('fullscreen');
  String get exitFullscreen => translate('exit_fullscreen');
  String get volume => translate('volume');
  String get audioTrack => translate('audio_track');
  String get subtitles => translate('subtitles');
  String get none => translate('none');

  String get all => translate('all');
  String get categories => translate('categories');
  String get byCategory => translate('by_category');

  String get language => translate('language');
  String get theme => translate('theme');
  String get darkMode => translate('dark_mode');
  String get lightMode => translate('light_mode');
  String get about => translate('about');
  String get version => translate('version');

  String get profiles => translate('profiles');
  String get createProfile => translate('create_profile');
  String get editProfile => translate('edit_profile');
  String get deleteProfile => translate('delete_profile');
  String get profileName => translate('profile_name');

  String get addPlaylist => translate('add_playlist');
  String get editPlaylist => translate('edit_playlist');
  String get deletePlaylist => translate('delete_playlist');
  String get playlistName => translate('playlist_name');
  String get playlistUrl => translate('playlist_url');
  String get playlistType => translate('playlist_type');
  String get m3uFile => translate('m3u_file');
  String get xtreamCodes => translate('xtream_codes');
  String get username => translate('username');
  String get password => translate('password');
  String get serverUrl => translate('server_url');

  String get noChannels => translate('no_channels');
  String get noMovies => translate('no_movies');
  String get noSeries => translate('no_series');
  String get noFavorites => translate('no_favorites');
  String get noRecent => translate('no_recent');
  String get playlistUpdated => translate('playlist_updated');
  String get comingSoon => translate('coming_soon');
  String get confirmExit => translate('confirm_exit');
  String get exit => translate('exit');

  String get nowPlaying => translate('now_playing');
  String get next => translate('next');
  String get previous => translate('previous');

  String get sortByAdded => translate('sort_by_added');
  String get sortByName => translate('sort_by_name');
  String get sortByRating => translate('sort_by_rating');

  String get overview => translate('overview');
  String get views => translate('views');
  String get rating => translate('rating');

  String get selectTheme => translate('select_theme');
  String get themeOriginal => translate('theme_original');
  String get themeOriginalDesc => translate('theme_original_desc');
  String get themeNetflix => translate('theme_netflix');
  String get themeNetflixDesc => translate('theme_netflix_desc');
  String get themeApplied => translate('theme_applied');
  String get close => translate('close');

  String get season => translate('season');
  String get seasons => translate('seasons');

  String get playlistManagement => translate('playlist_management');
  String get newPlaylist => translate('new_playlist');
  String get noPlaylists => translate('no_playlists');
  String get addFirstPlaylist => translate('add_first_playlist');
  String get help => translate('help');

  // Playlist Dialog
  String get addNewPlaylistSubtitle => translate('add_new_playlist_subtitle');
  String get modifyPlaylistSubtitle => translate('modify_playlist_subtitle');
  String get playlistNameLabel => translate('playlist_name_label');
  String get playlistNameHint => translate('playlist_name_hint');
  String get playlistNameValidation => translate('playlist_name_validation');
  String get playlistUrlLabel => translate('playlist_url_label');
  String get playlistUrlHint => translate('playlist_url_hint');
  String get playlistUrlValidation => translate('playlist_url_validation');
  String get urlValidationProtocol => translate('url_validation_protocol');
  String get serverHostLabel => translate('server_host_label');
  String get serverHostHint => translate('server_host_hint');
  String get serverHostValidation => translate('server_host_validation');
  String get protocolValidation => translate('protocol_validation');
  String get usernameLabel => translate('username_label');
  String get usernameHint => translate('username_hint');
  String get usernameValidation => translate('username_validation');
  String get passwordLabel => translate('password_label');
  String get passwordHint => translate('password_hint');
  String get passwordValidation => translate('password_validation');
  String get verifyCredentials => translate('verify_credentials');
  String get verifying => translate('verifying');
  String get completeAllFields => translate('complete_all_fields');
  String get credentialsVerified => translate('credentials_verified');
  String get credentialsInvalid => translate('credentials_invalid');

  // Help Dialog
  String get supportedFormats => translate('supported_formats');
  String get supportedFormatsDesc => translate('supported_formats_desc');
  String get xtreamUrl => translate('xtream_url');
  String get xtreamUrlDesc => translate('xtream_url_desc');
  String get epg => translate('epg');
  String get epgDesc => translate('epg_desc');
  String get update => translate('update');
  String get updateDesc => translate('update_desc');
  String get understood => translate('understood');

  // Loading Dialog
  String get loadingPlaylist => translate('loading_playlist');
  String get updatingPlaylist => translate('updating_playlist');
  String get downloadingChannels => translate('downloading_channels');

  // Date
  String get never => translate('never');

  // Playlist Info Dialog
  String get information => translate('information');
  String get name => translate('name');
  String get channelsCount => translate('channels_count');
  String get updated => translate('updated');
  String get authentication => translate('authentication');
  String get url => translate('url');
  String get authenticated => translate('authenticated');
  String get active => translate('active');
  String get refresh => translate('refresh');
  String get moreOptions => translate('more_options');
  String get channelsLowercase => translate('channels');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['es', 'en', 'zh', 'ru'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
