import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../shared/maintenance.dart';
import 'landlord_messages.dart';
import 'landlord_schedule.dart';
import 'new_notice.dart';

/// Port of `LandlordHome.swift` (`LandlordDashboardView`).
class LandlordHome extends ConsumerWidget {
  const LandlordHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final listings = ref.watch(landlordListingsProvider).value ?? [];
    final conversations = ref.watch(conversationsProvider).value ?? [];
    final events = ref.watch(landlordEventsProvider).value ?? [];
    final latest = ref.watch(latestMaintenanceProvider);

    final occupied = listings.where((l) => l.isRented).length;
    // Same totals as `totalRentCollected` / `totalPossibleEarnings`.
    final totalRent = listings
        .where((l) => l.isRented)
        .fold<double>(0, (s, l) => s + l.price);
    final totalPossible = listings.fold<double>(0, (s, l) => s + l.price);
    final percent = totalPossible > 0 ? totalRent / totalPossible * 100 : 0.0;

    final now = DateTime.now();
    final upcoming = events.where((e) => !e.endAt.isBefore(now)).firstOrNull;
    final firstName = (user?.name ?? '').split(' ').first;

    void push(Widget w) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
          children: [
            Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hey ${firstName.isEmpty ? 'there' : firstName}!',
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold)),
                      const Text('Here is your property overview.',
                          style: TextStyle(color: Colors.black54)),
                    ]),
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.notification_add),
                tooltip: 'Send notice',
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => const NewNoticeSheet(),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                  child: _StatCard('Properties', '${listings.length}',
                      Icons.apartment, QColors.blue)),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                      'Occupied', '$occupied', Icons.people, Colors.green)),
            ]),
            const SizedBox(height: 20),
            QCard(
              child: Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Earnings',
                            style: TextStyle(color: Colors.black54)),
                        const SizedBox(height: 4),
                        Text(
                            'CA${cad(totalRent)} / ${cad(totalPossible)}',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold)),
                      ]),
                ),
                Pill('${percent.toStringAsFixed(1)}%',
                    color: percent < 50 ? Colors.red : Colors.green),
              ]),
            ),
            const SizedBox(height: 20),
            const SectionTitle('Messages'),
            NavCard(
              icon: Icons.forum,
              iconColor: QColors.blue,
              circle: true,
              title: 'Active Conversations',
              subtitle: conversations.isEmpty
                  ? 'No pending messages'
                  : 'You have ${conversations.length} active chats',
              onTap: () => push(const LandlordMessages()),
            ),
            const SizedBox(height: 20),
            const SectionTitle('Upcoming Event'),
            upcoming == null
                ? const EmptyCard('No upcoming events scheduled.')
                : NavCard(
                    icon: Icons.calendar_today,
                    iconColor: Colors.orange,
                    title: upcoming.title,
                    subtitle: formatEventTime(upcoming),
                    onTap: () => push(const LandlordSchedule()),
                  ),
            const SizedBox(height: 20),
            SectionTitle(
              'Maintenance',
              trailing: latest.value == null
                  ? null
                  : TextButton(
                      onPressed: () => push(MaintenanceListScreen(
                          listingId: latest.value!.listingId)),
                      child: const Text('View All'),
                    ),
            ),
            latest.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyCard('Could not load requests: $e'),
              data: (r) => r == null
                  ? const EmptyCard('No maintenance requests.')
                  : MaintenanceCard(
                      request: r,
                      onTap: () =>
                          push(MaintenanceDetailScreen(request: r)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.title, this.value, this.icon, this.color);
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => QCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(value,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54)),
        ]),
      );
}
