import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../models/listing.dart';

/// Replaces the Core Data `LDListing` + `DraftImage` entities. Drafts never
/// reach Firestore (the iOS sync skipped them too), so they live on-device:
///
///   `{app documents}/drafts/{landlordUid}/{listingId}/draft.json`
///   `{app documents}/drafts/{landlordUid}/{listingId}/img_{n}.jpg`
class DraftStore {
  Future<Directory> _root(String uid) async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/drafts/$uid');
  }

  Future<List<Listing>> loadDrafts(String uid) async {
    final root = await _root(uid);
    if (!await root.exists()) return [];
    final drafts = <Listing>[];
    await for (final dir in root.list()) {
      if (dir is! Directory) continue;
      final json = File('${dir.path}/draft.json');
      if (!await json.exists()) continue;
      try {
        final d = jsonDecode(await json.readAsString()) as Map<String, dynamic>;
        final images = <Uint8List>[];
        for (var i = 0; i < (d['imageCount'] as int? ?? 0); i++) {
          final f = File('${dir.path}/img_$i.jpg');
          if (await f.exists()) images.add(await f.readAsBytes());
        }
        drafts.add(Listing(
          listingId: d['listingId'] as String,
          listingName: d['listingName'] as String? ?? '',
          landLordId: uid,
          tenantId: d['tenantId'] as String? ?? '',
          price: (d['price'] as num? ?? 0).toDouble(),
          bedrooms: d['bedrooms'] as int? ?? 0,
          bathrooms: d['bathrooms'] as int? ?? 0,
          squareFeet: d['squareFeet'] as int? ?? 0,
          amenities: (d['amenities'] as List? ?? []).cast<String>(),
          rules: d['rules'] as String? ?? '',
          address: d['address'] as String? ?? '',
          latitude: (d['latitude'] as num?)?.toDouble(),
          longitude: (d['longitude'] as num?)?.toDouble(),
          newImages: images,
          existingImageUrls: (d['existingImageUrls'] as List? ?? []).cast<String>(),
          status: ListingStatus.draft,
          isRented: d['isRented'] as bool? ?? false,
          rentDueDay: d['rentDueDay'] as int? ?? 1,
          createdAt: DateTime.tryParse(d['createdAt'] as String? ?? ''),
          updatedAt: DateTime.tryParse(d['updatedAt'] as String? ?? ''),
        ));
      } on FormatException {
        // Skip a corrupt draft rather than failing the whole list.
      }
    }
    drafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return drafts;
  }

  Future<void> saveDraft(String uid, Listing l) async {
    final dir = Directory('${(await _root(uid)).path}/${l.listingId}');
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    for (var i = 0; i < l.newImages.length; i++) {
      await File('${dir.path}/img_$i.jpg').writeAsBytes(l.newImages[i]);
    }
    await File('${dir.path}/draft.json').writeAsString(jsonEncode({
      'listingId': l.listingId,
      'listingName': l.listingName,
      'tenantId': l.tenantId,
      'price': l.price,
      'bedrooms': l.bedrooms,
      'bathrooms': l.bathrooms,
      'squareFeet': l.squareFeet,
      'amenities': l.amenities,
      'rules': l.rules,
      'address': l.address,
      'latitude': l.latitude,
      'longitude': l.longitude,
      'existingImageUrls': l.existingImageUrls,
      'isRented': l.isRented,
      'rentDueDay': l.rentDueDay,
      'imageCount': l.newImages.length,
      'createdAt': l.createdAt.toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    }));
  }

  Future<void> deleteDraft(String uid, String listingId) async {
    final dir = Directory('${(await _root(uid)).path}/$listingId');
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
