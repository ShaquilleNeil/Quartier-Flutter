import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../models/listing.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../listings/apartment_detail.dart';
import 'tenant_home.dart';

/// Port of `TenantDiscover.swift`: map of available listings with price
/// pins showing the difference from the tenant's rent or budget.
class TenantDiscover extends ConsumerStatefulWidget {
  const TenantDiscover({super.key});

  @override
  ConsumerState<TenantDiscover> createState() => _TenantDiscoverState();
}

class _TenantDiscoverState extends ConsumerState<TenantDiscover> {
  static const _montreal = LatLng(45.5017, -73.5673);
  final _map = MapController();
  LatLng? _userLocation;
  bool _showHome = false;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  /// `LocationManager.swift`: ask once, centre on the user if allowed.
  Future<void> _locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final here = LatLng(pos.latitude, pos.longitude);
      setState(() => _userLocation = here);
      _map.move(here, 14);
    } catch (_) {
      // Location is optional; stay on the fallback centre.
    }
  }

  void _zoom(double delta) {
    final cam = _map.camera;
    _map.move(cam.center, (cam.zoom + delta).clamp(3, 18));
  }

  String? _priceDiff(double price, double? baseline) {
    if (baseline == null || baseline <= 0) return null;
    final diff = price - baseline;
    if (diff == 0) return 'On Budget';
    return diff > 0 ? '+\$${diff.toInt()}' : '-\$${diff.abs().toInt()}';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final isRenting = user?.isRenting ?? false;

    if (isRenting && _showHome) {
      return Column(children: [
        SafeArea(bottom: false, child: _toggle()),
        const Expanded(child: TenantHome()),
      ]);
    }

    final listings = ref.watch(availableListingsProvider).value ?? [];
    // Baseline: current rent if renting, else max budget (as on iOS).
    final rent = ref.watch(rentedListingProvider).value?.price;
    final budget = ref.watch(preferencesProvider).value?.budgetMax;
    final baseline = (rent != null && rent > 0) ? rent : budget;

    return Stack(children: [
      FlutterMap(
        mapController: _map,
        options: const MapOptions(initialCenter: _montreal, initialZoom: 13),
        children: [
          osmTiles(),
          MarkerLayer(markers: [
            if (_userLocation != null)
              Marker(
                point: _userLocation!,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            for (final l in listings)
              if (l.latitude != null && l.longitude != null)
                Marker(
                  point: LatLng(l.latitude!, l.longitude!),
                  width: 90,
                  height: 100,
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: () => _openListing(l),
                    child: _Pin(listing: l, diff: _priceDiff(l.price, baseline)),
                  ),
                ),
          ]),
        ],
      ),
      if (isRenting) SafeArea(child: _toggle()),
      Positioned(
        right: 16,
        bottom: 16,
        child: Column(children: [
          IconButton.filledTonal(
              icon: const Icon(Icons.add), onPressed: () => _zoom(1)),
          const SizedBox(height: 12),
          IconButton.filledTonal(
              icon: const Icon(Icons.remove), onPressed: () => _zoom(-1)),
        ]),
      ),
    ]);
  }

  Widget _toggle() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: SegmentedButton<bool>(
          style: SegmentedButton.styleFrom(backgroundColor: Colors.white),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: true, label: Text('Home')),
            ButtonSegment(value: false, label: Text('Discover')),
          ],
          selected: {_showHome},
          onSelectionChanged: (s) => setState(() => _showHome = s.first),
        ),
      );

  void _openListing(Listing l) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => ApartmentDetailScreen(listing: l)),
          ),
        ),
      );
}

class _Pin extends StatelessWidget {
  const _Pin({required this.listing, required this.diff});
  final Listing listing;
  final String? diff;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(blurRadius: 2, color: Colors.black26)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('\$${listing.price.toInt()}',
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          if (diff != null)
            Text(diff!,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: diff!.startsWith('+') ? Colors.red : Colors.green)),
        ]),
      ),
      const SizedBox(height: 2),
      Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black26)],
        ),
        child: ClipOval(
          child: NetImage(listing.existingImageUrls.firstOrNull,
              width: 50, height: 50),
        ),
      ),
    ]);
  }
}
