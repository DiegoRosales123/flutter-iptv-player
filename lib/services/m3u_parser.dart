import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel.dart';

class M3UParser {
  static Future<List<Channel>> parseFromUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        // The server is sending Latin1/ISO-8859-1 encoded data
        // but we need to decode it as UTF-8 bytes that were incorrectly encoded as Latin1
        String content;

        try {
          // Try direct body first (uses response's declared encoding)
          content = response.body;

          // Check if it has mojibake (double-encoding issue)
          if (content.contains('Ã') || content.contains('â€') || content.contains('Ã±')) {
            // Data was UTF-8 encoded then sent as Latin1
            // We need to reverse: treat as Latin1 bytes, then decode as UTF-8
            final latin1Bytes = latin1.encode(content);
            content = utf8.decode(latin1Bytes, allowMalformed: true);
          }
        } catch (e) {
          // Fallback to simple Latin1 decode
          content = latin1.decode(response.bodyBytes);
        }

        return parseM3U(content);
      } else {
        throw Exception('Failed to load playlist: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching playlist: $e');
    }
  }

  static List<Channel> parseM3U(String content) {
    final channels = <Channel>[];
    final lines = content.split('\n');

    String? currentExtinf;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.startsWith('#EXTINF:')) {
        currentExtinf = line;
      } else if (line.isNotEmpty &&
          !line.startsWith('#') &&
          currentExtinf != null) {
        // This is a URL line following an EXTINF
        try {
          final channel = Channel.fromM3U(currentExtinf, line);
          channels.add(channel);
        } catch (e) {
          print('Error parsing channel: $e');
        }
        currentExtinf = null;
      }
    }

    return channels;
  }

  static Future<List<Channel>> parseFromFile(String filePath) async {
    try {
      // For file parsing, you would use dart:io File
      // But since we're focusing on network playlists, this is a placeholder
      throw UnimplementedError('File parsing not yet implemented');
    } catch (e) {
      throw Exception('Error reading file: $e');
    }
  }

  static List<String> extractGroups(List<Channel> channels) {
    final groups = <String>{};
    for (var channel in channels) {
      if (channel.group != null && channel.group!.isNotEmpty) {
        groups.add(channel.group!);
      }
    }
    return groups.toList()..sort();
  }

  static Map<String, List<Channel>> groupChannels(List<Channel> channels) {
    final grouped = <String, List<Channel>>{};

    for (var channel in channels) {
      final group = channel.group ?? 'Uncategorized';
      if (!grouped.containsKey(group)) {
        grouped[group] = [];
      }
      grouped[group]!.add(channel);
    }

    return grouped;
  }
}
