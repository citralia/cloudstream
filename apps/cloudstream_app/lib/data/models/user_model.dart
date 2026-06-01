import '../../domain/entities/user_entity.dart';

class UserModel {
  final int id;
  final String username;
  final String status;
  final String expiry;
  final bool isTrial;
  final int maxConnections;
  final List<String> allowedOutputFormats;
  final String token;

  const UserModel({
    required this.id,
    required this.username,
    required this.status,
    required this.expiry,
    required this.isTrial,
    required this.maxConnections,
    required this.allowedOutputFormats,
    required this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      status: json['status'] as String? ?? 'Active',
      expiry: json['expiry'] as String? ?? '',
      isTrial: json['is_trial'] as bool? ?? false,
      maxConnections: json['max_connections'] as int? ?? 1,
      allowedOutputFormats: (json['allowed_output_formats'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? ['m3u8'],
      token: json['token'] as String,
    );
  }

  UserEntity toEntity() => UserEntity(
    id: id,
    username: username,
    status: status,
    expiry: expiry,
    isTrial: isTrial,
    maxConnections: maxConnections,
    allowedOutputFormats: allowedOutputFormats,
    token: token,
  );
}
