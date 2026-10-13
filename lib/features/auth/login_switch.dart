import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_user.dart';
import '../../providers.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import 'sign_up.dart';

/// Port of `LoginSwitch.swift` + `TenantLogin.swift` + `LandlordLogin.swift`
/// (the two login screens differed only in their copy).
class LoginSwitch extends StatefulWidget {
  const LoginSwitch({super.key});

  @override
  State<LoginSwitch> createState() => _LoginSwitchState();
}

class _LoginSwitchState extends State<LoginSwitch> {
  UserRole _role = UserRole.tenant;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QColors.background,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<UserRole>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: UserRole.tenant, label: Text('Tenant')),
                  ButtonSegment(
                      value: UserRole.landlord, label: Text('Landlord')),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _LoginForm(key: ValueKey(_role), role: _role),
            ),
          ),
        ]),
      ),
    );
  }
}

class _LoginForm extends ConsumerStatefulWidget {
  const _LoginForm({super.key, required this.role});
  final UserRole role;

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _busy = false;
  Map<String, String> _errors = {};

  bool get _isLandlord => widget.role == UserRole.landlord;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final errors = <String, String>{
      if (_email.text.isEmpty) 'email': 'Email is required',
      if (_password.text.isEmpty) 'password': 'Password is required',
    };
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).login(_email.text, _password.text);
    } catch (e) {
      if (mounted) showMessage(context, 'Login Failed', authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      showMessage(context, 'Password Reset',
          'Please enter your email address in the field above first.');
      return;
    }
    try {
      await ref.read(authServiceProvider).resetPassword(email);
      if (mounted) {
        showMessage(context, 'Password Reset',
            'A password reset link has been sent to $email.');
      }
    } catch (e) {
      if (mounted) showMessage(context, 'Password Reset', authErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: QColors.blue,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: QColors.blue.withValues(alpha: .2),
                    blurRadius: 8,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: const Icon(Icons.apartment, color: Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _isLandlord ? 'Welcome back Landlord!' : 'Welcome back Tenant!',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: QColors.ink),
        ),
        const SizedBox(height: 4),
        Text(
          _isLandlord
              ? 'Enter your details to manage your listings'
              : 'Enter your details to access your account',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: QColors.muted),
        ),
        const SizedBox(height: 24),
        const _Label('Email'),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          textCapitalization: TextCapitalization.none,
          decoration: quartierField('Enter your email'),
        ),
        FieldError(_errors['email']),
        const SizedBox(height: 16),
        const _Label('Password'),
        TextField(
          controller: _password,
          obscureText: !_showPassword,
          decoration: quartierField(
            'Enter your password',
            suffix: IconButton(
              icon: Icon(
                  _showPassword ? Icons.visibility : Icons.visibility_off,
                  color: QColors.muted),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
        ),
        FieldError(_errors['password']),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _forgotPassword,
            child: const Text('Forgot Password?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton('Log In', onPressed: _login, busy: _busy),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('New to Quartier?',
              style: TextStyle(color: QColors.muted, fontSize: 14)),
          TextButton(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SignUpScreen())),
            child: const Text('Create an account',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500, color: QColors.ink)),
      );
}
