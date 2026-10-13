import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_user.dart';
import '../../providers.dart';
import '../../services/auth_service.dart';
import '../../utils/media.dart';
import '../../widgets/common.dart';

/// Port of `SignUp.swift`.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  UserRole _role = UserRole.tenant;
  Uint8List? _image;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _busy = false;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final errors = <String, String>{
      if (_name.text.isEmpty) 'fullName': 'Full name is required',
      if (_email.text.isEmpty) 'email': 'Email is required',
      if (_password.text.isEmpty) 'password': 'Password is required',
    };
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).register(
            email: _email.text,
            password: _password.text,
            role: _role,
            fullName: _name.text,
            imageData: _image,
          );
      // The auth gate swaps the whole screen once the user doc arrives.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showMessage(context, 'Sign Up Failed', authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            const SizedBox(height: 40),
            const Text('Create Account',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827))),
            const SizedBox(height: 24),
            SegmentedButton<UserRole>(
              showSelectedIcon: false,
              segments: [
                for (final r in UserRole.values)
                  ButtonSegment(value: r, label: Text(r.label)),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
            const SizedBox(height: 24),
            Center(
              child: GestureDetector(
                onTap: () async {
                  final img = await pickImage();
                  if (img != null) setState(() => _image = img);
                },
                child: _image != null
                    ? ClipOval(
                        child: Image.memory(_image!,
                            width: 120, height: 120, fit: BoxFit.cover))
                    : const Icon(Icons.account_circle,
                        size: 120, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Full Name', style: _labelStyle),
            const SizedBox(height: 6),
            TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: quartierField('Enter your full name')),
            FieldError(_errors['fullName']),
            const SizedBox(height: 20),
            const Text('Email Address', style: _labelStyle),
            const SizedBox(height: 6),
            TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: quartierField('name@example.com')),
            FieldError(_errors['email']),
            const SizedBox(height: 20),
            const Text('Password', style: _labelStyle),
            const SizedBox(height: 6),
            TextField(
              controller: _password,
              obscureText: !_showPassword,
              decoration: quartierField(
                'Min. 8 characters',
                suffix: IconButton(
                  icon: Icon(
                      _showPassword ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
              ),
            ),
            FieldError(_errors['password']),
            const SizedBox(height: 32),
            PrimaryButton('Sign Up',
                onPressed: _signUp, busy: _busy, height: 56),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Already have an account?',
                  style: TextStyle(color: Color(0xFF4B5563), fontSize: 14)),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Log In',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

const _labelStyle = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF374151));
