import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/profile.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../shared/profile_widgets.dart';
import 'tenant_preferences.dart';

/// Port of `TenantProfile.swift`.
class TenantProfile extends ConsumerWidget {
  const TenantProfile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final docs = ref.watch(documentsProvider).value ?? [];
    final completed = DocumentType.values
        .where((t) => docs.any((d) => d.type == t.name))
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), centerTitle: true),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ProfileHeader(
          email: ref.watch(authStateProvider).value?.email ?? 'Tenant User',
          profileUrl: user?.profilePic,
          name: user?.name ?? 'User',
          completedCount: completed,
        ),
        const SizedBox(height: 24),
        PrimaryButton('Edit Profile',
            color: Colors.blue,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ProfileEditScreen()))),
        const SizedBox(height: 24),
        QCard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => const TenantPreferencesScreen())),
          child: Row(children: [
            const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Housing Preferences',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600)),
                    SizedBox(height: 6),
                    Text('Edit your budget, location, and needs',
                        style: TextStyle(color: Colors.black54)),
                  ]),
            ),
            CircleAvatar(
              backgroundColor: Colors.blue.withValues(alpha: .1),
              child: const Icon(Icons.tune, color: Colors.blue),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        const DocumentsSection(title: 'My Documents', rows: [
          ('Government ID', DocumentType.id),
          ('Recent Paystubs', DocumentType.paystub),
          ('Tax Returns (W2)', DocumentType.tax),
        ]),
        const SizedBox(height: 8),
        PrimaryButton('Log Out',
            color: Colors.red,
            onPressed: () => ref.read(authServiceProvider).signOut()),
      ]),
    );
  }
}
