import '../../domain/entities/channel_entity.dart';

/// Maps API JSON → ChannelEntity.
class ChannelModel {
  final int id;
  final String name;
  final String? logo;
  final int categoryId;
  final String categoryName;
  final String streamUrl;
  final bool isRecording;

  const ChannelModel({
    required this.id,
    required this.name,
    this.logo,
    required this.categoryId,
    required this.categoryName,
    required this.streamUrl,
    this.isRecording = false,
  });

  factory ChannelModel.fromJson(Map<String, dynamic> json) {
    return ChannelModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Unknown',
      logo: json['logo'] as String?,
      categoryId: json['category_id'] as int? ?? 0,
      categoryName: json['category_name'] as String? ?? '',
      streamUrl: json['stream_url'] as String,
      isRecording: json['is_recording'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'logo': logo,
    'category_id': categoryId,
    'category_name': categoryName,
    'stream_url': streamUrl,
    'is_recording': isRecording,
  };

  ChannelEntity toEntity() => ChannelEntity(
    id: id,
    name: name,
    logo: logo,
    categoryId: categoryId,
    categoryName: categoryName,
    streamUrl: streamUrl,
    isRecording: isRecording,
  );
}
