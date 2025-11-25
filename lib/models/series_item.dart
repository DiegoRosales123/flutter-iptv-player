/// Model for TV Series
class SeriesItem {
  final String id;
  final String name;
  final String? posterUrl;
  final String? backdropUrl;
  final String? plot;
  final String? cast;
  final String? director;
  final String? genre;
  final String? releaseDate;
  final String? rating;
  final String categoryId;
  final String categoryName;
  final int? episodeRunTime;
  final String? youtubeTrailer;
  bool isFavorite;

  SeriesItem({
    required this.id,
    required this.name,
    this.posterUrl,
    this.backdropUrl,
    this.plot,
    this.cast,
    this.director,
    this.genre,
    this.releaseDate,
    this.rating,
    required this.categoryId,
    required this.categoryName,
    this.episodeRunTime,
    this.youtubeTrailer,
    this.isFavorite = false,
  });

  factory SeriesItem.fromJson(Map<String, dynamic> json, {Map<String, String>? categoryMap}) {
    final info = json['info'] as Map<String, dynamic>?;

    // Get category name from map or fallback to json
    final categoryId = json['category_id']?.toString() ?? '';
    final categoryName = categoryMap?[categoryId] ?? json['category_name']?.toString() ?? 'Series';

    return SeriesItem(
      id: json['series_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Series',
      posterUrl: json['cover']?.toString() ?? info?['cover']?.toString(),
      backdropUrl: info?['backdrop_path']?.toString().isNotEmpty == true
          ? info!['backdrop_path'].toString()
          : null,
      plot: info?['plot']?.toString() ?? info?['description']?.toString(),
      cast: info?['cast']?.toString(),
      director: info?['director']?.toString(),
      genre: info?['genre']?.toString(),
      releaseDate: info?['releasedate']?.toString() ?? info?['release_date']?.toString(),
      rating: info?['rating']?.toString() ?? info?['rating_5based']?.toString(),
      categoryId: categoryId,
      categoryName: categoryName,
      episodeRunTime: info?['episode_run_time'] != null
          ? int.tryParse(info!['episode_run_time'].toString())
          : null,
      youtubeTrailer: info?['youtube_trailer']?.toString(),
      isFavorite: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'posterUrl': posterUrl,
      'backdropUrl': backdropUrl,
      'plot': plot,
      'cast': cast,
      'director': director,
      'genre': genre,
      'releaseDate': releaseDate,
      'rating': rating,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'episodeRunTime': episodeRunTime,
      'youtubeTrailer': youtubeTrailer,
      'isFavorite': isFavorite,
    };
  }

  SeriesItem copyWith({
    String? id,
    String? name,
    String? posterUrl,
    String? backdropUrl,
    String? plot,
    String? cast,
    String? director,
    String? genre,
    String? releaseDate,
    String? rating,
    String? categoryId,
    String? categoryName,
    int? episodeRunTime,
    String? youtubeTrailer,
    bool? isFavorite,
  }) {
    return SeriesItem(
      id: id ?? this.id,
      name: name ?? this.name,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      plot: plot ?? this.plot,
      cast: cast ?? this.cast,
      director: director ?? this.director,
      genre: genre ?? this.genre,
      releaseDate: releaseDate ?? this.releaseDate,
      rating: rating ?? this.rating,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      episodeRunTime: episodeRunTime ?? this.episodeRunTime,
      youtubeTrailer: youtubeTrailer ?? this.youtubeTrailer,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
