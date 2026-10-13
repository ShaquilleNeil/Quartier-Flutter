import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../models/app_user.dart';
import '../../models/listing.dart';
import '../../providers.dart';
import '../../utils/media.dart';
import '../../widgets/common.dart';

const _allAmenities = [
  'Air Conditioning',
  'WiFi',
  'Parking',
  'Pet Friendly',
  'Laundry',
];

/// Port of `ListingFormView.swift` + `ListingFormViewModel.swift`.
class ListingFormScreen extends ConsumerStatefulWidget {
  const ListingFormScreen({super.key, this.existing});
  final Listing? existing;

  @override
  ConsumerState<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends ConsumerState<ListingFormScreen> {
  late final Listing _l = widget.existing?.copy() ?? Listing();
  late final String _originalAddress = _l.address;
  bool get _isEditing => widget.existing != null;

  late final _name = TextEditingController(text: _l.listingName);
  late final _price = TextEditingController(
      text: _l.price == 0 ? '' : _l.price.toStringAsFixed(0));
  late final _address = TextEditingController(text: _l.address);
  late final _sqft = TextEditingController(
      text: _l.squareFeet == 0 ? '' : '${_l.squareFeet}');
  late final _rules = TextEditingController(text: _l.rules);

  List<TenantItem> _tenants = [];
  TenantItem? _selectedTenant;
  String _originalTenantId = '';
  String? _leaseFileName;
  bool _uploadingLease = false;
  bool _publishing = false;
  Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    _originalTenantId = _l.tenantId;
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(listingRepoProvider);
    final tenants = await ref.read(userRepoProvider).fetchAllTenants();
    final lease = _isEditing ? await repo.fetchLeaseFileName(_l.listingId) : null;
    if (!mounted) return;
    setState(() {
      _tenants = tenants;
      _leaseFileName = lease;
      if (_l.tenantId.isNotEmpty) {
        _selectedTenant =
            tenants.where((t) => t.id == _l.tenantId).firstOrNull;
      }
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _price, _address, _sqft, _rules]) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncFields() {
    _l
      ..listingName = _name.text
      ..price = double.tryParse(_price.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0
      ..address = _address.text
      ..squareFeet = int.tryParse(_sqft.text) ?? 0
      ..rules = _rules.text
      ..tenantId = _selectedTenant?.id ?? '';
  }

  bool _validate() {
    _syncFields();
    final e = <String, String>{
      if (_l.listingName.isEmpty) 'name': 'Name is required',
      if (_l.address.isEmpty) 'address': 'Address is required',
      if (_l.price == 0) 'price': 'Price must be greater than 0',
      if (_l.bedrooms <= 0) 'bedrooms': 'Must have at least 1 bedroom',
      if (_l.squareFeet == 0)
        'squareFeet': 'Square footage must be greater than 0',
      if (_l.bathrooms <= 0) 'bathrooms': 'Must have at least 1 bathroom',
      if (_selectedTenant != null && _leaseFileName == null)
        'lease': 'A lease must be attached when a tenant is assigned',
    };
    setState(() => _errors = e);
    return e.isEmpty;
  }

  Future<void> _saveDraft() async {
    _syncFields();
    _l
      ..status = ListingStatus.draft
      ..landLordId = ref.read(currentUidProvider) ?? '';
    await ref.read(draftsProvider.notifier).save(_l);
    if (mounted) {
      showMessage(context, 'Draft Saved', '',
          onOk: () => Navigator.pop(context));
    }
  }

  Future<void> _publish() async {
    if (!_validate()) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      showMessage(context, 'Publish Failed', 'User not authenticated.');
      return;
    }
    final wasDraft = _l.status == ListingStatus.draft;
    _l
      ..landLordId = uid
      ..status = ListingStatus.published;

    setState(() => _publishing = true);
    try {
      // Geocode new listings, and (unlike iOS) re-geocode if the address
      // changed so the map pin follows it.
      if (_l.latitude == null || _l.address != _originalAddress) {
        final c = await geocode(_l.address);
        _l
          ..latitude = c.lat
          ..longitude = c.lng;
      }

      final repo = ref.read(listingRepoProvider);
      final newUrls =
          await repo.uploadListingImages(_l.listingId, _l.newImages);
      final urls = [..._l.existingImageUrls, ...newUrls];
      await repo.saveListing(_l, imageUrls: urls);

      final newTenant = _l.tenantId;
      final id = _l.listingId;
      if (_originalTenantId.isEmpty && newTenant.isNotEmpty) {
        await repo.assignTenant(id, newTenant);
      } else if (_originalTenantId.isNotEmpty && newTenant.isEmpty) {
        await repo.removeTenant(id, _originalTenantId);
      } else if (_originalTenantId != newTenant) {
        await repo.removeTenant(id, _originalTenantId);
        await repo.assignTenant(id, newTenant);
      }

      if (wasDraft) {
        await ref.read(draftsProvider.notifier).delete(id);
      }
      _l
        ..existingImageUrls = urls
        ..newImages = [];
      _originalTenantId = newTenant;

      if (mounted) {
        showMessage(context, 'Listing Published', '',
            onOk: () => Navigator.pop(context));
      }
    } catch (e) {
      if (mounted) showMessage(context, 'Publish Failed', '$e');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _attachLease() async {
    final uid = ref.read(currentUidProvider);
    final file = await pickDocument();
    if (uid == null || file == null) return;
    setState(() => _uploadingLease = true);
    try {
      await ref.read(listingRepoProvider).uploadLease(
          landlordId: uid, listingId: _l.listingId, file: file);
      setState(() => _leaseFileName = p.basename(file.path));
    } catch (e) {
      if (mounted) showSnack(context, 'Lease upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploadingLease = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Listing' : 'New Listing')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: () async {
              final imgs = await pickImages();
              setState(() => _l.newImages.addAll(imgs));
            },
            child: const Text('Select Photos'),
          ),
        ),
        const SizedBox(height: 12),
        _imageRow(),
        const SizedBox(height: 20),
        _card(TextField(
          controller: _name,
          decoration:
              const InputDecoration(hintText: 'Name', border: InputBorder.none),
        )),
        FieldError(_errors['name']),
        const SizedBox(height: 20),
        _card(TextField(
          controller: _price,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
              hintText: 'Monthly Price',
              prefixText: 'CA\$ ',
              border: InputBorder.none),
        )),
        FieldError(_errors['price']),
        const SizedBox(height: 20),
        _card(TextField(
          controller: _address,
          decoration: const InputDecoration(
              hintText: 'Address', border: InputBorder.none),
        )),
        FieldError(_errors['address']),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
              child: _Stepper('Bedrooms', _l.bedrooms,
                  (v) => setState(() => _l.bedrooms = v))),
          const SizedBox(width: 8),
          Expanded(
              child: _Stepper('Bathrooms', _l.bathrooms,
                  (v) => setState(() => _l.bathrooms = v))),
        ]),
        FieldError(_errors['bathrooms'] ?? _errors['bedrooms']),
        const SizedBox(height: 20),
        _card(Row(children: [
          const Text('Square Feet'),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _sqft,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(hintText: '0', border: InputBorder.none),
            ),
          ),
        ])),
        FieldError(_errors['squareFeet']),
        const SizedBox(height: 20),
        const Text('Amenities',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        for (final a in _allAmenities) ...[
          _card(
            InkWell(
              onTap: () => setState(() => _l.amenities.contains(a)
                  ? _l.amenities.remove(a)
                  : _l.amenities.add(a)),
              child: Row(children: [
                Expanded(child: Text(a)),
                Icon(
                    _l.amenities.contains(a)
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: _l.amenities.contains(a) ? Colors.blue : Colors.grey),
              ]),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        _tenantSection(),
        const SizedBox(height: 20),
        const Text('Rules',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _card(TextField(
          controller: _rules,
          minLines: 5,
          maxLines: 8,
          decoration: const InputDecoration(border: InputBorder.none),
        )),
        const SizedBox(height: 20),
        Row(children: [
          TextButton(onPressed: _saveDraft, child: const Text('Save as Draft')),
          const Spacer(),
          FilledButton(
            onPressed: _publishing ? null : _publish,
            child: _publishing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_isEditing && _l.status == ListingStatus.published
                    ? 'Update'
                    : 'Publish'),
          ),
        ]),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        constraints: const BoxConstraints(minHeight: 52),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: child,
      );

  /// Existing URLs then new picks; tapping one makes it the cover photo.
  Widget _imageRow() {
    final tiles = <Widget>[
      for (final (i, url) in _l.existingImageUrls.indexed)
        GestureDetector(
          onTap: () => setState(() => _l.existingImageUrls
              .insert(0, _l.existingImageUrls.removeAt(i))),
          onLongPress: () =>
              setState(() => _l.existingImageUrls.removeAt(i)),
          child: NetImage(url, width: 110, height: 110),
        ),
      for (final (i, bytes) in _l.newImages.indexed)
        GestureDetector(
          onTap: () => setState(
              () => _l.newImages.insert(0, _l.newImages.removeAt(i))),
          onLongPress: () => setState(() => _l.newImages.removeAt(i)),
          child: Image.memory(bytes, width: 110, height: 110, fit: BoxFit.cover),
        ),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tiles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) =>
            ClipRRect(borderRadius: BorderRadius.circular(12), child: tiles[i]),
      ),
    );
  }

  Widget _tenantSection() {
    final tenant = _selectedTenant;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Center(child: Text('Assign To a Tenant')),
      const SizedBox(height: 12),
      if (tenant == null)
        Autocomplete<TenantItem>(
          displayStringForOption: (t) => t.email,
          optionsBuilder: (v) => v.text.isEmpty
              ? const <TenantItem>[]
              : _tenants
                  .where((t) => t.email.contains(v.text.toLowerCase()))
                  .take(8),
          onSelected: (t) => setState(() => _selectedTenant = t),
          fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
            controller: controller,
            focusNode: focus,
            decoration: InputDecoration(
              hintText: 'Search Tenants...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
          ),
        )
      else ...[
        Center(
          child: InputChip(
            label: Text(tenant.email),
            onDeleted: () => setState(() => _selectedTenant = null),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.event_repeat, color: Colors.blue),
            const SizedBox(width: 8),
            const Expanded(child: Text('Rent Due on Day:')),
            DropdownButton<int>(
              value: _l.rentDueDay.clamp(1, 31),
              underline: const SizedBox.shrink(),
              items: [
                for (var d = 1; d <= 31; d++)
                  DropdownMenuItem(value: d, child: Text('$d')),
              ],
              onChanged: (d) => setState(() => _l.rentDueDay = d ?? 1),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Center(
          child: _leaseFileName != null
              ? InputChip(
                  avatar: const Icon(Icons.description, color: Colors.blue),
                  label: Text(_leaseFileName!, overflow: TextOverflow.ellipsis),
                  onDeleted: () => setState(() => _leaseFileName = null),
                )
              : TextButton(
                  onPressed: _uploadingLease ? null : _attachLease,
                  child: Text(_uploadingLease ? 'Uploading…' : 'Attach Lease'),
                ),
        ),
        Center(child: FieldError(_errors['lease'])),
      ],
    ]);
  }
}

/// Port of `StepperCard.swift`.
class _Stepper extends StatelessWidget {
  const _Stepper(this.title, this.value, this.onChanged);
  final String title;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Text(title),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: value > 0 ? () => onChanged(value - 1) : null),
            SizedBox(
              width: 40,
              child: Text('$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => onChanged(value + 1)),
          ]),
        ]),
      );
}
