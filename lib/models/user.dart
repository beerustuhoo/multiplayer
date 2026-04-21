class UserModel {
  final String id;
  final String username;
  final String email;
  final bool emailVerified;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.emailVerified,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      emailVerified: json['emailVerified'] as bool? ?? false,
    );
  }

  UserModel copyWith({bool? emailVerified}) {
    return UserModel(
      id: id,
      username: username,
      email: email,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }
}
