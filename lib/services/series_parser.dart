import '../models/channel.dart';
import '../models/series.dart';

class SeriesParser {
  static Map<String, Series> groupIntoSeries(List<Channel> channels) {
    final Map<String, Map<String, List<Channel>>> categorized = {};

    // Group channels by category, then by series name
    for (var channel in channels) {
      final category = channel.group ?? 'Unknown';
      final info = _extractSeriesInfo(channel.name);
      final seriesName = info['seriesName'] ?? channel.name;

      if (!categorized.containsKey(category)) {
        categorized[category] = {};
      }

      if (!categorized[category]!.containsKey(seriesName)) {
        categorized[category]![seriesName] = [];
      }

      categorized[category]![seriesName]!.add(channel);
    }

    // Convert to Series objects with category_seriesName as key
    final Map<String, Series> result = {};
    categorized.forEach((category, seriesMap) {
      seriesMap.forEach((seriesName, episodes) {
        if (episodes.isNotEmpty) {
          final key = '${category}_$seriesName';
          result[key] = _createSeries(seriesName, episodes, category);
        }
      });
    });

    return result;
  }

  static Map<String, String?> _extractSeriesInfo(String channelName) {
    // Patterns to detect series/season/episode
    // Examples:
    // "Tulsa King - S01E01 - Episode Name"
    // "Breaking Bad S05E16"
    // "Game of Thrones 1x01"

    final patterns = [
      RegExp(r'^(.+?)\s*-\s*S(\d+)E(\d+)', caseSensitive: false),
      RegExp(r'^(.+?)\s+S(\d+)E(\d+)', caseSensitive: false),
      RegExp(r'^(.+?)\s+(\d+)x(\d+)', caseSensitive: false),
      RegExp(r'^(.+?)\s+Temporada\s*(\d+)\s+Cap[íi]tulo\s*(\d+)', caseSensitive: false),
    ];

    for (var pattern in patterns) {
      final match = pattern.firstMatch(channelName);
      if (match != null) {
        return {
          'seriesName': match.group(1)?.trim(),
          'season': match.group(2),
          'episode': match.group(3),
        };
      }
    }

    // If no pattern matches, try to detect by " - " separator
    if (channelName.contains(' - ')) {
      final parts = channelName.split(' - ');
      if (parts.length >= 2) {
        return {
          'seriesName': parts[0].trim(),
          'season': null,
          'episode': null,
        };
      }
    }

    return {'seriesName': channelName, 'season': null, 'episode': null};
  }

  static Series _createSeries(String seriesName, List<Channel> episodes, String category) {
    // Group episodes by season
    final Map<int, List<Episode>> seasonMap = {};

    for (var channel in episodes) {
      final info = _extractSeriesInfo(channel.name);
      final seasonNum = int.tryParse(info['season'] ?? '1') ?? 1;
      final episodeNum = int.tryParse(info['episode'] ?? '1') ?? 1;

      if (!seasonMap.containsKey(seasonNum)) {
        seasonMap[seasonNum] = [];
      }

      seasonMap[seasonNum]!.add(Episode(
        name: channel.name,
        url: channel.url,
        thumbnail: channel.logo,
        episodeNumber: episodeNum,
        seasonNumber: seasonNum,
        plot: null,
        duration: null,
      ));
    }

    // Sort episodes within each season
    seasonMap.forEach((season, eps) {
      eps.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
    });

    // Create Season objects
    final seasons = seasonMap.entries.map((entry) {
      return Season(
        seasonNumber: entry.key,
        episodes: entry.value,
      );
    }).toList();

    seasons.sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));

    // Get poster from first episode
    final firstEpisode = episodes.isNotEmpty ? episodes.first : null;

    return Series(
      name: seriesName,
      poster: firstEpisode?.logo,
      backdrop: firstEpisode?.logo,
      seasons: seasons,
      rating: 4.0, // Default rating
    );
  }
}
