import 'package:isar/isar.dart';

part 'playlist.g.dart';

enum PlaylistSourceType {
  m3u,
  xtreamCodes,
}

@collection
class Playlist {
  Id id = Isar.autoIncrement;

  late String name;
  late String url; // M3U URL or Xtream baseUrl
  String? username;
  String? password;
  DateTime? lastUpdated;
  bool isActive = true;
  int channelCount = 0;

  // Xtream Codes specific
  @enumerated
  PlaylistSourceType sourceType = PlaylistSourceType.m3u;

  Playlist();

  factory Playlist.create({
    required String name,
    required String url,
    String? username,
    String? password,
  }) {
    final playlist = Playlist();
    playlist.name = name;
    playlist.url = url;
    playlist.username = username;
    playlist.password = password;
    playlist.lastUpdated = DateTime.now();
    return playlist;
  }

  String getFullUrl() {
    // For Xtream Codes, return the base URL (credentials handled separately)
    if (sourceType == PlaylistSourceType.xtreamCodes) {
      return url;
    }

    // For M3U format
    if (username != null && password != null) {
      // Handle Xtream Codes API format in M3U
      if (url.contains('get.php')) {
        return '$url?username=$username&password=$password&type=m3u_plus';
      }
      // Handle basic auth
      final uri = Uri.parse(url);
      return uri.replace(
        userInfo: '$username:$password',
      ).toString();
    }
    return url;
  }

  bool get isXtreamCodes => sourceType == PlaylistSourceType.xtreamCodes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'username': username,
        'password': password,
        'lastUpdated': lastUpdated?.toIso8601String(),
        'isActive': isActive,
        'channelCount': channelCount,
      };
}
