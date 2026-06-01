/// Domain entity — an EPG programme.
class ProgrammeEntity {
  final String id;
  final int channelId;
  final String title;
  final String? description;
  final DateTime start;
  final DateTime end;
  final String? category;
  final bool isCatchup;

  const ProgrammeEntity({
    required this.id,
    required this.channelId,
    required this.title,
    this.description,
    required this.start,
    required this.end,
    this.category,
    this.isCatchup = false,
  });

  bool get isOnNow {
    final now = DateTime.now().toUtc();
    return now.isAfter(start) && now.isBefore(end);
  }

  bool get isNext {
    final now = DateTime.now().toUtc();
    return now.isBefore(start);
  }

  Duration get duration => end.difference(start);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgrammeEntity && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
