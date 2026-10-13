import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/app_user.dart';
import 'models/chat.dart';
import 'models/events.dart';
import 'models/listing.dart';
import 'models/profile.dart';
import 'services/auth_service.dart';
import 'services/chat_repository.dart';
import 'services/draft_store.dart';
import 'services/listing_repository.dart';
import 'services/schedule_repository.dart';
import 'services/user_repository.dart';

// MARK: - Infrastructure

/// Overridden in `main.dart` once SharedPreferences has loaded.
final sharedPrefsProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError());

final _db = Provider((ref) => FirebaseFirestore.instance);
final _storage = Provider((ref) => FirebaseStorage.instance);

final userRepoProvider =
    Provider((ref) => UserRepository(ref.watch(_db), ref.watch(_storage)));
final listingRepoProvider =
    Provider((ref) => ListingRepository(ref.watch(_db), ref.watch(_storage)));
final chatRepoProvider = Provider((ref) => ChatRepository(ref.watch(_db)));
final scheduleRepoProvider =
    Provider((ref) => ScheduleRepository(ref.watch(_db)));
final authServiceProvider = Provider(
    (ref) => AuthService(FirebaseAuth.instance, ref.watch(userRepoProvider)));
final draftStoreProvider = Provider((ref) => DraftStore());

// MARK: - Session

final authStateProvider = StreamProvider<User?>(
    (ref) => ref.watch(authServiceProvider).authStateChanges());

final currentUidProvider =
    Provider<String?>((ref) => ref.watch(authStateProvider).value?.uid);

/// Live `users/{uid}` document. Same rule as `AuthService.swift`: if the
/// server says the document is gone, sign out.
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(userRepoProvider).userDocStream(uid).map((snap) {
    if (!snap.exists) {
      if (!snap.metadata.isFromCache && !AuthService.isRegistering) {
        ref.read(authServiceProvider).signOut();
      }
      return null;
    }
    return AppUser.fromFirestore(snap);
  });
});

bool _isLandlord(Ref ref) =>
    ref.watch(currentUserProvider).value?.role == UserRole.landlord;

// MARK: - Listings

final landlordListingsProvider = StreamProvider<List<Listing>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.watch(listingRepoProvider).landlordListings(uid);
});

final availableListingsProvider = StreamProvider<List<Listing>>(
    (ref) => ref.watch(listingRepoProvider).availableListings());

final listingProvider = StreamProvider.autoDispose.family<Listing?, String>(
    (ref, id) => ref.watch(listingRepoProvider).listingStream(id));

final publicLandlordListingsProvider =
    StreamProvider.autoDispose.family<List<Listing>, String>((ref, uid) =>
        ref.watch(listingRepoProvider).publicLandlordListings(uid));

/// The listing the signed-in tenant rents, live.
final rentedListingProvider = StreamProvider<Listing?>((ref) {
  final id = ref.watch(currentUserProvider).value?.rentedListingId;
  if (id == null) return Stream.value(null);
  return ref.watch(listingRepoProvider).listingStream(id);
});

final userProfileProvider = FutureProvider.autoDispose
    .family<AppUser?, String>(
        (ref, uid) => ref.watch(userRepoProvider).fetchUser(uid));

final tenantsProvider = FutureProvider.autoDispose<List<TenantItem>>(
    (ref) => ref.watch(userRepoProvider).fetchAllTenants());

// MARK: - Drafts (local)

class DraftsNotifier extends AsyncNotifier<List<Listing>> {
  @override
  Future<List<Listing>> build() async {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) return [];
    return ref.watch(draftStoreProvider).loadDrafts(uid);
  }

  Future<void> save(Listing l) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    await ref.read(draftStoreProvider).saveDraft(uid, l);
    ref.invalidateSelf();
  }

  Future<void> delete(String listingId) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    await ref.read(draftStoreProvider).deleteDraft(uid, listingId);
    ref.invalidateSelf();
  }
}

final draftsProvider =
    AsyncNotifierProvider<DraftsNotifier, List<Listing>>(DraftsNotifier.new);

// MARK: - Favorites & preferences

