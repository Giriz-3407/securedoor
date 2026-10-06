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
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String? ?? 'Authorized Operator',
      role: json['role'] as String? ?? 'operator',
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
