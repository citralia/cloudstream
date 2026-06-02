import '../../domain/entities/vod_entity.dart';

/// Maps API JSON → VodEntity.
class VodModel {
  final int streamId;
  final String name;
  final String? cover;
  final String? plot;
  final String? cast;
  final String? director;
  final String? releaseDate;
  final String? rating;
  final String? duration;
  final int categoryId;
  final String categoryName;

  const VodModel({
    required this.streamId,
    required this.name,
    this.cover,
    this.plot,
    this.cast,
    this.director,
    this.releaseDate,
    this.rating,
    this.duration,
    required this.categoryId,
    required this.categoryName,
  });

  factory VodModel.fromJson(Map<String, dynamic> json) {
    return VodModel(
      streamId: json['stream_id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Unknown',
      cover: json['stream_icon'] as String? ?? json['cover'] as String?,
      plot: null,
      cast: null,
      director: null,
      releaseDate: null,
      rating: json['rating'] as String?,
      duration: json['duration'] as String?,
      categoryId: int.tryParse(json['category_id']?.toString() ?? '') ?? 0,
      categoryName: json['category_name'] as String? ?? '',
    );
  }

  VodEntity toEntity() => VodEntity(
    streamId: streamId,
    name: name,
    cover: cover,
    plot: plot,
    cast: cast,
    director: director,
    releaseDate: releaseDate,
    rating: rating,
    duration: duration,
    categoryId: categoryId,
    categoryName: categoryName,
  );
}
