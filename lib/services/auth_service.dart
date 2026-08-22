import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // From Google Cloud Console → APIs & Services → Credentials →
  // "Web client (auto created by Google Service)". Firebase creates this
  // automatically once you enable the Google sign-in provider.
  static const String _googleServerClientId =
      '964054090271-vh3ot3db28ob3mhhui3o0g2imr0gb64b.apps.googleusercontent.com';

  bool _googleSignInReady = false;

  Future<void> _ensureGoogleSignInReady() async {
    if (_googleSignInReady) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: _googleServerClientId,
    );
    _googleSignInReady = true;
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Registers a new user with email + password and a unique username.
  /// Throws an Exception with a readable message on failure.
  Future<void> registerUser({
    required String email,
    required String password,
    required String username,
    String name = '',
  }) async {
    final usernameLower = username.trim().toLowerCase();

    if (usernameLower.isEmpty) {
      throw Exception('Username cannot be empty');
    }

    // 1. Check username availability BEFORE creating the auth account
    final usernameDoc = await _db
        .collection('usernames')
        .doc(usernameLower)
        .get();
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
      'name': name.trim(),
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

  /// Signs in with Google. If this is the person's first time (no user
  /// document yet), auto-generates a unique username from their email and
  /// creates their profile — same pattern as [registerUser].
  Future<void> signInWithGoogle() async {
    await _ensureGoogleSignInReady();

    final GoogleSignInAccount googleUser = await GoogleSignIn.instance
        .authenticate();
    final idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      throw Exception('Google sign-in failed — no ID token returned');
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user!;

    final userDoc = await _db.collection('users').doc(user.uid).get();
    if (userDoc.exists) return; // returning user — profile already set up

    // First-time Google sign-in: reserve a unique username and create the profile.
    final base = (user.email ?? 'user')
        .split('@')
        .first
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '')
        .toLowerCase();
    final safeBase = base.isEmpty ? 'user' : base;
    var usernameLower = safeBase;
    var attempt = 0;
    final rand = Random();
    while ((await _db.collection('usernames').doc(usernameLower).get())
        .exists) {
      attempt++;
      usernameLower = '$safeBase${rand.nextInt(9000) + 1000}';
      if (attempt > 8) break; // extremely unlikely, but don't loop forever
    }

    final batch = _db.batch();
    batch.set(_db.collection('usernames').doc(usernameLower), {
      'uid': user.uid,
    });
    batch.set(_db.collection('users').doc(user.uid), {
      'uid': user.uid,
      'email': user.email ?? '',
      'name': user.displayName ?? '',
      'username': usernameLower,
      'username_lower': usernameLower,
      'photoUrl': user.photoURL ?? '',
      'bio': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }
}
