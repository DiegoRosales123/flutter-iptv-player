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
  double rating = 0.0; // TMDB rating (0-10), 0 means not set
  String? description; // Movie/Series description or plot
  int watchedMilliseconds = 0; // Progress in milliseconds
  int totalMilliseconds = 0; // Total duration in milliseconds

  // Playlist association
  int? playlistId; // ID of the playlist this channel belongs to

  // Content type: 'live', 'movie', 'series'
  @enumerated
  late ContentType contentType;

  Channel();

  // Professional content type detection based on URL pattern priority
  // Strategy: URL API patterns > name patterns > group (group is unreliable in M3U)
  // Default to LIVE since most M3U content is broadcast television
  void detectContentType() {
    final lowerUrl = url.toLowerCase();
    final lowerName = name.toLowerCase();
    final lowerGroup = (group ?? '').toLowerCase();

    // STAGE 1: Definitive URL patterns (highest confidence)
    // Xtream Codes API endpoints are very reliable
    if (lowerUrl.contains('/movie/') || lowerUrl.contains('&type=movie')) {
      contentType = ContentType.movie;
      return;
    }
    if (lowerUrl.contains('/series/') || lowerUrl.contains('&type=series')) {
      contentType = ContentType.series;
      return;
    }
    if (lowerUrl.contains('/vod/')) {
      contentType = ContentType.movie; // VOD is primarily movies
      return;
    }

    // STAGE 2: Definitive LIVE TV name patterns
    // These patterns are almost 100% reliable for identifying live channels
    // "LAT |", "HBO -", "1 |", "101.", etc. are channel naming conventions
    if (RegExp(r'^[a-z]{1,3}\s*[\|\-]', caseSensitive: false).hasMatch(lowerName)) {
      contentType = ContentType.live;
      return;
    }

    // Numbered channels (1, 101, 1.1, etc.) followed by separator
    if (RegExp(r'^\d+(\.\d+)?\s*[\|\-\.]', caseSensitive: false).hasMatch(lowerName)) {
      contentType = ContentType.live;
      return;
    }

    // MPEG-TS format is used for live TV streaming
    if (lowerUrl.endsWith('.ts') || lowerUrl.contains('.ts?') || lowerUrl.contains('.ts/')) {
      contentType = ContentType.live;
      return;
    }

    // Explicit live path
    if (lowerUrl.contains('/live/')) {
      contentType = ContentType.live;
      return;
    }

    // STAGE 3: Name patterns for series (season/episode notation)
    if (RegExp(r's\d{1,2}e\d{1,2}|temporada\s*\d+|season\s*\d+', caseSensitive: false).hasMatch(lowerName)) {
      contentType = ContentType.series;
      return;
    }

    // STAGE 4: Check if name indicates live TV before trusting group
    final liveNamePatterns = [
      'live', 'en vivo', 'tvonline', 'tv online',
      'canal', 'sport', 'sports', 'news', 'documentales',
      'hbo', 'espn', 'discovery', 'nat geo', 'animal planet',
      'history', 'syfy', 'cinemax', 'mtv', 'vevo'
    ];

    bool nameLooksLive = liveNamePatterns.any((p) => lowerName.contains(p));

    if (nameLooksLive) {
      contentType = ContentType.live;
      return;
    }

    // STAGE 5: Use group only if name doesn't contradict
    // (at this point we know the name doesn't look like a live channel)
    if (lowerGroup.contains('movie') || lowerGroup.contains('película') ||
        lowerGroup.contains('peliculas') || lowerGroup.contains('pelicula') ||
        lowerGroup.contains('film') || lowerGroup.contains('cine') ||
        lowerGroup.contains('cinema')) {
      contentType = ContentType.movie;
      return;
    }

    if (lowerGroup.contains('series') || lowerGroup.contains('serie') ||
        lowerGroup.contains('tv show') || lowerGroup.contains('temporada')) {
      contentType = ContentType.series;
      return;
    }

    // STAGE 6: Default to LIVE TV
    // This is the safest default since most M3U content is broadcast television
    contentType = ContentType.live;
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
        'rating': rating,
        'description': description,
        'watchedMilliseconds': watchedMilliseconds,
        'totalMilliseconds': totalMilliseconds,
      };
}
