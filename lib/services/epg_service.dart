import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:isar/isar.dart';
import '../models/epg.dart';
import 'database_service.dart';

class XtreamCredentials {
  final String server;
  final String username;
  final String password;

  XtreamCredentials({
    required this.server,
    required this.username,
    required this.password,
  });

  // Build EPG URL for Xtream Codes API
  String get epgUrl => '$server/xmltv.php?username=$username&password=$password';

  // Build API info URL
  String get apiInfoUrl => '$server/player_api.php?username=$username&password=$password';

  // Build live streams URL
  String get liveStreamsUrl => '$server/player_api.php?username=$username&password=$password&action=get_live_streams';

  // Build EPG for specific stream
  String epgForStreamUrl(String streamId) =>
      '$server/player_api.php?username=$username&password=$password&action=get_simple_data_table&stream_id=$streamId';
}

class EpgService {

  /// Extract Xtream Codes credentials from M3U URL
  static XtreamCredentials? parseXtreamUrl(String url) {
    try {
      final uri = Uri.parse(url);

      // Check if it's an Xtream Codes URL
      // Format: http://server:port/get.php?username=X&password=Y&type=m3u_plus
      // Or: http://server:port/player_api.php?username=X&password=Y

      final username = uri.queryParameters['username'];
      final password = uri.queryParameters['password'];

      if (username != null && password != null) {
        // Build server URL (protocol + host + port)
        // Always include port if it's specified in the original URL
        String server;
        if (uri.hasPort && uri.port != 0) {
          server = '${uri.scheme}://${uri.host}:${uri.port}';
        } else {
          server = '${uri.scheme}://${uri.host}';
        }

        print('EPG Service - Server detectado: $server');
        print('EPG Service - Usuario: $username');

        return XtreamCredentials(
          server: server,
          username: username,
          password: password,
        );
      }
    } catch (e) {
      print('Error parsing Xtream URL: $e');
    }
    return null;
  }

  /// Load EPG automatically from M3U/Xtream URL
  static Future<Map<String, dynamic>> loadEpgFromPlaylistUrl(String playlistUrl) async {
    final credentials = parseXtreamUrl(playlistUrl);

    if (credentials == null) {
      return {
        'success': false,
        'message': 'No se detectaron credenciales Xtream Codes en la URL',
        'channels': 0,
        'programs': 0,
      };
    }

    // Lista de URLs EPG a intentar
    final epgUrls = [
      credentials.epgUrl,  // /xmltv.php
      '${credentials.server}/epg.xml?username=${credentials.username}&password=${credentials.password}',
      '${credentials.server}/epg?username=${credentials.username}&password=${credentials.password}',
    ];

    for (final epgUrl in epgUrls) {
      try {
        print('EPG Service - Intentando: $epgUrl');

        final response = await http.get(
          Uri.parse(epgUrl),
          headers: {
            'Accept': 'application/xml, text/xml, */*',
            'User-Agent': 'IPTV Player Pro/1.0',
          },
        ).timeout(const Duration(seconds: 120));

        print('EPG Service - Status: ${response.statusCode}');
        print('EPG Service - Content length: ${response.bodyBytes.length} bytes');

        if (response.statusCode == 200 && response.bodyBytes.length > 100) {
          String content = response.body;

          // Handle encoding
          if (!_isValidUtf8(content) || content.contains('Ã') || content.contains('Â')) {
            content = latin1.decode(response.bodyBytes);
          }

          // Check if it's valid XMLTV
          if (content.contains('<tv') || content.contains('<programme') || content.contains('<?xml')) {
            print('EPG Service - XML válido detectado, parseando...');
            await parseXmltvEpg(content);

            final stats = await getEpgStats();
            print('EPG Service - Resultado: ${stats['channels']} canales, ${stats['programs']} programas');

            if ((stats['programs'] ?? 0) > 0) {
              return {
                'success': true,
                'message': 'EPG cargado correctamente',
                'channels': stats['channels'],
                'programs': stats['programs'],
                'source': 'xmltv',
              };
            }
          }

          // Try JSON format
          try {
            if (content.trim().startsWith('{') || content.trim().startsWith('[')) {
              final jsonData = json.decode(content);
              if (jsonData is Map || jsonData is List) {
                await _parseJsonEpg(jsonData, credentials);
                final stats = await getEpgStats();
                if ((stats['programs'] ?? 0) > 0) {
                  return {
                    'success': true,
                    'message': 'EPG cargado desde API JSON',
                    'channels': stats['channels'],
                    'programs': stats['programs'],
                    'source': 'json_api',
                  };
                }
              }
            }
          } catch (_) {}
        }
      } catch (e) {
        print('EPG Service - Error con $epgUrl: $e');
        continue; // Intentar siguiente URL
      }
    }

    // Si llegamos aquí, ninguna URL funcionó
    return {
      'success': false,
      'message': 'No se encontró EPG disponible en el servidor',
      'channels': 0,
      'programs': 0,
    };
  }

