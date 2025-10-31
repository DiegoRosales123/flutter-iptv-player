import 'package:isar/isar.dart';

part 'profile.g.dart';

@collection
class Profile {
  Id id = Isar.autoIncrement;

  late String name;
  String? avatarUrl;
  bool isActive = false;
  DateTime? createdAt;

  // Settings
  bool showAdultContent = false;
  String videoQuality = 'auto';
  bool autoPlay = true;
  double volume = 1.0;

  Profile();

  factory Profile.create({
    required String name,
    String? avatarUrl,
  }) {
    final profile = Profile();
    profile.name = name;
    profile.avatarUrl = avatarUrl;
    profile.createdAt = DateTime.now();
    return profile;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatarUrl': avatarUrl,
        'isActive': isActive,
        'createdAt': createdAt?.toIso8601String(),
        'showAdultContent': showAdultContent,
        'videoQuality': videoQuality,
        'autoPlay': autoPlay,
        'volume': volume,
      };
}
