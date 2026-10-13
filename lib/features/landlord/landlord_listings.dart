import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/listing.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../listings/apartment_card.dart';
import 'listing_form.dart';

enum _Mode { drafts, published, rented }

/// Port of `LandlordListings.swift` (`MyListingsView`).
class LandlordListings extends ConsumerStatefulWidget {
  const LandlordListings({super.key});

  @override
  ConsumerState<LandlordListings> createState() => _LandlordListingsState();
}

class _LandlordListingsState extends ConsumerState<LandlordListings> {
  _Mode _mode = _Mode.drafts;

  void _open(Listing? listing) => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ListingFormScreen(existing: listing)));

  Future<bool> _confirmDelete() async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete listing?'),
          content: const Text('This cannot be undone.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child:
                    const Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final remote = ref.watch(landlordListingsProvider);
    final drafts = ref.watch(draftsProvider).value ?? [];

    final remoteIds = (remote.value ?? []).map((l) => l.listingId).toSet();
    final draftRows = drafts.where((d) => !d.isRented).toList();
    final rentedDraftsNotOnFirebase = drafts
        .where((d) => d.isRented && !remoteIds.contains(d.listingId))
        .toList();

    Widget remoteCard(Listing l) => ListingRowCard(
          listing: l,
          statusLabel: l.status == ListingStatus.published ? 'Published' : 'Draft',
          statusColor: statusColor(l.status.name),
          onTap: () => _open(l),
          onDelete: () async {
            if (await _confirmDelete()) {
              await ref.read(listingRepoProvider).deleteListing(l.listingId);
            }
          },
        );

    Widget draftCard(Listing l, {bool rented = false}) => ListingRowCard(
          listing: l,
          statusLabel: rented ? 'Rented (draft)' : 'Draft',
          statusColor: rented ? Colors.blue : Colors.orange,
          onTap: () => _open(l),
          onDelete: () => ref.read(draftsProvider.notifier).delete(l.listingId),
        );

    final List<Widget> cards = switch (_mode) {
      _Mode.drafts => [for (final d in draftRows) draftCard(d)],
      _Mode.published => [
          for (final l in remote.value ?? <Listing>[])
            if (l.status == ListingStatus.published && !l.isRented)
              remoteCard(l)
        ],
      _Mode.rented => [
          for (final l in remote.value ?? <Listing>[])
            if (l.isRented) remoteCard(l),
          for (final d in rentedDraftsNotOnFirebase) draftCard(d, rented: true),
        ],
    };

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        backgroundColor: QColors.blue,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        onPressed: () => _open(null),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
          children: [
            const Text('My Listings',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            SegmentedButton<_Mode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _Mode.drafts, label: Text('Drafts')),
                ButtonSegment(value: _Mode.published, label: Text('Published')),
                ButtonSegment(value: _Mode.rented, label: Text('Rented')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 14),
            if (remote.hasError)
              Text('Could not load listings: ${remote.error}',
                  style: const TextStyle(color: Colors.red)),
            for (final c in cards) ...[c, const SizedBox(height: 12)],
          ],
        ),
      ),
    );
  }
}
