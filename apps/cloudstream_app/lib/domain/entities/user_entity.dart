/// Domain entity — authenticated user session.
class UserEntity {
  final int id;
  final String username;
  final String status;
  final String expiry;
  final bool isTrial;
  final int maxConnections;
  final List<String> allowedOutputFormats;
  final String token;

  const UserEntity({
    required this.id,
    required this.username,
    required this.status,
    required this.expiry,
    required this.isTrial,
    required this.maxConnections,
    required this.allowedOutputFormats,
    required this.token,
  });

  bool get isExpired {
    try {
      final expiryDate = DateTime.parse(expiry);
      return DateTime.now().isAfter(expiryDate);
    } catch (_) {
      return false;
    }
  }
}
