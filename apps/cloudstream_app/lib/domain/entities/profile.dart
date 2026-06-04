

/// A local user profile — groups favourites, watch-progress, and recent channels
/// under a single named identity.
class Profile {
  final String id;
  final String name;
  final int colorIndex;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.createdAt,
  });

  Profile copyWith({String? name, int? colorIndex}) {
    return Profile(
      id: id,
      name: name ?? this.name,
      colorIndex: colorIndex ?? this.colorIndex,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorIndex': colorIndex,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      name: json['name'] as String,
      colorIndex: json['colorIndex'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static String generateId() => DateTime.now().millisecondsSinceEpoch.toString();
}

/// Colours available for profile avatar backgrounds.
const kProfileColors = [
  0xFF6366F1, // Indigo
  0xFF8B5CF6, // Violet
  0xFFEC4899, // Pink
  0xFFEF4444, // Red
  0xFFF97316, // Orange
  0xFF14B8A6, // Teal
  0xFF22C55E, // Green
  0xFF3B82F6, // Blue
];
