import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

import '../models/events.dart';
import '../models/listing.dart';

/// Listing, tenant-assignment, lease, maintenance and favorites operations
/// from `FirebaseManager.swift`.
class ListingRepository {
  ListingRepository(this._db, this._storage);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _listings =>
      _db.collection('listings');

  List<Listing> _parse(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map(Listing.fromFirestore).toList();

  /// `fetchListingsLandlord`, live. Sorted newest-updated first.
  Stream<List<Listing>> landlordListings(String uid) => _listings
      .where('landLordId', isEqualTo: uid)
      .snapshots()
      .map((s) => _parse(s)..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));

  /// `fetchListingsLandlordPublic`.
  Stream<List<Listing>> publicLandlordListings(String uid) => _listings
      .where('landLordId', isEqualTo: uid)
      .where('status', isEqualTo: 'published')
      .snapshots()
      .map((s) => _parse(s)..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));

  /// `fetchAllListings`: everything not rented.
  Stream<List<Listing>> availableListings() => _listings
      .where('isRented', isEqualTo: false)
      .snapshots()
      .map(_parse);

  /// `listenToListing`.
  Stream<Listing?> listingStream(String id) => _listings
      .doc(id)
      .snapshots()
      .map((s) => s.exists ? Listing.fromFirestore(s) : null);

  Future<List<Listing>> listingsByIds(List<String> ids) async {
    final out = <Listing>[];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final s =
          await _listings.where(FieldPath.documentId, whereIn: chunk).get();
      out.addAll(_parse(s));
    }
    return out;
  }

  /// Port of `uploadListingImages`. The iOS app names files `image_<i>.jpg`,
  /// which overwrote earlier photos when a listing was edited; a timestamp
  /// keeps every upload unique in the same folder.
  Future<List<String>> uploadListingImages(
      String listingId, List<Uint8List> images) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final urls = <String>[];
    for (var i = 0; i < images.length; i++) {
      try {
        final ref = _storage.ref('listings/$listingId/image_${stamp}_$i.jpg');
        await ref.putData(
            images[i], SettableMetadata(contentType: 'image/jpeg'));
        urls.add(await ref.getDownloadURL());
      } on FirebaseException {
        // Same as iOS: a failed upload is skipped, the rest still publish.
      }
    }
    return urls;
  }

  /// Port of `saveListing` (set with merge; `createdAt` only on first write).
  Future<void> saveListing(Listing l, {required List<String> imageUrls}) async {
    final ref = _listings.doc(l.listingId);
    final data = <String, dynamic>{
      'id': l.listingId,
      'listingName': l.listingName,
      'landLordId': l.landLordId,
      'tenantId': l.tenantId,
      'price': l.price.toDouble(),
      'squareFeet': l.squareFeet,
      'bedrooms': l.bedrooms,
      'bathrooms': l.bathrooms,
      'amenities': l.amenities,
      'status': l.status.name,
      'rules': l.rules,
      'images': imageUrls,
      'address': l.address,
      'location': GeoPoint(l.latitude ?? 0, l.longitude ?? 0),
      'isRented': l.tenantId.isNotEmpty,
      'rentDueDay': l.rentDueDay,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final existing = await ref.get();
    if (!existing.exists) data['createdAt'] = FieldValue.serverTimestamp();
    await ref.set(data, SetOptions(merge: true));
  }

  Future<void> deleteListing(String listingId) =>
      _listings.doc(listingId).delete();

  /// Port of `assignTenantToListing`.
  Future<void> assignTenant(String listingId, String tenantId) {
    final batch = _db.batch()
      ..update(_listings.doc(listingId), {
        'tenantId': tenantId,
        'isRented': true,
        'updatedAt': FieldValue.serverTimestamp(),
      })
      ..update(_db.collection('users').doc(tenantId), {
        'isRenting': true,
        'apartmentId': listingId,
      });
    return batch.commit();
  }

  /// Port of `removeTenantFromListing`.
  Future<void> removeTenant(String listingId, String previousTenantId) {
    final batch = _db.batch()
      ..update(_listings.doc(listingId), {'tenantId': '', 'isRented': false})
      ..update(_db.collection('users').doc(previousTenantId), {
        'isRenting': false,
        'apartmentId': '',
      });
    return batch.commit();
  }

  // MARK: - Lease (documents/{listingId}_lease)

  Future<void> uploadLease(
      {required String landlordId,
      required String listingId,
      required File file}) async {
    final ref = _storage.ref('users/$landlordId/documents/$listingId/lease.pdf');
    await ref.putFile(file);
    final url = await ref.getDownloadURL();
    await _db.collection('documents').doc('${listingId}_lease').set({
      'type': 'lease',
      'url': url,
      'listingId': listingId,
      'landlordId': landlordId,
      'status': 'pending',
      // Not written by iOS, but `fetchLeaseFileName` reads it.
      'fileName': p.basename(file.path),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> fetchLeaseFileName(String listingId) async {
    final s = await _db.collection('documents').doc('${listingId}_lease').get();
    if (!s.exists) return null;
    return s.data()?['fileName'] as String? ?? 'lease.pdf';
  }

  Future<String?> fetchLeaseUrl(String listingId) async {
    final s = await _db.collection('documents').doc('${listingId}_lease').get();
    return s.data()?['url'] as String?;
  }

  // MARK: - Maintenance

  CollectionReference<Map<String, dynamic>> _maintenance(String listingId) =>
      _listings.doc(listingId).collection('maintenanceRequests');

  /// Port of `submitMaintenanceRequest`. iOS uploaded the photos with
  /// `uploadListingImages`, overwriting the listing's own photos; these use
  /// their own file names in the same folder.
  Future<void> submitMaintenance(
      MaintenanceRequest r, List<Uint8List> photos) async {
    final urls = <String>[];
    for (var i = 0; i < photos.length; i++) {
      final ref =
          _storage.ref('listings/${r.listingId}/maintenance_${r.id}_$i.jpg');
      await ref.putData(photos[i], SettableMetadata(contentType: 'image/jpeg'));
      urls.add(await ref.getDownloadURL());
    }
    await _maintenance(r.listingId).doc(r.id).set({
      'id': r.id,
      'listingId': r.listingId,
      'tenantId': r.tenantId,
      'description': r.description,
      'date': Timestamp.fromDate(r.date),
      'status': r.status.name,
      'photoURLs': urls,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<MaintenanceRequest>> maintenanceRequests(String listingId) =>
      _maintenance(listingId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs
              .map((d) => MaintenanceRequest.fromFirestore(d, listingId))
              .whereType<MaintenanceRequest>()
              .toList());

  /// Port of `fetchLatestMaintenanceRequest`: newest request (by `date`)
  /// across the given listings.
  Future<MaintenanceRequest?> latestMaintenance(List<String> listingIds) async {
    final results = await Future.wait(listingIds.map((id) async {
      final s = await _maintenance(id)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      return s.docs.isEmpty
          ? null
          : MaintenanceRequest.fromFirestore(s.docs.first, id);
    }));
    final found = results.whereType<MaintenanceRequest>().toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return found.isEmpty ? null : found.first;
  }

  Future<void> resolveMaintenance(String listingId, String requestId) =>
      _maintenance(listingId).doc(requestId).update({'status': 'resolved'});

  // MARK: - Favorites (users/{uid}/favorites/{listingId})

  CollectionReference<Map<String, dynamic>> _favorites(String uid) =>
      _db.collection('users').doc(uid).collection('favorites');

  Stream<Set<String>> favoriteIds(String uid) => _favorites(uid)
      .snapshots()
      .map((s) => s.docs.map((d) => d.id).toSet());

  /// Port of `saveFavorite` (a toggle).
  Future<void> toggleFavorite(String uid, String listingId) async {
    final ref = _favorites(uid).doc(listingId);
    if ((await ref.get()).exists) {
      await ref.delete();
    } else {
      await ref.set({
        'listingId': listingId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
