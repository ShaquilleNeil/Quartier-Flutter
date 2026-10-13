import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../widgets/common.dart';
import '../listings/apartment_card.dart';
import 'tenant_preferences.dart';

/// Port of `TenantHome.swift`: searchable feed of available listings,
/// filtered by the tenant's saved preferences.
class TenantHome extends ConsumerStatefulWidget {
  const TenantHome({super.key});

  @override
  ConsumerState<TenantHome> createState() => _TenantHomeState();
}

class _TenantHomeState extends ConsumerState<TenantHome> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listings = ref.watch(availableListingsProvider);
    final prefs = ref.watch(preferencesProvider).value;
    final cleared = ref.watch(filtersClearedProvider);
    final activePrefs = cleared ? null : prefs;
    final query = _search.text.toLowerCase();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  textCapitalization: TextCapitalization.words,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: 'Search neighborhoods...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.grey),
                            onPressed: _search.clear),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                style: IconButton.styleFrom(
                    backgroundColor: Colors.blue,
                    fixedSize: const Size(44, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                icon: const Icon(Icons.tune),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => const TenantPreferencesScreen())),
              ),
            ]),
            if (activePrefs != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(children: [
                  const Text('Preferences Applied',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue)),
                  const Spacer(),
                  TextButton(
                    onPressed: () =>
                        ref.read(filtersClearedProvider.notifier).clear(),
                    child: const Text('Clear Filters',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red)),
                  ),
                ]),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: asyncBody(listings, (all) {
                final filtered = all.where((l) {
                  if (query.isNotEmpty &&
                      !l.address.toLowerCase().contains(query)) {
                    return false;
                  }
                  return activePrefs == null ||
                      activePrefs.matches(price: l.price, bedrooms: l.bedrooms);
                }).toList();
                if (filtered.isEmpty) {
                  return const Center(
                      child: Text('No listings match.',
                          style: TextStyle(color: Colors.black54)));
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (_, i) => ApartmentCard(listing: filtered[i]),
                );
              }),
            ),
          ]),
        ),
      ),
    );
  }
}
