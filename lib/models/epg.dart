import 'package:isar/isar.dart';

part 'epg.g.dart';

@collection
class EpgChannel {
  Id id = Isar.autoIncrement;

  late String channelId; // tvg-id from M3U
  String? displayName;
  String? icon;

  EpgChannel();

  factory EpgChannel.create({
    required String channelId,
    String? displayName,
    String? icon,
  }) {
    final channel = EpgChannel();
    channel.channelId = channelId;
    channel.displayName = displayName;
    channel.icon = icon;
    return channel;
  }
}

@collection
class EpgProgram {
  Id id = Isar.autoIncrement;

  late String channelId; // Reference to EpgChannel.channelId
  late String title;
  String? description;
  late DateTime startTime;
  late DateTime endTime;
  String? category;
  String? icon;
  String? rating;
  String? episode; // e.g., "S01E05"

  EpgProgram();

  factory EpgProgram.create({
    required String channelId,
    required String title,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
    String? category,
    String? icon,
    String? rating,
    String? episode,
  }) {
    final program = EpgProgram();
    program.channelId = channelId;
    program.title = title;
    program.description = description;
    program.startTime = startTime;
    program.endTime = endTime;
    program.category = category;
    program.icon = icon;
    program.rating = rating;
    program.episode = episode;
    return program;
  }

  // Calculate duration in minutes
  int get durationMinutes {
    return endTime.difference(startTime).inMinutes;
  }

  // Check if program is currently airing
  bool get isNowPlaying {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  // Check if program has already ended
  bool get hasEnded {
    return DateTime.now().isAfter(endTime);
  }

  // Calculate progress percentage (0.0 to 1.0)
  double get progress {
    if (hasEnded) return 1.0;
    if (!isNowPlaying) return 0.0;

    final now = DateTime.now();
    final totalDuration = endTime.difference(startTime).inSeconds;
    final elapsed = now.difference(startTime).inSeconds;

    return (elapsed / totalDuration).clamp(0.0, 1.0);
  }

  // Format time as HH:MM
  String get formattedStartTime {
    return '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
  }

  String get formattedEndTime {
    return '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
  }

  String get formattedTimeRange {
    return '$formattedStartTime - $formattedEndTime';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'channelId': channelId,
        'title': title,
        'description': description,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'category': category,
        'icon': icon,
        'rating': rating,
        'episode': episode,
      };
}
