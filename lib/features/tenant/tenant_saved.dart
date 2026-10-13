import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../widgets/common.dart';
import '../listings/apartment_card.dart';

/// Port of `TenantSaved.swift`. Firestore's offline cache replaces the
/// `TFavoriteListing` Core Data fallback.
class TenantSaved extends ConsumerWidget {
  const TenantSaved({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: asyncBody(ref.watch(savedListingsProvider), (listings) {
          if (listings.isEmpty) {
            return const Center(
              child: Text('No saved listings yet.',
                  style: TextStyle(color: Colors.black54)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(32),
            itemCount: listings.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (_, i) => ApartmentCard(listing: listings[i]),
          );
        }),
      ),
    );
  }
}