final favoriteIdsProvider = StreamProvider<Set<String>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value({});
  return ref.watch(listingRepoProvider).favoriteIds(uid);
});

final savedListingsProvider = FutureProvider<List<Listing>>((ref) async {
  final ids = await ref.watch(favoriteIdsProvider.future);
  if (ids.isEmpty) return [];
  return ref.watch(listingRepoProvider).listingsByIds(ids.toList());
});

final preferencesProvider = StreamProvider<Preferences?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(userRepoProvider).preferencesStream(uid);
});

/// "Clear Filters" on the tenant home screen. iOS deleted the local Core
/// Data copy (restored on next sync); here it's session state.
class FiltersCleared extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(preferencesProvider);
    return false;
  }

  void clear() => state = true;
}

final filtersClearedProvider =
    NotifierProvider<FiltersCleared, bool>(FiltersCleared.new);

final documentsProvider = StreamProvider<List<UserDocument>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.watch(userRepoProvider).documentsStream(uid);
});

// MARK: - Chat

final conversationsProvider = StreamProvider<List<Conversation>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);
  return ref
      .watch(chatRepoProvider)
      .conversations(uid, isLandlord: _isLandlord(ref));
});

final totalUnreadProvider = Provider<int>((ref) {
  final landlord = _isLandlord(ref);
  return (ref.watch(conversationsProvider).value ?? []).fold(
      0,
      (total, c) =>
          total + (landlord ? c.landlordUnreadCount : c.tenantUnreadCount));
});

final messagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>(
        (ref, id) => ref.watch(chatRepoProvider).messages(id));

// MARK: - Schedules, notices, maintenance

final landlordEventsProvider = StreamProvider<List<ScheduleEvent>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.watch(scheduleRepoProvider).landlordEvents(uid);
});

final tenantEventsProvider = StreamProvider<List<ScheduleEvent>>((ref) {
  final listingId = ref.watch(currentUserProvider).value?.rentedListingId;
  if (listingId == null) return Stream.value([]);
  final landlordId = ref.watch(rentedListingProvider).value?.landLordId;
  return ref
      .watch(scheduleRepoProvider)
      .tenantEvents(listingId: listingId, landlordId: landlordId);
});

final tenantNoticesProvider = StreamProvider<List<NoticeEvent>>((ref) {
  final listingId = ref.watch(currentUserProvider).value?.rentedListingId;
  if (listingId == null) return Stream.value([]);
  final landlordId = ref.watch(rentedListingProvider).value?.landLordId;
  return ref
      .watch(scheduleRepoProvider)
      .tenantNotices(listingId: listingId, landlordId: landlordId);
});

/// `lastViewedSchedule` in UserDefaults on iOS.
class ScheduleLastViewed extends Notifier<DateTime> {
  static const _key = 'lastViewedSchedule';

  @override
  DateTime build() {
    final ms = ref.watch(sharedPrefsProvider).getInt(_key);
    return ms == null
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  void markViewed() {
    final now = DateTime.now();
    ref.read(sharedPrefsProvider).setInt(_key, now.millisecondsSinceEpoch);
    state = now;
  }
}

final scheduleLastViewedProvider =
    NotifierProvider<ScheduleLastViewed, DateTime>(ScheduleLastViewed.new);

final scheduleHasUnreadProvider = Provider<bool>((ref) {
  final lastViewed = ref.watch(scheduleLastViewedProvider);
  return (ref.watch(tenantEventsProvider).value ?? [])
      .any((e) => (e.createdAt ?? e.startAt).isAfter(lastViewed));
});

final maintenanceRequestsProvider = StreamProvider.autoDispose
    .family<List<MaintenanceRequest>, String>((ref, listingId) =>
        ref.watch(listingRepoProvider).maintenanceRequests(listingId));

final latestMaintenanceProvider =
    FutureProvider.autoDispose<MaintenanceRequest?>((ref) async {
  final listings = await ref.watch(landlordListingsProvider.future);
  if (listings.isEmpty) return null;
  return ref
      .watch(listingRepoProvider)
      .latestMaintenance(listings.map((l) => l.listingId).toList());
});
