import 'package:isar/isar.dart';

part 'playlist.g.dart';

@collection
class Playlist {
  Id id = Isar.autoIncrement;

  late String name;
  late String url;
  String? username;
  String? password;
  DateTime? lastUpdated;
  bool isActive = true;
  int channelCount = 0;

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
    if (username != null && password != null) {
      // Handle Xtream Codes API format
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