  /// Try to get EPG info from Xtream API for live streams
  static Future<void> _parseJsonEpg(dynamic jsonData, XtreamCredentials credentials) async {
    final channels = <EpgChannel>[];
    final programs = <EpgProgram>[];

    if (jsonData is List) {
      for (var item in jsonData) {
        if (item is Map<String, dynamic>) {
          // Parse EPG item
          final channelId = item['stream_id']?.toString() ?? item['channel_id']?.toString() ?? '';
          final title = item['title']?.toString() ?? item['name']?.toString() ?? '';

          if (channelId.isNotEmpty && title.isNotEmpty) {
            // Parse times
            DateTime? startTime;
            DateTime? endTime;

            if (item['start'] != null) {
              startTime = DateTime.tryParse(item['start'].toString()) ??
                         _parseTimestamp(item['start']);
            }
            if (item['end'] != null) {
              endTime = DateTime.tryParse(item['end'].toString()) ??
                       _parseTimestamp(item['end']);
            }

            if (startTime != null && endTime != null) {
              programs.add(EpgProgram.create(
                channelId: channelId,
                title: title,
                description: item['description']?.toString(),
                startTime: startTime,
                endTime: endTime,
                category: item['category']?.toString(),
              ));
            }
          }
        }
      }
    }

    if (programs.isNotEmpty) {
      await _saveEpgData(channels, programs);
    }
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    if (value is String) {
      final intValue = int.tryParse(value);
      if (intValue != null) {
        return DateTime.fromMillisecondsSinceEpoch(intValue * 1000);
      }
    }
    return null;
  }

  static bool _isValidUtf8(String content) {
    try {
      utf8.encode(content);
      return !content.contains('�');
    } catch (e) {
      return false;
    }
  }

  // Parse XMLTV format EPG data
  static Future<void> loadEpgFromUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        String content = response.body;

        // Try to detect encoding
        if (!_isValidUtf8(content)) {
          content = latin1.decode(response.bodyBytes);
        }

