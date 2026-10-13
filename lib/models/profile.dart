import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_utils.dart';

/// Mirrors `Preferences.swift`.
/// Firestore document: `users/{uid}/preferences/tenant`.
class Preferences {
  const Preferences({
    this.locationQuery = '',
    this.budgetMin = 1000,
    this.budgetMax = 3000,
    this.selectedBedroom = 'Studio',
    this.petsAllowed = false,
    this.fullyFurnished = false,
    this.parkingIncluded = false,
  });

  final String locationQuery;
  final double budgetMin;
  final double budgetMax;

  /// One of "Studio", "1", "2", "3+".
  final String selectedBedroom;
  final bool petsAllowed;
  final bool fullyFurnished;
  final bool parkingIncluded;

  static const bedroomOptions = ['Studio', '1', '2', '3+'];

  factory Preferences.fromFirestore(Map<String, dynamic> d) => Preferences(
        locationQuery: readString(d['locationQuery']),
        budgetMin: readDouble(d['budgetMin']),
        budgetMax: readDouble(d['budgetMax'], 5000),
        selectedBedroom: readString(d['selectedBedroom'], 'Studio'),
        petsAllowed: readBool(d['petsAllowed']),
        fullyFurnished: readBool(d['fullyFurnished']),
        parkingIncluded: readBool(d['parkingIncluded']),
      );

  Map<String, dynamic> toFirestore() => {
        'locationQuery': locationQuery,
        'budgetMin': budgetMin,
        'budgetMax': budgetMax,
        'selectedBedroom': selectedBedroom,
        'petsAllowed': petsAllowed,
        'fullyFurnished': fullyFurnished,
        'parkingIncluded': parkingIncluded,
      };

  /// Same filter as `TenantHome.filteredListings`.
  bool matches({required double price, required int bedrooms}) {
    final priceOk = price >= budgetMin && price <= budgetMax;
    final bool bedsOk;
    if (selectedBedroom == 'Studio') {
      bedsOk = bedrooms == 0;
    } else if (selectedBedroom == '3+') {
      bedsOk = bedrooms >= 3;
    } else {
      final exact = int.tryParse(selectedBedroom);
      bedsOk = exact == null || bedrooms == exact;
    }
    return priceOk && bedsOk;
  }
}

/// Mirrors `DocumentType.swift`.
enum DocumentType { id, paystub, tax, lease }

/// Mirrors `UserDocument.swift`.
/// Firestore document: `users/{uid}/documents/{type}`.
class UserDocument {
  const UserDocument(
      {required this.type, required this.url, required this.status});

  final String type;
  final String url;
  final String status;

  static UserDocument? fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    final type = readOptString(d['type']);
    final url = readOptString(d['url']);
    final status = readOptString(d['status']);
    if (type == null || url == null || status == null) return null;
    return UserDocument(type: type, url: url, status: status);
  }
}
