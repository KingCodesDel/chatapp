import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Registers a new user with email + password and a unique username.
  /// Throws an Exception with a readable message on failure.
  Future<void> registerUser({
    required String email,
    required String password,
    required String username,
  }) async {
    final usernameLower = username.trim().toLowerCase();

    if (usernameLower.isEmpty) {
      throw Exception('Username cannot be empty');
    }

    // 1. Check username availability BEFORE creating the auth account
    final usernameDoc =
        await _db.collection('usernames').doc(usernameLower).get();
    if (usernameDoc.exists) {
      throw Exception('That username is already taken');
    }

    // 2. Create the auth account
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = credential.user!.uid;

    // 3. Reserve the username + create the user profile document
    //    (done together so they can't go out of sync)
    final batch = _db.batch();
    batch.set(_db.collection('usernames').doc(usernameLower), {'uid': uid});
    batch.set(_db.collection('users').doc(uid), {
      'uid': uid,
      'email': email.trim(),
      'username': username.trim(),
      'username_lower': usernameLower,
      'photoUrl': '',
      'bio': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    // 4. Send email verification
    await credential.user!.sendEmailVerification();
  }

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
