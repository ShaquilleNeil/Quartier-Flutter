import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/events.dart';
import '../../models/listing.dart';
import '../../providers.dart';
import '../../utils/format.dart';
import '../../utils/media.dart';
import '../../widgets/common.dart';
import '../shared/maintenance.dart';
import 'tenant_messages.dart';

/// Port of `TenantRentedDash.swift`.
class TenantRentedDash extends ConsumerWidget {
  const TenantRentedDash({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final listing = ref.watch(rentedListingProvider).value;
    final events = ref.watch(tenantEventsProvider).value ?? [];
    final notices = ref.watch(tenantNoticesProvider).value ?? [];
    final conversations = ref.watch(conversationsProvider).value ?? [];

    final now = DateTime.now();
    final upcoming = events.where((e) => !e.endAt.isBefore(now)).firstOrNull;
    final title = (listing?.address.isNotEmpty ?? false)
        ? listing!.address
        : (user?.rentedAddress ?? 'Your rental');
    final subtitle = (listing?.listingName.isNotEmpty ?? false)
        ? 'Building ${listing!.listingName}'
        : 'Quartier tenant';

    void push(Widget w) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    return Scaffold(
      backgroundColor: QColors.grouped,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            const Icon(Icons.account_circle, size: 48, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('QUARTIER',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(title,
                        maxLines: 2,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600)),
                    Text(subtitle,
                        maxLines: 1,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                  ]),
            ),
            const Icon(Icons.notifications),
          ]),
          const SizedBox(height: 20),
          _RentStatusCard(
              listing: listing, address: listing?.address ?? title),
          const SizedBox(height: 20),
          _QuickActions(listingId: user?.rentedListingId ?? ''),
          const SizedBox(height: 20),
          const SectionTitle('Upcoming Event'),
          upcoming == null
              ? const EmptyCard('No upcoming events scheduled.')
              : NavCard(
                  icon: Icons.calendar_today,
                  iconColor: Colors.orange,
                  title: upcoming.title,
                  subtitle: formatEventTime(upcoming),
                  onTap: () => push(const TenantScheduleScreen()),
                ),
          const SizedBox(height: 20),
          const SectionTitle('Messages'),
          NavCard(
            icon: Icons.message,
            iconColor: Colors.blue,
            circle: true,
            title: 'Pending Messages',
            subtitle: conversations.isEmpty
                ? 'No new messages'
                : 'You have ${conversations.length} active chats',
            onTap: () => push(const TenantMessages()),
          ),
          const SizedBox(height: 28),
          const Text('Announcements',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (notices.isEmpty)
            const Text('No new announcements.',
                style: TextStyle(color: Colors.grey))
          else
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: notices.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _NoticeCard(notices[i]),
              ),
            ),
        ]),
      ),
    );
  }
}

class _RentStatusCard extends ConsumerStatefulWidget {
  const _RentStatusCard({required this.listing, required this.address});
  final Listing? listing;
  final String address;

  @override
  ConsumerState<_RentStatusCard> createState() => _RentStatusCardState();
}

class _RentStatusCardState extends ConsumerState<_RentStatusCard> {
  /// Same UserDefaults key as iOS: `rent_paid_<listingId>_<MMMM yyyy>`.
  String get _paymentKey =>
      'rent_paid_${widget.listing?.listingId ?? 'unknown'}_${monthYear(DateTime.now())}';

  bool get _paid => ref.read(sharedPrefsProvider).getBool(_paymentKey) ?? false;

  int get _dueDay {
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    return min(widget.listing?.rentDueDay ?? 1, daysInMonth);
  }

  int get _daysUntilDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var due = DateTime(now.year, now.month, _dueDay);
    if (now.day > _dueDay) due = DateTime(now.year, now.month + 1, _dueDay);
    return due.difference(today).inDays;
  }

  String get _nextDue {
    final now = DateTime.now();
    final roll = _paid || now.day > _dueDay;
    return DateFormat('MMM d')
        .format(DateTime(now.year, now.month + (roll ? 1 : 0), _dueDay));
  }

  @override
  Widget build(BuildContext context) {
    final price = widget.listing?.price ?? 0;
    final paid = _paid;
    final days = _daysUntilDue;
    final month = DateFormat('MMMM').format(DateTime.now());

    return Card(
      color: Colors.white,
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        NetImage(widget.listing?.existingImageUrls.firstOrNull,
            height: 180, width: double.infinity),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Rent Status',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600)),
                      Text(monthYear(DateTime.now()),
                          style: const TextStyle(color: Colors.grey)),
                    ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(price > 0 ? cad(price, decimals: 2) : '—',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
                const Text('Monthly rent',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: Text(widget.address,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.black54)),
              ),
              if (paid)
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('Paid for $month',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green)),
                  Text('Next due: $_nextDue',
                      style:
                          const TextStyle(fontSize: 11, color: Colors.black54)),
                ])
              else if (days == 0)
                const Text('Due Today!',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red))
              else
                Text('Due in $days days',
                    style: TextStyle(
                        fontSize: 12,
                        color: days <= 5 ? Colors.red : Colors.orange)),
            ]),
            const SizedBox(height: 12),
            PrimaryButton(
              paid ? 'Paid' : 'Pay Now',
              color: paid ? Colors.green : Colors.red,
              onPressed: paid
                  ? null
                  : () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (_) => _PayRentSheet(
                          amount: price,
                          onPaid: () {
                            ref
                                .read(sharedPrefsProvider)
                                .setBool(_paymentKey, true);
                            setState(() {});
                          },
                        ),
                      ),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Port of `PayRentView`. Like the iOS version this is a mock: it records
