class AppUser {
  final String uid;
  final String email;
  final String username;      // display version, e.g. "JohnDoe"
  final String usernameLower; // lowercase version used for searching/uniqueness
  final String photoUrl;
  final String bio;

  AppUser({
    required this.uid,
    required this.email,
    required this.username,
    required this.usernameLower,
    this.photoUrl = '',
    this.bio = '',
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
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
      'username': username,
      'username_lower': usernameLower,
      'photoUrl': photoUrl,
      'bio': bio,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
}
