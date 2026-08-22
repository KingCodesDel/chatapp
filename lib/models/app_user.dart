class AppUser {
  final String uid;
  final String email;
  final String name;          // full display name, e.g. "Olamide Ashaolu"
  final String username;      // display version, e.g. "JohnDoe"
  final String usernameLower; // lowercase version used for searching/uniqueness
  final String photoUrl;
  final String bio;

  AppUser({
    required this.uid,
    required this.email,
    this.name = '',
    required this.username,
    required this.usernameLower,
    this.photoUrl = '',
    this.bio = '',
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      username: map['username'] ?? '',
      usernameLower: map['username_lower'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      bio: map['bio'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'username': username,
      'username_lower': usernameLower,
      'photoUrl': photoUrl,
      'bio': bio,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
}
