class User {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final name = json['fullName'] as String? ?? json['name'] as String? ?? 'Authorized Operator';
    return User(
      id: (json['id'] ?? json['_id'] ?? 'usr_unknown').toString(),
      email: (json['email'] ?? '').toString(),
      fullName: name,
      role: (json['role'] ?? 'user').toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'fullName': fullName,
    'role': role,
    'createdAt': createdAt.toIso8601String(),
  };
}

class LoginCredentials {
  final String email;
  final String password;

  const LoginCredentials({required this.email, required this.password});
}
