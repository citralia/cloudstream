import '../../domain/entities/programme_entity.dart';

class ProgrammeModel {
  final String id;
  final int channelId;
  final String title;
  final String? description;
  final DateTime start;
  final DateTime end;
  final String? category;
  final bool isCatchup;

  const ProgrammeModel({
    required this.id,
    required this.channelId,
    required this.title,
    this.description,
    required this.start,
    required this.end,
    this.category,
    this.isCatchup = false,
  });

  factory ProgrammeModel.fromJson(Map<String, dynamic> json) {
    return ProgrammeModel(
      id: json['id'] as String,
      channelId: json['channel_id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      category: json['category'] as String?,
      isCatchup: json['is_catchup'] as bool? ?? false,
    );
  }

  ProgrammeEntity toEntity() => ProgrammeEntity(
    id: id,
    channelId: channelId,
    title: title,
    description: description,
    start: start,
    end: end,
    category: category,
    isCatchup: isCatchup,
  );
}


class EpgChannelModel {
  final int id;
  final String name;
  final String? logo;
  final List<ProgrammeModel> programmes;

  const EpgChannelModel({
    required this.id,
    required this.name,
    this.logo,
    required this.programmes,
  });

  factory EpgChannelModel.fromJson(Map<String, dynamic> json) {
    return EpgChannelModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      logo: json['logo'] as String?,
      programmes: (json['programmes'] as List<dynamic>?)
          ?.map((p) => ProgrammeModel.fromJson(p as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}
