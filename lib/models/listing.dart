import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_utils.dart';

enum ListingStatus {
  draft,
  published;

  static ListingStatus parse(Object? raw) => raw is String &&
          raw.toLowerCase() == 'published'
      ? ListingStatus.published
      : ListingStatus.draft;
}

/// Mirrors `Listing.swift`. Firestore document: `listings/{listingId}`.
///
/// Note the Firestore field names the iOS app uses: `landLordId` (capital L),
/// `images` for the URL list, and `location` as a GeoPoint.
class Listing {
  Listing({
    String? listingId,
    this.listingName = '',
    this.landLordId = '',
    this.tenantId = '',
    this.price = 0,
    this.bedrooms = 0,
    this.bathrooms = 0,
    this.squareFeet = 0,
    List<String>? amenities,
    this.rules = '',
    this.address = '',
    this.latitude,
    this.longitude,
    List<Uint8List>? newImages,
    List<String>? existingImageUrls,
    this.status = ListingStatus.draft,
    this.isRented = false,
    this.rentDueDay = 1,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : listingId = listingId ?? newUuid(),
        amenities = amenities ?? [],
        newImages = newImages ?? [],
        existingImageUrls = existingImageUrls ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String listingId;
  String listingName;
  String landLordId;
  String tenantId;
  double price;
  int bedrooms;
  int bathrooms;
  int squareFeet;
  List<String> amenities;
  String rules;
  String address;
  double? latitude;
  double? longitude;

  /// Picked but not yet uploaded images (JPEG bytes). UI-only.
  List<Uint8List> newImages;
  List<String> existingImageUrls;

  ListingStatus status;
  bool isRented;
  int rentDueDay;
  DateTime createdAt;
  DateTime updatedAt;

  factory Listing.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    final loc = d['location'];
    return Listing(
      listingId: normalizeUuid(doc.id),
      listingName: readString(d['listingName']),
      landLordId: readString(d['landLordId']),
      tenantId: readString(d['tenantId']),
      price: readDouble(d['price']),
      bedrooms: readInt(d['bedrooms']),
      bathrooms: readInt(d['bathrooms']),
      squareFeet: readInt(d['squareFeet']),
      amenities: readStringList(d['amenities']),
      rules: readString(d['rules']),
      address: readString(d['address']),
      latitude: loc is GeoPoint ? loc.latitude : null,
      longitude: loc is GeoPoint ? loc.longitude : null,
      existingImageUrls: readStringList(d['images']),
      status: ListingStatus.parse(d['status']),
      isRented: readBool(d['isRented']),
      rentDueDay: readInt(d['rentDueDay'], 1),
      createdAt: readDate(d['createdAt']),
      updatedAt: readDate(d['updatedAt']),
    );
  }

  Listing copy() => Listing(
        listingId: listingId,
        listingName: listingName,
        landLordId: landLordId,
        tenantId: tenantId,
        price: price,
        bedrooms: bedrooms,
        bathrooms: bathrooms,
        squareFeet: squareFeet,
        amenities: [...amenities],
        rules: rules,
        address: address,
        latitude: latitude,
        longitude: longitude,
        newImages: [...newImages],
        existingImageUrls: [...existingImageUrls],
        status: status,
        isRented: isRented,
        rentDueDay: rentDueDay,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