/// the payment on-device only and charges nothing.
class _PayRentSheet extends StatefulWidget {
  const _PayRentSheet({required this.amount, required this.onPaid});
  final double amount;
  final VoidCallback onPaid;

  @override
  State<_PayRentSheet> createState() => _PayRentSheetState();
}

class _PayRentSheetState extends State<_PayRentSheet> {
  final _fields = List.generate(4, (_) => TextEditingController());
  bool _processing = false;

  bool get _valid => _fields.every((c) => c.text.isNotEmpty);

  @override
  void initState() {
    super.initState();
    for (final c in _fields) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in _fields) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pay() async {
    setState(() => _processing = true);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    widget.onPaid();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final amount = cad(widget.amount, decimals: 2);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          TextButton(
              onPressed: _processing ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          const Expanded(
            child: Text('Pay Rent',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 72),
        ]),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const Text('Amount Due', style: TextStyle(color: Colors.black54)),
            Text(amount,
                style:
                    const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
                controller: _fields[0],
                decoration: const InputDecoration(labelText: 'Name on Card')),
            TextField(
                controller: _fields[1],
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Card Number')),
            Row(children: [
              Expanded(
                child: TextField(
                    controller: _fields[2],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'MM/YY')),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                    controller: _fields[3],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'CVV')),
              ),
            ]),
            const SizedBox(height: 24),
            PrimaryButton('Pay $amount',
                onPressed: _valid ? _pay : null, busy: _processing),
          ]),
        ),
      ]),
    );
  }
}

class _QuickActions extends ConsumerStatefulWidget {
  const _QuickActions({required this.listingId});
  final String listingId;

  @override
  ConsumerState<_QuickActions> createState() => _QuickActionsState();
}

class _QuickActionsState extends ConsumerState<_QuickActions> {
  bool _loadingLease = false;

  Future<void> _openLease() async {
    setState(() => _loadingLease = true);
    String? url;
    try {
      url = await ref.read(listingRepoProvider).fetchLeaseUrl(widget.listingId);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loadingLease = false);
    if (url == null) {
      showMessage(context, 'No Lease Found',
          "Your landlord hasn't uploaded a lease yet.");
    } else {
      await openUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = ref.watch(scheduleHasUnreadProvider);
    void push(Widget w) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('QUICK ACTIONS',
          style: TextStyle(fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
        children: [
          _ActionCard(
              _loadingLease ? 'Loading...' : 'Lease',
              _loadingLease ? Icons.hourglass_empty : Icons.description,
              _loadingLease ? null : _openLease),
          _ActionCard('Maintenance', Icons.build,
              () => push(const MaintenanceFormScreen())),
          _ActionCard('Upcoming', Icons.calendar_today,
              () => push(const TenantScheduleScreen()),
              dot: hasUnread),
        ],
      ),
    ]);
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard(this.title, this.icon, this.onTap, {this.dot = false});
  final String title;
  final IconData icon;
  final VoidCallback? onTap;
  final bool dot;

  @override
  Widget build(BuildContext context) => QCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        child: Stack(children: [
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFE5E5EA),
                child: Icon(icon, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
            ]),
          ),
          if (dot)
            const Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(radius: 7, backgroundColor: Colors.red),
            ),
        ]),
      );
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard(this.notice);
  final NoticeEvent notice;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 260,
        child: QCard(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ANNOUNCEMENT',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(notice.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(notice.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54)),
              ]),
        ),
      );
}

/// Port of `TenantSchedule.swift`.
class TenantScheduleScreen extends ConsumerStatefulWidget {
  const TenantScheduleScreen({super.key});

  @override
  ConsumerState<TenantScheduleScreen> createState() =>
      _TenantScheduleScreenState();
}

class _TenantScheduleScreenState extends ConsumerState<TenantScheduleScreen> {
  DateTime _selected = DateTime.now();

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(scheduleLastViewedProvider.notifier).markViewed());
  }

  @override
  Widget build(BuildContext context) {
    final events = (ref.watch(tenantEventsProvider).value ?? [])
        .where((e) => isSameDay(e.startAt, _selected))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        centerTitle: false,
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        QCard(
          padding: EdgeInsets.zero,
          child: CalendarDatePicker(
            initialDate: _selected,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            onDateChanged: (d) => setState(() => _selected = d),
          ),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Appointments'),
        if (events.isEmpty)
          const Text('No events scheduled for this day.',
              style: TextStyle(color: Colors.black54)),
        for (final e in events) ...[
          QCard(
            child: SizedBox(
              width: double.infinity,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(formatEventTime(e),
                        style: const TextStyle(color: Colors.blue)),
                    if (e.notes?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 8),
                      Text(e.notes!,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                    ],
                  ]),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ]),
    );
  }
}
