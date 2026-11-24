enum UserRole {
  manager,
  akuntan,
  karyawan,
}

class AppUser {
  final String id;
  final String username;
  final String fullName;
  final UserRole role;
  final bool isActive;
  final String token;

  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.token,
    this.isActive = true,
  });

  String get roleName {
    switch (role) {
      case UserRole.manager:
        return 'Manager';

      case UserRole.akuntan:
        return 'Akuntan';

      case UserRole.karyawan:
        return 'Karyawan';
    }
  }

  bool get isManager => role == UserRole.manager;

  bool get isAkuntan => role == UserRole.akuntan;

  bool get isKaryawan => role == UserRole.karyawan;

  int? get userId => int.tryParse(id);

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final rawToken = json['token'] ?? json['access_token'];

    final rawRole = json['role']?.toString().toLowerCase();

    return AppUser(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      role: UserRole.values.firstWhere(
        (item) => item.name == rawRole,
        orElse: () => UserRole.karyawan,
      ),
      isActive:
          json['is_active'] == true ||
          json['is_active'] == 1 ||
          json['is_active'] == '1',
      token: rawToken?.toString().trim() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'role': role.name,
      'is_active': isActive,
      'token': token,
    };
  }

  Map<String, dynamic> toJson() => toMap();
}