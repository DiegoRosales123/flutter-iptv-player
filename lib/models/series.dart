class Series {
  final String name;
  final String? poster;
  final String? backdrop;
  final String? director;
  final String? genre;
  final String? releaseDate;
  double? rating;
  final String? plot;
  final List<Season> seasons;

  Series({
    required this.name,
    this.poster,
    this.backdrop,
    this.director,
    this.genre,
    this.releaseDate,
    this.rating,
    this.plot,
    this.seasons = const [],
  });
}

class Season {
  final int seasonNumber;
  final List<Episode> episodes;

  Season({
    required this.seasonNumber,
    required this.episodes,
  });
}

class Episode {
  final String name;
  final String url;
  final String? thumbnail;
  final int episodeNumber;
  final int seasonNumber;
  final String? duration;
  final String? plot;
  int watchedMilliseconds = 0; // Progress in milliseconds
  int totalMilliseconds = 0; // Total duration in milliseconds

  Episode({
    required this.name,
    required this.url,
    this.thumbnail,
    required this.episodeNumber,
    required this.seasonNumber,
    this.duration,
    this.plot,
  });
}
