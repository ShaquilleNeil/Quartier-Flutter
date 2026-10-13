import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_utils.dart';

enum UserRole {
  tenant,
  landlord;

  static UserRole? parse(Object? raw) => switch (raw) {
        String s when s.toLowerCase() == 'landlord' => UserRole.landlord,
        String s when s.toLowerCase() == 'tenant' => UserRole.tenant,
        _ => null,
      };

  String get label => name[0].toUpperCase() + name.substring(1);
}

/// Mirrors `User.swift` plus the routing fields `AuthService` reads.
/// Firestore document: `users/{uid}`.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.profilePic,
    required this.role,
    required this.createdAt,
    required this.isActive,
    required this.isRenting,
    required this.apartmentId,
    required this.hasCompletedPreferences,
    required this.rentedAddress,
  });

  final String id;
  final String email;
  final String name;
  final String profilePic;
  final UserRole? role;
  final DateTime createdAt;
  final bool isActive;
  final bool isRenting;

  /// Listing id the tenant is renting, or empty.
  final String apartmentId;
  final bool hasCompletedPreferences;
  final String? rentedAddress;

  String? get rentedListingId => apartmentId.isEmpty ? null : apartmentId;

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    final addr = readString(d['rentedAddress']);
    return AppUser(
      id: readString(d['id'], doc.id),
      email: readString(d['email']),
      name: readString(d['name']),
      profilePic: readString(d['profilePic']),
      role: UserRole.parse(d['role']),
      createdAt: readDate(d['createdAt']),
      isActive: readBool(d['isActive'], true),
      isRenting: readBool(d['isRenting']),
      apartmentId: readString(d['apartmentId']),
      hasCompletedPreferences: readBool(d['hasCompletedPreferences']),
      rentedAddress: addr.isEmpty ? null : addr,
    );
  }

  /// Display name with the same fallback the iOS chat screens use.
  String get displayName =>
      name.isNotEmpty ? name : email.split('@').first;
}

/// Mirrors `TenantItem.swift`; used in the landlord's tenant picker.
class TenantItem {
  const TenantItem({required this.id, required this.email});
  final String id;
  final String email;

  @override
  bool operator ==(Object other) => other is TenantItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
