import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/events.dart';
import '../../providers.dart';
import '../../utils/firestore_utils.dart';
import '../../utils/media.dart';
import '../../widgets/common.dart';

/// Port of `MaintenanceCard`.
class MaintenanceCard extends StatelessWidget {
  const MaintenanceCard({super.key, required this.request, this.onTap});
  final MaintenanceRequest request;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pending = request.status == MaintenanceStatus.pending;
    final color = pending ? Colors.orange : Colors.green;
    return QCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(pending ? Icons.build : Icons.check_circle, color: color),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(request.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(DateFormat.yMMMd().format(request.date),
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ]),
        ),
        StatusBadge(request.status),
      ]),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final MaintenanceStatus status;

  @override
  Widget build(BuildContext context) => Pill(
      status == MaintenanceStatus.pending ? 'Pending' : 'Resolved',
      color: status == MaintenanceStatus.pending ? Colors.orange : Colors.green);
}

/// Port of `MaintenanceListView` (landlord).
class MaintenanceListScreen extends ConsumerStatefulWidget {
  const MaintenanceListScreen({super.key, required this.listingId});
  final String listingId;

  @override
  ConsumerState<MaintenanceListScreen> createState() =>
      _MaintenanceListScreenState();
}

class _MaintenanceListScreenState extends ConsumerState<MaintenanceListScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance')),
      body: asyncBody(ref.watch(maintenanceRequestsProvider(widget.listingId)),
          (requests) {
        final filtered = _search.isEmpty
            ? requests
            : requests
                .where((r) => r.description
                    .toLowerCase()
                    .contains(_search.toLowerCase()))
                .toList();
        return ListView(padding: const EdgeInsets.all(16), children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search requests',
              prefixIcon: Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderSide: BorderSide.none),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 12),
          if (requests.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Text('No maintenance requests yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54)),
            ),
          for (final r in filtered) ...[
            MaintenanceCard(
              request: r,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MaintenanceDetailScreen(request: r))),
            ),
            const SizedBox(height: 12),
          ],
        ]);
      }),
    );
  }
}

/// Port of `MaintenanceDetailView`.
class MaintenanceDetailScreen extends ConsumerStatefulWidget {
  const MaintenanceDetailScreen({super.key, required this.request});
  final MaintenanceRequest request;

  @override
  ConsumerState<MaintenanceDetailScreen> createState() =>
      _MaintenanceDetailScreenState();
}

class _MaintenanceDetailScreenState
    extends ConsumerState<MaintenanceDetailScreen> {
  bool _resolving = false;
  String? _error;

  MaintenanceRequest get r => widget.request;

  Future<void> _resolve() async {
    setState(() => _resolving = true);
    try {
      await ref.read(listingRepoProvider).resolveMaintenance(r.listingId, r.id);
      ref.invalidate(latestMaintenanceProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = '$e';
        _resolving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Detail')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          StatusBadge(r.status),
          const Spacer(),
          Text(DateFormat.yMMMMd().add_jm().format(r.date),
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
        const SizedBox(height: 20),
        QCard(
          child: SizedBox(
            width: double.infinity,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Description',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(r.description),
                ]),
          ),
        ),
        if (r.photoUrls.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Photos',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: r.photoUrls.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: NetImage(r.photoUrls[i], width: 140, height: 140),
              ),
            ),
          ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        if (r.status == MaintenanceStatus.pending) ...[
          const SizedBox(height: 20),
          PrimaryButton(_resolving ? 'Resolving...' : 'Mark as Resolved',
              color: Colors.green, onPressed: _resolve, busy: _resolving),
        ],
      ]),
    );
  }
}

/// Port of `MaintenanceForm.swift` (tenant).
class MaintenanceFormScreen extends ConsumerStatefulWidget {
  const MaintenanceFormScreen({super.key});

  @override
  ConsumerState<MaintenanceFormScreen> createState() =>
      _MaintenanceFormScreenState();
}

class _MaintenanceFormScreenState extends ConsumerState<MaintenanceFormScreen> {
  DateTime _date = DateTime.now();
  final _description = TextEditingController();
  final List<Uint8List> _photos = [];
  bool _submitting = false;
  String? _error;
  String? _fieldError;

  @override
  void initState() {
    super.initState();
    _description.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_description.text.isEmpty) {
      setState(() => _fieldError = 'Please enter a description.');
      return;
    }
    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      setState(() => _error = 'Could not load user.');
      return;
    }
    final listingId = user.rentedListingId;
    if (listingId == null) {
      setState(() => _error = 'No listing found for your account.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
      _fieldError = null;
    });
    try {
      await ref.read(listingRepoProvider).submitMaintenance(
            MaintenanceRequest(
              id: newUuid(),
              listingId: listingId,
              tenantId: user.id,
              description: _description.text,
              date: _date,
            ),
            _photos,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance Request Form')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        QCard(
          child: Column(children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              trailing: Text(DateFormat.yMMMd().format(_date)),
              onTap: () async {
                final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100));
                if (d != null) setState(() => _date = d);
              },
            ),
            const Divider(),
            TextField(
              controller: _description,
              maxLines: null,
              decoration: const InputDecoration(
                  hintText: 'Description', border: InputBorder.none),
            ),
            FieldError(_fieldError),
            const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () async {
                  final imgs = await pickImages();
                  setState(() => _photos.addAll(imgs));
                },
                child: const Text('Add Photos'),
              ),
            ),
            if (_photos.isNotEmpty)
              SizedBox(
                height: 80,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final p in _photos)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, top: 8),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(p,
                              width: 72, height: 72, fit: BoxFit.cover)),
                    ),
                ]),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child:
                    Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 12),
            PrimaryButton(_submitting ? 'Submitting...' : 'Submit',
                onPressed: _description.text.isEmpty ? null : _submit,
                busy: _submitting),
          ]),
        ),
      ]),
    );
  }
}
