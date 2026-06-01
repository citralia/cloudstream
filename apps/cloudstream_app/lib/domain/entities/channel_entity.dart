/// Domain entity — a live TV channel.
class ChannelEntity {
  final int id;
  final String name;
  final String? logo;
  final int categoryId;
  final String categoryName;
  final String streamUrl;  // relative URL, e.g. "/api/stream/123"
  final bool isRecording;

  const ChannelEntity({
    required this.id,
    required this.name,
    this.logo,
    required this.categoryId,
    required this.categoryName,
    required this.streamUrl,
    this.isRecording = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelEntity && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
