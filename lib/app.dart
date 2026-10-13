import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/login_switch.dart';
import 'features/landlord/landlord_home.dart';
import 'features/landlord/landlord_listings.dart';
import 'features/landlord/landlord_messages.dart';
import 'features/landlord/landlord_profile.dart';
import 'features/landlord/landlord_schedule.dart';
import 'features/tenant/tenant_discover.dart';
import 'features/tenant/tenant_home.dart';
import 'features/tenant/tenant_messages.dart';
import 'features/tenant/tenant_preferences.dart';
import 'features/tenant/tenant_profile.dart';
import 'features/tenant/tenant_rented_dash.dart';
import 'features/tenant/tenant_saved.dart';
import 'models/app_user.dart';
import 'providers.dart';
import 'widgets/common.dart';

class QuartierApp extends StatelessWidget {
  const QuartierApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quartier',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: QColors.blue, primary: QColors.blue),
        scaffoldBackgroundColor: QColors.grouped,
        appBarTheme: const AppBarTheme(
            backgroundColor: QColors.grouped, surfaceTintColor: Colors.transparent),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

/// Port of `ContentView.swift`: logged out → login; tenant → preferences
/// setup or tenant tabs; landlord → landlord tabs.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    if (auth.isLoading) return const _Loading();
    if (auth.value == null) return const LoginSwitch();

    final user = ref.watch(currentUserProvider).value;
    return switch (user?.role) {
      UserRole.tenant when !user!.hasCompletedPreferences =>
        const TenantPreferencesScreen(isOnboarding: true),
      UserRole.tenant => const TenantTabs(),
      UserRole.landlord => const LandlordTabs(),
      null => const _Loading(),
    };
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading...', style: TextStyle(color: Colors.grey)),
          ]),
        ),
      );
}

/// Bottom tab bar where each tab keeps its own navigation stack, like a
/// SwiftUI `TabView` whose tabs each contain a `NavigationStack`.
class _TabShell extends ConsumerStatefulWidget {
  const _TabShell({super.key, required this.tabs});
  final List<_Tab> tabs;

  @override
  ConsumerState<_TabShell> createState() => _TabShellState();
}

class _Tab {
  const _Tab(this.label, this.icon, this.builder, {this.badge = false});
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
  final bool badge;
}

class _TabShellState extends ConsumerState<_TabShell> {
  int _index = 0;
  late final _keys = List.generate(
      widget.tabs.length, (_) => GlobalKey<NavigatorState>());

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(totalUnreadProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        final nav = _keys[_index].currentState;
        if (nav != null && nav.canPop()) nav.pop();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            for (final (i, tab) in widget.tabs.indexed)
              Navigator(
                key: _keys[i],
                onGenerateRoute: (_) =>
                    MaterialPageRoute(builder: tab.builder),
              ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) {
            if (i == _index) {
              _keys[i].currentState?.popUntil((r) => r.isFirst);
            }
            setState(() => _index = i);
          },
          destinations: [
            for (final tab in widget.tabs)
              NavigationDestination(
                label: tab.label,
                icon: Badge(
                  isLabelVisible: tab.badge && unread > 0,
                  label: Text('$unread'),
                  child: Icon(tab.icon),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// `LandlordTabView.swift`.
class LandlordTabs extends StatelessWidget {
  const LandlordTabs({super.key});

  @override
  Widget build(BuildContext context) => _TabShell(tabs: [
        _Tab('Home', Icons.home, (_) => const LandlordHome()),
        _Tab('Listings', Icons.assignment, (_) => const LandlordListings()),
        _Tab('Scheduler', Icons.calendar_month, (_) => const LandlordSchedule()),
        _Tab('Messages', Icons.message, (_) => const LandlordMessages(),
            badge: true),
        _Tab('Profile', Icons.person, (_) => const LandlordProfile()),
      ]);
}

/// `TenantTabView.swift`. Home shows the rented dashboard once the tenant
/// is assigned a listing.
class TenantTabs extends ConsumerWidget {
  const TenantTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRenting = ref.watch(currentUserProvider).value?.isRenting ?? false;
    return _TabShell(
      key: ValueKey(isRenting),
      tabs: [
        _Tab('Home', Icons.home,
            (_) => isRenting ? const TenantRentedDash() : const TenantHome()),
        _Tab('Discover', Icons.search, (_) => const TenantDiscover()),
        _Tab('Saved', Icons.bookmark, (_) => const TenantSaved()),
        _Tab('Messages', Icons.message, (_) => const TenantMessages(),
            badge: true),
        _Tab('Profile', Icons.person, (_) => const TenantProfile()),
      ],
    );
  }
}
