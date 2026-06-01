import '../../domain/entities/category_entity.dart';

class CategoryModel {
  final int id;
  final String name;
  final String type;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.type,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      type: json['type'] as String,
    );
  }

  CategoryEntity toEntity() => CategoryEntity(
    id: id,
    name: name,
    type: type,
  );
}
