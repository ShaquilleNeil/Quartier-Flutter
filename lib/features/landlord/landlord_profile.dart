import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/profile.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../listings/apartment_card.dart';
import '../listings/apartment_detail.dart';
import '../shared/profile_widgets.dart';

/// Port of `LandlordProfile.swift`. With [publicId] it is the public view a
/// tenant sees (header + published listings); without it, the landlord's own
/// profile (edit, verification documents, log out).
class LandlordProfile extends ConsumerWidget {
  const LandlordProfile({super.key, this.publicId});
  final String? publicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPublic = publicId != null;
    final me = ref.watch(currentUserProvider).value;
    final user = isPublic ? ref.watch(userProfileProvider(publicId!)).value : me;
    final docs = isPublic ? null : ref.watch(documentsProvider).value;
    final completed = docs
            ?.where((d) => DocumentType.values.any((t) => t.name == d.type))
            .length ??
        0;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), centerTitle: true),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ProfileHeader(
          email: user?.email ??
              (isPublic ? '' : ref.watch(authStateProvider).value?.email ?? ''),
          profileUrl: user?.profilePic,
          name: user?.name ?? (isPublic ? 'Landlord' : 'User'),
          completedCount: completed,
        ),
        const SizedBox(height: 24),
        if (!isPublic) ...[
          PrimaryButton('Edit Profile',
              color: Colors.blue,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ProfileEditScreen()))),
          const SizedBox(height: 24),
          const DocumentsSection(title: 'Verification Documents', rows: [
            ('Government ID', DocumentType.id),
            ('Proof of Ownership', DocumentType.tax),
            ('Insurance Certificate', DocumentType.paystub),
          ]),
          const SizedBox(height: 8),
          PrimaryButton('Log Out',
              color: Colors.red,
              onPressed: () => ref.read(authServiceProvider).signOut()),
        ] else
          _PublicListings(landlordId: publicId!),
      ]),
    );
  }
}

class _PublicListings extends ConsumerWidget {
  const _PublicListings({required this.landlordId});
  final String landlordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings =
        ref.watch(publicLandlordListingsProvider(landlordId)).value ?? [];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Listings',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      const SizedBox(height: 16),
      if (listings.isEmpty)
        const Text('No listings available.',
            style: TextStyle(color: Colors.black54)),
      for (final l in listings) ...[
        ListingRowCard(
          listing: l,
          statusLabel: 'Published',
          statusColor: statusColor('published'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ApartmentDetailScreen(listing: l))),
        ),
        const SizedBox(height: 12),
      ],
    ]);
  }
}
