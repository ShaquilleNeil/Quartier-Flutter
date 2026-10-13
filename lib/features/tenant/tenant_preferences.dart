import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/profile.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

/// Port of `TenantPreferencesView.swift`. Shown full-screen as onboarding
/// when `hasCompletedPreferences` is false, and as a sheet from Home/Profile.
class TenantPreferencesScreen extends ConsumerStatefulWidget {
  const TenantPreferencesScreen({super.key, this.isOnboarding = false});
  final bool isOnboarding;

  @override
  ConsumerState<TenantPreferencesScreen> createState() =>
      _TenantPreferencesScreenState();
}

class _TenantPreferencesScreenState
    extends ConsumerState<TenantPreferencesScreen> {
  final _location = TextEditingController();
  double _min = 1000;
  double _max = 3000;
  String _bedroom = 'Studio';
  bool _pets = false;
  bool _furnished = false;
  bool _parking = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(preferencesProvider).value;
    if (saved != null) {
      _location.text = saved.locationQuery;
      _min = saved.budgetMin.clamp(500, 5000);
      _max = saved.budgetMax.clamp(500, 5000);
      _bedroom = Preferences.bedroomOptions.contains(saved.selectedBedroom)
          ? saved.selectedBedroom
          : 'Studio';
      _pets = saved.petsAllowed;
      _furnished = saved.fullyFurnished;
      _parking = saved.parkingIncluded;
    }
  }

  @override
  void dispose() {
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(userRepoProvider).savePreferences(
            uid,
            Preferences(
              locationQuery: _location.text,
              budgetMin: _min,
              budgetMax: _max,
              selectedBedroom: _bedroom,
              petsAllowed: _pets,
              fullyFurnished: _furnished,
              parkingIncluded: _parking,
            ),
          );
      // During onboarding the auth gate swaps this screen out once
      // `hasCompletedPreferences` flips.
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save preferences: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QColors.background,
      appBar: AppBar(
        backgroundColor: QColors.background,
        title: const Text('Preferences',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: !widget.isOnboarding,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          if (widget.isOnboarding) ...[
            const Text('Find your perfect home',
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: QColors.ink)),
            const SizedBox(height: 8),
            const Text(
                'Set your preferences so we can curate the best listings for you.',
                style: TextStyle(fontSize: 16, color: Color(0xFF64748B))),
            const SizedBox(height: 32),
          ],
          const _Heading('Desired Location'),
          _Box(
            child: TextField(
              controller: _location,
              decoration: const InputDecoration(
                hintText: 'Search neighborhoods (e.g. Laval)',
                prefixIcon: Icon(Icons.place, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(children: [
            const _Heading('Budget Range'),
            const Spacer(),
            Text('\$${_min.toInt()} - \$${_max.toInt()}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: QColors.blue)),
          ]),
          _Box(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Minimum: \$${_min.toInt()}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Slider(
                    value: _min,
                    min: 500,
                    max: 5000,
                    divisions: 90,
                    onChanged: (v) => setState(() {
                      _min = v;
                      if (v > _max) _max = v;
                    }),
                  ),
                  const SizedBox(height: 12),
                  Text('Maximum: \$${_max.toInt()}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Slider(
                    value: _max,
                    min: 500,
                    max: 5000,
                    divisions: 90,
                    onChanged: (v) => setState(() {
                      _max = v;
                      if (v < _min) _min = v;
                    }),
                  ),
                ]),
          ),
          const SizedBox(height: 32),
          const _Heading('Bedrooms'),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              for (final o in Preferences.bedroomOptions)
                ButtonSegment(value: o, label: Text(o)),
            ],
            selected: {_bedroom},
            onSelectionChanged: (s) => setState(() => _bedroom = s.first),
          ),
          const SizedBox(height: 32),
          const _Heading('Key Features'),
          _Box(
            child: Column(children: [
              _ToggleRow(Icons.pets, Colors.orange, 'Pets Allowed', _pets,
                  (v) => setState(() => _pets = v)),
              const Divider(indent: 64, height: 1),
              _ToggleRow(Icons.chair, Colors.blue, 'Fully Furnished',
                  _furnished, (v) => setState(() => _furnished = v)),
              const Divider(indent: 64, height: 1),
              _ToggleRow(Icons.directions_car, Colors.grey, 'Parking Included',
                  _parking, (v) => setState(() => _parking = v)),
            ]),
          ),
        ],
      ),
      bottomSheet: Container(
        color: Colors.white.withValues(alpha: .9),
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          top: false,
          child: PrimaryButton('Save & Continue',
              onPressed: _save, busy: _saving, height: 56),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      );
}

class _Box extends StatelessWidget {
  const _Box({required this.child, this.padding = EdgeInsets.zero});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: .05),
                blurRadius: 2,
                offset: const Offset(0, 1)),
          ],
        ),
        child: child,
      );
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow(this.icon, this.color, this.title, this.value, this.onChanged);
  final IconData icon;
  final Color color;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withValues(alpha: .1),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: QColors.ink)),
          ),
          Switch(value: value, onChanged: onChanged),
        ]),
      );
}
