import 'package:isar/isar.dart';

part 'channel.g.dart';

enum ContentType {
  live,
  movie,
  series,
}

@collection
class Channel {
  Id id = Isar.autoIncrement;

  late String name;
  late String url;
  String? logo;
  String? group;
  int? tvgId;
  String? tvgName;
  String? tvgLogo;
  String? groupTitle;
  bool isFavorite = false;
  int playCount = 0;
  DateTime? lastPlayed;

  // Content type: 'live', 'movie', 'series'
  @enumerated
  late ContentType contentType;

  Channel();

  // Determine content type from URL or group
  void detectContentType() {
    final lowerUrl = url.toLowerCase();
    final lowerGroup = (group ?? '').toLowerCase();
    final lowerName = name.toLowerCase();

    // Check URL patterns (Xtream Codes API format)
    if (lowerUrl.contains('/movie/') ||
        lowerUrl.contains('&type=movie') ||
        lowerUrl.contains('/vod/') ||
        lowerGroup.contains('vod') ||
        lowerGroup.contains('movie') ||
        lowerGroup.contains('películas') ||
        lowerGroup.contains('peliculas') ||
        lowerGroup.contains('pelicula') ||
        lowerGroup.contains('film') ||
        lowerGroup.contains('cinema')) {
      contentType = ContentType.movie;
    } else if (lowerUrl.contains('/series/') ||
               lowerUrl.contains('&type=series') ||
               lowerGroup.contains('series') ||
               lowerGroup.contains('serie') ||
               lowerGroup.contains('tv shows') ||
               lowerGroup.contains('temporada')) {
      contentType = ContentType.series;
    } else {
      // Everything else is live TV
      contentType = ContentType.live;
    }
  }

  factory Channel.fromM3U(String line, String url) {
    final channel = Channel();
    channel.url = url.trim();

    // Parse EXTINF line
    // Format: #EXTINF:-1 tvg-id="..." tvg-name="..." tvg-logo="..." group-title="...",Channel Name
    final nameMatch = RegExp(r',(.+)$').firstMatch(line);
    channel.name = nameMatch?.group(1)?.trim() ?? 'Unknown Channel';

    // Parse attributes
    final tvgIdMatch = RegExp(r'tvg-id="([^"]*)"').firstMatch(line);
    channel.tvgName = tvgIdMatch?.group(1);

    final tvgNameMatch = RegExp(r'tvg-name="([^"]*)"').firstMatch(line);
    if (tvgNameMatch != null) {
      channel.tvgName = tvgNameMatch.group(1);
    }

    final tvgLogoMatch = RegExp(r'tvg-logo="([^"]*)"').firstMatch(line);
    channel.logo = tvgLogoMatch?.group(1);
    channel.tvgLogo = channel.logo;

    final groupMatch = RegExp(r'group-title="([^"]*)"').firstMatch(line);
    channel.group = groupMatch?.group(1);
    channel.groupTitle = channel.group;

    // Auto-detect content type
    channel.detectContentType();

    return channel;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'logo': logo,
        'group': group,
        'tvgId': tvgId,
        'tvgName': tvgName,
        'tvgLogo': tvgLogo,
        'groupTitle': groupTitle,
        'isFavorite': isFavorite,
        'playCount': playCount,
        'lastPlayed': lastPlayed?.toIso8601String(),
      };
}
