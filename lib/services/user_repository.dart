import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/app_user.dart';
import '../models/profile.dart';

/// User, profile, preferences and verification-document operations from
/// `FirebaseManager.swift`.
class UserRepository {
  UserRepository(this._db, this._storage);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  Stream<DocumentSnapshot<Map<String, dynamic>>> userDocStream(String uid) =>
      _user(uid).snapshots();

  Future<AppUser?> fetchUser(String uid) async {
    if (uid.isEmpty) return null;
    final snap = await _user(uid).get();
    return snap.exists ? AppUser.fromFirestore(snap) : null;
  }

  Future<String> uploadProfileImage(String uid, Uint8List data) async {
    final ref = _storage.ref('users/$uid/profile.jpg');
    await ref.putData(data, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<void> updateProfile({
    required String uid,
    required String name,
    String? profilePic,
  }) =>
      _user(uid).update({
        'name': name,
        'profilePic': ?profilePic,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Port of `AuthService.saveProfile`.
  Future<void> saveProfile({
    required String uid,
    required String name,
    Uint8List? imageData,
  }) async {
    String? url;
    if (imageData != null) url = await uploadProfileImage(uid, imageData);
    await updateProfile(uid: uid, name: name, profilePic: url);
  }

  /// Port of `fetchAllTenants`: every user with role "tenant" and an email.
  Future<List<TenantItem>> fetchAllTenants() async {
    final snap =
        await _db.collection('users').where('role', isEqualTo: 'tenant').get();
    final items = <TenantItem>[];
    for (final doc in snap.docs) {
      final email =
          (doc.data()['email'] as String? ?? '').trim().toLowerCase();
      if (email.isNotEmpty) items.add(TenantItem(id: doc.id, email: email));
    }
    items.sort((a, b) => a.email.compareTo(b.email));
    return items;
  }

  // MARK: - Preferences (users/{uid}/preferences/tenant)

  DocumentReference<Map<String, dynamic>> _prefs(String uid) =>
      _user(uid).collection('preferences').doc('tenant');

  Stream<Preferences?> preferencesStream(String uid) => _prefs(uid)
      .snapshots()
      .map((s) => s.exists ? Preferences.fromFirestore(s.data()!) : null);

  /// Port of `CoreDataManager.savePreferences` +
  /// `updateUserHasCompletedPreferences`.
  Future<void> savePreferences(String uid, Preferences prefs) async {
    await _prefs(uid).set({
      ...prefs.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _user(uid).update({'hasCompletedPreferences': true});
  }

  // MARK: - Verification documents (users/{uid}/documents/{type})

  Stream<List<UserDocument>> documentsStream(String uid) => _user(uid)
      .collection('documents')
      .snapshots()
      .map((s) => s.docs
          .map(UserDocument.fromFirestore)
          .whereType<UserDocument>()
          .toList());

  Future<List<UserDocument>> fetchDocuments(String uid) async {
    final snap = await _user(uid).collection('documents').get();
    return snap.docs
        .map(UserDocument.fromFirestore)
        .whereType<UserDocument>()
        .toList();
  }

  /// Port of `uploadDocument`. The iOS app always names the file `.pdf`,
  /// even for images; kept for compatibility.
  Future<void> uploadDocument(String uid, File file, DocumentType type) async {
    final ref = _storage.ref('users/$uid/documents/${type.name}.pdf');
    await ref.putFile(file);
    final url = await ref.getDownloadURL();
    await _user(uid).collection('documents').doc(type.name).set({
      'type': type.name,
      'url': url,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteDocument(String uid, DocumentType type) async {
    await _storage.ref('users/$uid/documents/${type.name}.pdf').delete();
    await _user(uid).collection('documents').doc(type.name).delete();
  }
}
