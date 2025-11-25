/// Model for Video-on-Demand (Movies)
class VodItem {
  final String id;
  final String name;
  final String streamUrl;
  final String? posterUrl;
  final String? backdropUrl;
  final String? plot;
  final String? cast;
  final String? director;
  final String? genre;
  final String? releaseDate;
  final String? rating;
  final String? duration;
  final String categoryId;
  final String categoryName;
  final String containerExtension;
  bool isFavorite;

  VodItem({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.posterUrl,
    this.backdropUrl,
    this.plot,
    this.cast,
    this.director,
    this.genre,
    this.releaseDate,
    this.rating,
    this.duration,
    required this.categoryId,
    required this.categoryName,
    this.containerExtension = 'mp4',
    this.isFavorite = false,
  });

  factory VodItem.fromJson(Map<String, dynamic> json, String baseUrl, String username, String password, {Map<String, String>? categoryMap}) {
    final streamId = json['stream_id']?.toString() ?? json['id']?.toString() ?? '';
    final containerExt = json['container_extension']?.toString() ?? 'mp4';

    // Build stream URL: http://server/movie/username/password/streamId.ext
    final streamUrl = '$baseUrl/movie/$username/$password/$streamId.$containerExt';

    final info = json['info'] as Map<String, dynamic>?;

    // Get category name from map or fallback to json
    final categoryId = json['category_id']?.toString() ?? '';
    final categoryName = categoryMap?[categoryId] ?? json['category_name']?.toString() ?? 'Movies';

    return VodItem(
      id: streamId,
      name: json['name']?.toString() ?? 'Unknown',
      streamUrl: streamUrl,
      posterUrl: json['stream_icon']?.toString() ?? info?['movie_image']?.toString(),
      backdropUrl: info?['backdrop_path']?.toString().isNotEmpty == true
          ? info!['backdrop_path'].toString()
          : null,
      plot: info?['plot']?.toString() ?? info?['description']?.toString(),
      cast: info?['cast']?.toString(),
      director: info?['director']?.toString(),
      genre: info?['genre']?.toString(),
      releaseDate: info?['releasedate']?.toString() ?? info?['release_date']?.toString(),
      rating: info?['rating']?.toString() ?? info?['rating_5based']?.toString(),
      duration: info?['duration']?.toString(),
      categoryId: categoryId,
      categoryName: categoryName,
      containerExtension: containerExt,
      isFavorite: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'streamUrl': streamUrl,
      'posterUrl': posterUrl,
      'backdropUrl': backdropUrl,
      'plot': plot,
      'cast': cast,
      'director': director,
      'genre': genre,
      'releaseDate': releaseDate,
      'rating': rating,
      'duration': duration,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'containerExtension': containerExtension,
      'isFavorite': isFavorite,
    };
  }

  VodItem copyWith({
    String? id,
    String? name,
    String? streamUrl,
    String? posterUrl,
    String? backdropUrl,
    String? plot,
    String? cast,
    String? director,
    String? genre,
    String? releaseDate,
    String? rating,
    String? duration,
    String? categoryId,
    String? categoryName,
    String? containerExtension,
    bool? isFavorite,
  }) {
    return VodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      streamUrl: streamUrl ?? this.streamUrl,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      plot: plot ?? this.plot,
      cast: cast ?? this.cast,
      director: director ?? this.director,
      genre: genre ?? this.genre,
      releaseDate: releaseDate ?? this.releaseDate,
      rating: rating ?? this.rating,
      duration: duration ?? this.duration,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      containerExtension: containerExtension ?? this.containerExtension,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
