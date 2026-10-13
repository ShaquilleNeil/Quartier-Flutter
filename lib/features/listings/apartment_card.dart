import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/listing.dart';
import '../../providers.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import 'apartment_detail.dart';

/// Port of `ApartmentCard.swift` (tenant feed / saved list).
class ApartmentCard extends ConsumerWidget {
  const ApartmentCard({super.key, required this.listing});
  final Listing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite =
        ref.watch(favoriteIdsProvider).value?.contains(listing.listingId) ??
            false;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ApartmentDetailScreen(listing: listing))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: .19),
                blurRadius: 8,
                offset: const Offset(0, 4)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            NetImage(listing.existingImageUrls.firstOrNull,
                height: 200, width: double.infinity),
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.black.withValues(alpha: .4),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.white),
                  onPressed: () {
                    final uid = ref.read(currentUidProvider);
                    if (uid == null) return;
                    ref
                        .read(listingRepoProvider)
                        .toggleFavorite(uid, listing.listingId);
                  },
                ),
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(listing.listingName,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(children: [
                Text(dollars2(listing.price),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue)),
                const SizedBox(width: 4),
                const Text('/ mo', style: TextStyle(color: Colors.grey)),
              ]),
              const SizedBox(height: 6),
              Text(listing.address.isEmpty ? 'unknown address' : listing.address),
              const SizedBox(height: 6),
              DefaultTextStyle(
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                child: Row(children: [
                  const Icon(Icons.bed_outlined, size: 14, color: Colors.grey),
                  Text(' ${listing.bedrooms} bed'),
                  const SizedBox(width: 14),
                  const Icon(Icons.bathtub_outlined,
                      size: 14, color: Colors.grey),
                  Text(' ${listing.bathrooms} bath'),
                  const SizedBox(width: 14),
                  const Icon(Icons.straighten, size: 14, color: Colors.grey),
                  Text(' ${listing.squareFeet} sqft'),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Port of `RemoteListingCard` / the landlord `remoteCard` and `draftCard`.
class ListingRowCard extends StatelessWidget {
  const ListingRowCard({
    super.key,
    required this.listing,
    required this.statusLabel,
    required this.statusColor,
    this.onTap,
    this.onDelete,
  });

  final Listing listing;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final Widget thumb;
    if (listing.existingImageUrls.isNotEmpty) {
      thumb = NetImage(listing.existingImageUrls.first, width: 85, height: 85);
    } else if (listing.newImages.isNotEmpty) {
      thumb = Image.memory(listing.newImages.first,
          width: 85, height: 85, fit: BoxFit.cover);
    } else {
      thumb = Container(
        width: 85,
        height: 85,
        color: statusColor.withValues(alpha: .15),
        child: Icon(Icons.photo, color: statusColor),
      );
    }

    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: statusColor.withValues(alpha: .25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(14), child: thumb),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          listing.address.isEmpty
                              ? 'Untitled Listing'
                              : listing.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Pill(statusLabel, color: statusColor),
                      if (onDelete != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: onDelete,
                        ),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      '${cad(listing.price)} • ${listing.bedrooms} bds • '
                      '${listing.bathrooms} ba',
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}

Color statusColor(String status) => switch (status.toLowerCase()) {
      'published' => Colors.green,
      'rented' => Colors.blue,
      _ => Colors.grey,
    };
