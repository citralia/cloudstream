/// Domain entity — a category of content.
class CategoryEntity {
  final int id;
  final String name;
  final String type;  // "live" | "vod" | "series"

  const CategoryEntity({
    required this.id,
    required this.name,
    required this.type,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryEntity && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
