import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import 'user_repository.dart';

/// Port of `AuthService.swift`. Routing state (role, preferences, renting)
/// comes from the `users/{uid}` stream in `providers.dart`.
class AuthService {
  AuthService(this._auth, this._users);

  final FirebaseAuth _auth;
  final UserRepository _users;

  /// True between `createUserWithEmailAndPassword` and the user document
  /// being written, so the auth gate doesn't treat the missing document as a
  /// deleted account and sign the new user out.
  static bool isRegistering = false;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> login(String email, String password) => _auth
      .signInWithEmailAndPassword(email: email.trim(), password: password);

  /// Creates the auth account and the `users/{uid}` document with the same
  /// fields `FirebaseManager.saveUser` writes, then uploads the avatar.
  Future<void> register({
    required String email,
    required String password,
    required UserRole role,
    required String fullName,
    Uint8List? imageData,
  }) async {
    isRegistering = true;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      final uid = cred.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'id': uid,
        'name': fullName.trim().isEmpty
            ? email.split('@').first
            : fullName.trim(),
        'profilePic': '',
        'email': email.trim(),
        'role': role.name,
        'isRenting': false,
        'apartmentId': '',
        'hasCompletedPreferences': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (imageData != null) {
        final url = await _users.uploadProfileImage(uid, imageData);
        await _users.updateProfile(uid: uid, name: fullName.trim(), profilePic: url);
      }
    } finally {
      isRegistering = false;
    }
  }

  Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => _auth.signOut();
}

/// Turns Firebase errors into the short messages shown in the UI.
String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => 'That email address is not valid.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' =>
        'Incorrect email or password.',
      'email-already-in-use' => 'An account already exists for that email.',
      'weak-password' => 'Password is too weak.',
      'too-many-requests' => 'Too many attempts. Try again later.',
      _ => error.message ?? 'Authentication failed.',
    };
  }
  return error.toString();
}
