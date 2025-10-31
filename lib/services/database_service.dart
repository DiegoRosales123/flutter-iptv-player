import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/channel.dart';
import '../models/playlist.dart';
import '../models/profile.dart';

class DatabaseService {
  static late Isar isar;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    final dir = await getApplicationDocumentsDirectory();

    isar = await Isar.open(
      [ChannelSchema, PlaylistSchema, ProfileSchema],
      directory: dir.path,
    );

    _initialized = true;

    // Create default profile if none exists
    final profileCount = await isar.profiles.count();
    if (profileCount == 0) {
      await isar.writeTxn(() async {
        final defaultProfile = Profile.create(name: 'Default');
        defaultProfile.isActive = true;
        await isar.profiles.put(defaultProfile);
      });
    }
  }

  // Playlist operations
  static Future<void> addPlaylist(Playlist playlist) async {
    await isar.writeTxn(() async {
      await isar.playlists.put(playlist);
    });
  }

  static Future<List<Playlist>> getAllPlaylists() async {
    return await isar.playlists.where().findAll();
  }

  static Future<void> deletePlaylist(int id) async {
    await isar.writeTxn(() async {
      await isar.playlists.delete(id);
      // Also delete associated channels
      await isar.channels.filter().idEqualTo(id).deleteAll();
    });
  }

  // Channel operations
  static Future<void> addChannels(List<Channel> channels) async {
    await isar.writeTxn(() async {
      await isar.channels.putAll(channels);
    });
  }

  static Future<List<Channel>> getAllChannels() async {
    return await isar.channels.where().findAll();
  }

  static Future<List<Channel>> getFavoriteChannels() async {
    return await isar.channels.filter().isFavoriteEqualTo(true).findAll();
  }

  static Future<List<Channel>> getChannelsByGroup(String group) async {
    return await isar.channels.filter().groupEqualTo(group).findAll();
  }

  static Future<void> toggleFavorite(Channel channel) async {
    await isar.writeTxn(() async {
      channel.isFavorite = !channel.isFavorite;
      await isar.channels.put(channel);
    });
  }

  static Future<void> updateChannelPlayCount(Channel channel) async {
    await isar.writeTxn(() async {
      channel.playCount++;
      channel.lastPlayed = DateTime.now();
      await isar.channels.put(channel);
    });
  }

  static Future<List<Channel>> searchChannels(String query) async {
    return await isar.channels
        .filter()
        .nameContains(query, caseSensitive: false)
        .findAll();
  }

  // Profile operations
  static Future<void> addProfile(Profile profile) async {
    await isar.writeTxn(() async {
      await isar.profiles.put(profile);
    });
  }

  static Future<List<Profile>> getAllProfiles() async {
    return await isar.profiles.where().findAll();
  }

  static Future<Profile?> getActiveProfile() async {
    return await isar.profiles.filter().isActiveEqualTo(true).findFirst();
  }

  static Future<void> setActiveProfile(Profile profile) async {
    await isar.writeTxn(() async {
      // Deactivate all profiles
      final allProfiles = await isar.profiles.where().findAll();
      for (var p in allProfiles) {
        p.isActive = false;
        await isar.profiles.put(p);
      }
      // Activate selected profile
      profile.isActive = true;
      await isar.profiles.put(profile);
    });
  }

  static Future<void> deleteProfile(int id) async {
    await isar.writeTxn(() async {
      await isar.profiles.delete(id);
    });
  }

  static Future<void> clearAllData() async {
    await isar.writeTxn(() async {
      await isar.clear();
    });
  }
}