        await parseXmltvEpg(content);
      } else {
        throw Exception('Failed to load EPG: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading EPG: $e');
      rethrow;
    }
  }

  // Parse XMLTV format
  static Future<void> parseXmltvEpg(String xmlContent) async {
    final channels = <EpgChannel>[];
    final programs = <EpgProgram>[];

    // Parse channels
    final channelRegex = RegExp(
      r'<channel\s+id="([^"]*)"[^>]*>(.*?)</channel>',
      dotAll: true,
    );

    for (final match in channelRegex.allMatches(xmlContent)) {
      final channelId = match.group(1) ?? '';
      final channelContent = match.group(2) ?? '';

      String? displayName;
      String? icon;

      // Extract display name
      final nameMatch = RegExp(r'<display-name[^>]*>([^<]*)</display-name>')
          .firstMatch(channelContent);
      if (nameMatch != null) {
        displayName = _decodeHtmlEntities(nameMatch.group(1) ?? '');
      }

      // Extract icon
      final iconMatch =
          RegExp(r'<icon\s+src="([^"]*)"').firstMatch(channelContent);
      if (iconMatch != null) {
        icon = iconMatch.group(1);
      }

      channels.add(EpgChannel.create(
        channelId: channelId,
        displayName: displayName,
        icon: icon,
      ));
    }

    // Parse programs - regex más flexible para diferentes ordenes de atributos
    final programRegex = RegExp(
      r'<programme\s+([^>]*)>(.*?)</programme>',
      dotAll: true,
    );

    print('EPG Parser - Buscando programas en ${xmlContent.length} caracteres...');
    int programCount = 0;

    for (final match in programRegex.allMatches(xmlContent)) {
      final attributes = match.group(1) ?? '';
      final programContent = match.group(2) ?? '';

      // Extraer atributos de forma flexible
      final startMatch = RegExp(r'start="([^"]*)"').firstMatch(attributes);
      final stopMatch = RegExp(r'stop="([^"]*)"').firstMatch(attributes);
      final channelMatch = RegExp(r'channel="([^"]*)"').firstMatch(attributes);

      final startStr = startMatch?.group(1) ?? '';
      final stopStr = stopMatch?.group(1) ?? '';
      final channelId = channelMatch?.group(1) ?? '';

      if (startStr.isEmpty || stopStr.isEmpty || channelId.isEmpty) {
        continue;
      }

      final startTime = _parseXmltvDate(startStr);
      final endTime = _parseXmltvDate(stopStr);

      if (startTime == null || endTime == null) {
        continue;
      }

      programCount++;

      String? title;
      String? description;
      String? category;
      String? icon;
      String? rating;
      String? episode;

      // Extract title
      final titleMatch =
          RegExp(r'<title[^>]*>([^<]*)</title>').firstMatch(programContent);
      if (titleMatch != null) {
        title = _decodeHtmlEntities(titleMatch.group(1) ?? '');
      }

      // Extract description
      final descMatch =
          RegExp(r'<desc[^>]*>([^<]*)</desc>').firstMatch(programContent);
      if (descMatch != null) {
        description = _decodeHtmlEntities(descMatch.group(1) ?? '');
      }

      // Extract category
      final catMatch =
          RegExp(r'<category[^>]*>([^<]*)</category>').firstMatch(programContent);
      if (catMatch != null) {
        category = _decodeHtmlEntities(catMatch.group(1) ?? '');
      }

      // Extract icon
      final iconMatch =
          RegExp(r'<icon\s+src="([^"]*)"').firstMatch(programContent);
      if (iconMatch != null) {
        icon = iconMatch.group(1);
      }

      // Extract rating
      final ratingMatch =
          RegExp(r'<rating[^>]*>.*?<value>([^<]*)</value>.*?</rating>', dotAll: true)
              .firstMatch(programContent);
      if (ratingMatch != null) {
        rating = ratingMatch.group(1);
      }

      // Extract episode number
      final episodeMatch = RegExp(
              r'<episode-num\s+system="onscreen"[^>]*>([^<]*)</episode-num>')
          .firstMatch(programContent);
      if (episodeMatch != null) {
        episode = episodeMatch.group(1);
      }

      if (title != null && title.isNotEmpty) {
        programs.add(EpgProgram.create(
          channelId: channelId,
          title: title,
          description: description,
          startTime: startTime,
          endTime: endTime,
          category: category,
          icon: icon,
          rating: rating,
          episode: episode,
        ));
      }
    }

    // Save to database
    await _saveEpgData(channels, programs);
  }

  static DateTime? _parseXmltvDate(String dateStr) {
    // Format: 20231215120000 +0000 or 20231215120000
    try {
      final cleanDate = dateStr.replaceAll(RegExp(r'\s.*'), '');

      if (cleanDate.length >= 14) {
        final year = int.parse(cleanDate.substring(0, 4));
        final month = int.parse(cleanDate.substring(4, 6));
        final day = int.parse(cleanDate.substring(6, 8));
        final hour = int.parse(cleanDate.substring(8, 10));
        final minute = int.parse(cleanDate.substring(10, 12));
        final second = int.parse(cleanDate.substring(12, 14));

        // Handle timezone offset if present
        if (dateStr.contains('+') || dateStr.contains('-')) {
          final tzMatch = RegExp(r'([+-])(\d{2})(\d{2})').firstMatch(dateStr);
          if (tzMatch != null) {
            final sign = tzMatch.group(1) == '+' ? 1 : -1;
            final tzHours = int.parse(tzMatch.group(2) ?? '0');
            final tzMinutes = int.parse(tzMatch.group(3) ?? '0');

            final utcTime = DateTime.utc(year, month, day, hour, minute, second);
            final offset = Duration(hours: tzHours * sign, minutes: tzMinutes * sign);
            return utcTime.subtract(offset).toLocal();
          }
        }

        return DateTime(year, month, day, hour, minute, second);
      }
    } catch (e) {
      print('Error parsing date: $dateStr - $e');
    }
    return null;
  }

  static String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'");
  }

  static Future<void> _saveEpgData(
      List<EpgChannel> channels, List<EpgProgram> programs) async {
    final isar = DatabaseService.isar;

    await isar.writeTxn(() async {
      // Clear old EPG data
      await isar.epgChannels.clear();
      await isar.epgPrograms.clear();

      // Save new data
      if (channels.isNotEmpty) {
        await isar.epgChannels.putAll(channels);
      }
      if (programs.isNotEmpty) {
        await isar.epgPrograms.putAll(programs);
      }
    });

    print('EPG loaded: ${channels.length} channels, ${programs.length} programs');
  }

  // Get all EPG channels
  static Future<List<EpgChannel>> getAllChannels() async {
    return await DatabaseService.isar.epgChannels.where().findAll();
  }

  // Get programs for a specific channel
  static Future<List<EpgProgram>> getProgramsForChannel(String channelId) async {
    return await DatabaseService.isar.epgPrograms
        .filter()
        .channelIdEqualTo(channelId)
        .sortByStartTime()
        .findAll();
  }

  // Get current program for a channel
  static Future<EpgProgram?> getCurrentProgram(String channelId) async {
    final now = DateTime.now();
    return await DatabaseService.isar.epgPrograms
        .filter()
        .channelIdEqualTo(channelId)
        .startTimeLessThan(now)
        .endTimeGreaterThan(now)
        .findFirst();
  }

  // Get next program for a channel
  static Future<EpgProgram?> getNextProgram(String channelId) async {
    final now = DateTime.now();
    return await DatabaseService.isar.epgPrograms
        .filter()
        .channelIdEqualTo(channelId)
        .startTimeGreaterThan(now)
        .sortByStartTime()
        .findFirst();
  }

  // Get programs for a specific time range
  static Future<List<EpgProgram>> getProgramsInTimeRange(
    String channelId,
    DateTime start,
    DateTime end,
  ) async {
    return await DatabaseService.isar.epgPrograms
        .filter()
        .channelIdEqualTo(channelId)
        .startTimeLessThan(end)
        .endTimeGreaterThan(start)
        .sortByStartTime()
        .findAll();
  }

  // Get all programs currently airing
  static Future<List<EpgProgram>> getCurrentlyAiringPrograms() async {
    final now = DateTime.now();
    return await DatabaseService.isar.epgPrograms
        .filter()
        .startTimeLessThan(now)
        .endTimeGreaterThan(now)
        .findAll();
  }

  // Search programs by title
  static Future<List<EpgProgram>> searchPrograms(String query) async {
    return await DatabaseService.isar.epgPrograms
        .filter()
        .titleContains(query, caseSensitive: false)
        .sortByStartTime()
        .findAll();
  }

  // Get programs for today
  static Future<List<EpgProgram>> getTodaysPrograms(String channelId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return await getProgramsInTimeRange(channelId, startOfDay, endOfDay);
  }

  // Clear all EPG data
  static Future<void> clearEpgData() async {
    await DatabaseService.isar.writeTxn(() async {
      await DatabaseService.isar.epgChannels.clear();
      await DatabaseService.isar.epgPrograms.clear();
    });
  }

  // Get EPG info count
  static Future<Map<String, int>> getEpgStats() async {
    final channelCount = await DatabaseService.isar.epgChannels.count();
    final programCount = await DatabaseService.isar.epgPrograms.count();
    return {
      'channels': channelCount,
      'programs': programCount,
    };
  }
}
