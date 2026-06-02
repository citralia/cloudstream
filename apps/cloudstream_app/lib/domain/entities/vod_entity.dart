/// Domain entity for a VOD (movie) item.
class VodEntity {
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

  const VodEntity({
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
}
