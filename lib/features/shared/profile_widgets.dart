import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/profile.dart';
import '../../providers.dart';
import '../../utils/media.dart';
import '../../widgets/common.dart';

/// Port of `ProfileHeaderView` (in `TenantProfile.swift`).
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.email,
    required this.profileUrl,
    required this.name,
    required this.completedCount,
  });

  final String email;
  final String? profileUrl;
  final String name;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    final verified = completedCount >= 3;
    return Column(children: [
      Stack(children: [
        Avatar(url: profileUrl, size: 120, color: Colors.grey),
        Positioned(
          right: 0,
          bottom: 0,
          child: CircleAvatar(
            radius: 16,
            backgroundColor: verified ? Colors.green : Colors.red,
            child: Icon(verified ? Icons.verified : Icons.gpp_bad,
                color: Colors.white, size: 16),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      Text(name,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      Text(email, style: const TextStyle(color: Colors.black54)),
      const Text('Verified Tenant • Member since 2026',
          style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(verified ? Icons.check_circle : Icons.cancel,
              size: 16, color: verified ? Colors.green : Colors.red),
          const SizedBox(width: 6),
          Text(verified ? 'ID Verified' : 'Not Verified',
              style: const TextStyle(fontSize: 12, color: Colors.blue)),
        ]),
      ),
    ]);
  }
}

/// Port of the private `DocumentRow` used on both profile screens.
class DocumentRow extends StatelessWidget {
  const DocumentRow(
      {super.key,
      required this.title,
      required this.uploaded,
      required this.onTap});

  final String title;
  final bool uploaded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = uploaded ? Colors.green : Colors.red;
    return QCard(
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.description),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            Text(uploaded ? 'Uploaded' : 'Not yet uploaded',
                style: TextStyle(color: color)),
          ]),
        ),
        CircleAvatar(
          radius: 12,
          backgroundColor: color,
          child: Icon(uploaded ? Icons.check : Icons.close,
              size: 14, color: Colors.white),
        ),
      ]),
    );
  }
}

/// The verification documents list + upload / replace / delete flow shared
/// by `TenantProfile` and `LandlordProfile`.
class DocumentsSection extends ConsumerWidget {
  const DocumentsSection(
      {super.key, required this.title, required this.rows});

  final String title;

  /// (label, type) pairs in display order.
  final List<(String, DocumentType)> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(documentsProvider).value ?? [];
    bool uploaded(DocumentType t) => docs.any((d) => d.type == t.name);
    final completed = DocumentType.values.where(uploaded).length;

    Future<void> upload(DocumentType type) async {
      final uid = ref.read(currentUidProvider);
      final file = await pickDocument();
      if (uid == null || file == null) return;
      try {
        await ref.read(userRepoProvider).uploadDocument(uid, file, type);
      } catch (e) {
        if (context.mounted) showSnack(context, 'Upload failed: $e');
      }
    }

    Future<void> onTap(DocumentType type) async {
      if (!uploaded(type)) return upload(type);
      final doc = docs.firstWhere((d) => d.type == type.name);
      final action = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const ListTile(title: Text('Document Options')),
            ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('View'),
                onTap: () => Navigator.pop(ctx, 'view')),
            ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('Replace'),
                onTap: () => Navigator.pop(ctx, 'replace')),
            ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(ctx, 'delete')),
          ]),
        ),
      );
      final uid = ref.read(currentUidProvider);
      switch (action) {
        case 'view':
          await openUrl(doc.url);
        case 'replace':
          await upload(type);
        case 'delete' when uid != null:
          await ref.read(userRepoProvider).deleteDocument(uid, type);
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text('$completed/3 Completed',
            style: const TextStyle(color: Colors.blue)),
      ]),
      const SizedBox(height: 16),
      for (final (label, type) in rows) ...[
        DocumentRow(
            title: label, uploaded: uploaded(type), onTap: () => onTap(type)),
        const SizedBox(height: 16),
      ],
    ]);
  }
}

/// Port of `ProfileEditView.swift`.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final _name = TextEditingController(
      text: ref.read(currentUserProvider).value?.name ?? '');
  Uint8List? _image;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      setState(() => _error = 'Could not find signed-in user.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(userRepoProvider)
          .saveProfile(uid: uid, name: _name.text.trim(), imageData: _image);
      if (mounted) {
        await showMessage(context, 'Profile Updated',
            'Your profile has been updated.',
            onOk: () => Navigator.pop(context));
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final canSave = _name.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Edit Profile',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Update your name and profile photo',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 24),
        Center(
          child: GestureDetector(
            onTap: () async {
              final img = await pickImage();
              if (img != null) setState(() => _image = img);
            },
            child: Stack(children: [
              _image != null
                  ? ClipOval(
                      child: Image.memory(_image!,
                          width: 120, height: 120, fit: BoxFit.cover))
                  : Avatar(url: user?.profilePic, size: 120, color: Colors.grey),
              const Positioned(
                right: 0,
                bottom: 0,
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.camera_alt, color: Colors.white, size: 16),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        const Text('Tap photo to change',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 24),
        QCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Profile Details',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            const Text('Full Name', style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              decoration: InputDecoration(
                hintText: 'Enter your name',
                filled: true,
                fillColor: const Color(0xFFF2F2F7),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Email', style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(14)),
              child: Text(ref.watch(authStateProvider).value?.email ??
                  'No email'),
            ),
          ]),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 24),
        PrimaryButton('Save Changes',
            onPressed: canSave ? _save : null, busy: _saving),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.black54))),
      ]),
    );
  }
}
