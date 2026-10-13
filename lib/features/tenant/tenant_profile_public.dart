import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/profile.dart';
import '../../providers.dart';
import '../../utils/media.dart';
import '../../widgets/common.dart';

final _tenantDocsProvider = FutureProvider.autoDispose
    .family<List<UserDocument>, String>(
        (ref, uid) => ref.watch(userRepoProvider).fetchDocuments(uid));

/// Port of `TenantProfilePublicView.swift` (what a landlord sees).
class TenantProfilePublicScreen extends ConsumerWidget {
  const TenantProfilePublicScreen({super.key, required this.tenantId});
  final String tenantId;

  static String _titleFor(String type) => switch (type.toLowerCase()) {
        'id' => 'Government ID',
        'paystub' => 'Recent Paystubs',
        'tax' => 'Tax Returns (W2)',
        _ => type.isEmpty ? type : type[0].toUpperCase() + type.substring(1),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(userProfileProvider(tenantId));
    final docs = ref.watch(_tenantDocsProvider(tenantId));
    final count = docs.value?.length ?? 0;
    final verified = count >= 3;
    final name = tenant.isLoading
        ? 'Loading...'
        : tenant.hasError
            ? 'Unknown Tenant'
            : tenant.value?.displayName ?? 'Tenant';

    return Scaffold(
      appBar: AppBar(title: const Text('Tenant Profile'), centerTitle: true),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        QCard(
          child: Column(children: [
            Stack(children: [
              Avatar(url: tenant.value?.profilePic, size: 92),
              if (verified)
                const Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                    radius: 11,
                    backgroundColor: Colors.green,
                    child: Icon(Icons.check, size: 12, color: Colors.white),
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            Text(name,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(tenant.value?.email ?? '',
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 10),
            verified
                ? const Pill('Verified Tenant', color: Colors.green)
                : const Pill('Pending Verification', color: Colors.orange),
          ]),
        ),
        const SizedBox(height: 14),
        QCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionTitle('Uploaded Documents',
                trailing: Text('$count/3',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: QColors.blue))),
            docs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e', style: const TextStyle(color: Colors.red)),
              data: (list) => list.isEmpty
                  ? const Text("This tenant hasn't uploaded any documents yet.",
                      style: TextStyle(color: Colors.black54))
                  : Column(children: [
                      for (final d in list)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                                color: QColors.blue.withValues(alpha: .1),
                                borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.description,
                                color: QColors.blue),
                          ),
                          title: Text(_titleFor(d.type),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Tap to view',
                              style:
                                  TextStyle(fontSize: 11, color: QColors.blue)),
                          trailing: const Icon(Icons.open_in_new,
                              color: QColors.blue),
                          onTap: () => openUrl(d.url),
                        ),
                    ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
