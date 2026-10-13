import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../models/listing.dart';
import '../../providers.dart';
import '../../utils/format.dart';
import '../../utils/media.dart';
import '../../widgets/common.dart';
import '../landlord/landlord_profile.dart';
import '../shared/chat.dart';

/// OpenStreetMap tiles. For production traffic, switch to a commercial tile
/// provider (MapTiler, Mapbox, Stadia) per the OSM tile usage policy.
TileLayer osmTiles() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.IOSGROUP.quartier',
    );

/// Port of `ApartmentDetailView.swift`.
class ApartmentDetailScreen extends ConsumerStatefulWidget {
  const ApartmentDetailScreen({super.key, required this.listing});
  final Listing listing;

  @override
  ConsumerState<ApartmentDetailScreen> createState() =>
      _ApartmentDetailScreenState();
}

class _ApartmentDetailScreenState extends ConsumerState<ApartmentDetailScreen> {
  bool _expanded = false;
  bool _opening = false;

  Listing get l => widget.listing;

  Future<void> _contactLandlord() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null || user.email.trim().isEmpty) {
      showMessage(context, 'Message', 'Please sign in to contact landlord.');
      return;
    }
    setState(() => _opening = true);
    try {
      final conv = await ref.read(chatRepoProvider).openOrCreate(
            tenantId: user.id,
            tenantName: user.displayName,
            landlordId: l.landLordId,
            listingId: l.listingId,
            listingAddress: l.address,
          );
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatScreen(conversation: conv, isLandlord: false)));
    } catch (e) {
      if (mounted) showMessage(context, 'Message', '$e');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final landlord = ref.watch(userProfileProvider(l.landLordId)).value;
    final height = MediaQuery.sizeOf(context).height * .35;
    final coord = LatLng(l.latitude ?? 45.5019, l.longitude ?? -73.5674);

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: const BackButton(
            style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(Colors.black38))),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: height,
            child: l.existingImageUrls.isEmpty
                ? const Center(
                    child: Icon(Icons.house, size: 120, color: Colors.grey))
                : PageView(
                    children: [
                      for (final url in l.existingImageUrls)
                        NetImage(url, height: height, width: double.infinity),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.listingName,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('${dollars2(l.price)}/mo',
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Apartment Listing'),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.location_searching, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(l.address,
                      style: const TextStyle(
                          fontStyle: FontStyle.italic, color: Colors.grey)),
                ),
              ]),
              const Divider(height: 24),
              IntrinsicHeight(
                child: Row(children: [
                  _info(l.bedrooms, 'BEDROOMS'),
                  const VerticalDivider(),
                  _info(l.bathrooms, 'BATH'),
                  const VerticalDivider(),
                  _info(l.squareFeet, 'SQFT'),
                ]),
              ),
              const Divider(height: 24),
              const SizedBox(height: 12),
              const Text('About this place',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                l.rules.isEmpty
                    ? 'This apartment offers a comfortable and well-designed '
                        'living space with plenty of natural light and a '
                        'practical layout suited for everyday living.'
                    : l.rules,
                maxLines: _expanded ? null : 3,
                overflow: _expanded ? null : TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Read less' : 'Read more',
                    style: const TextStyle(fontSize: 12)),
              ),
              const Text('Amenities',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              for (final a in l.amenities)
                Text('• $a',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const Divider(height: 24),
              InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => LandlordProfile(publicId: l.landLordId))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Avatar(url: landlord?.profilePic, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Listed by',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                            Text(
                                landlord == null
                                    ? 'Loading...'
                                    : (landlord.name.isNotEmpty
                                        ? landlord.name
                                        : landlord.email),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ]),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.black38),
                  ]),
                ),
              ),
              const Divider(height: 24),
              Row(children: [
                const Text('Location',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                  onPressed: l.latitude == null
                      ? null
                      : () => openDirections(
                          l.latitude!, l.longitude!, l.listingName),
                  child: const Text('Get Directions'),
                ),
              ]),
              MapCard(coordinate: coord, label: l.address),
              const SizedBox(height: 16),
              PrimaryButton('Contact Landlord',
                  onPressed: _contactLandlord, busy: _opening),
              const SizedBox(height: 24),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _info(int value, String title) => Expanded(
        child: Column(children: [
          Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(title,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      );
}

/// Port of `MapCard`: a small non-interactive map with an address label.
class MapCard extends StatelessWidget {
  const MapCard({super.key, required this.coordinate, required this.label});
  final LatLng coordinate;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 140,
        child: Stack(children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: coordinate,
              initialZoom: 15,
              interactionOptions:
                  const InteractionOptions(flags: InteractiveFlag.none),
            ),
            children: [
              osmTiles(),
              MarkerLayer(markers: [
                Marker(
                  point: coordinate,
                  child: const Icon(Icons.location_pin,
                      color: Colors.red, size: 36),
                ),
              ]),
            ],
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .85),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}
