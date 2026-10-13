import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/events.dart';

/// Port of `ScheduleViewModel.swift` and `NoticeViewModel.swift`.
class ScheduleRepository {
  ScheduleRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _schedules =>
      _db.collection('schedules');
  CollectionReference<Map<String, dynamic>> get _notices =>
      _db.collection('notices');

  /// Landlord's own events (same composite index as iOS:
  /// `landlordId` + `startAt asc`).
  Stream<List<ScheduleEvent>> landlordEvents(String uid) => _schedules
      .where('landlordId', isEqualTo: uid)
      .orderBy('startAt')
      .snapshots()
      .map((s) => s.docs.map(ScheduleEvent.fromFirestore).toList());

  /// Events visible to a tenant: those targeting their listing, plus the
  /// landlord's "all properties" events. iOS also merged in every
  /// landlord's `scopeAll` events; filtering by [landlordId] fixes that.
  Stream<List<ScheduleEvent>> tenantEvents(
          {required String listingId, required String? landlordId}) =>
      _mergeById(
        _schedules.where('listingIds', arrayContains: listingId),
        _schedules.where('scopeAll', isEqualTo: true),
        ScheduleEvent.fromFirestore,
        keep: (e) => !e.scopeAll || e.landlordId == landlordId,
        idOf: (e) => e.id,
        sort: (a, b) => a.startAt.compareTo(b.startAt),
      );

  Future<void> saveEvent({
    String? id,
    required String landlordId,
    required String title,
    String? notes,
    required DateTime startAt,
    required DateTime endAt,
    required bool allDay,
    required bool scopeAll,
    required List<String> listingIds,
  }) {
    final ref = id == null ? _schedules.doc() : _schedules.doc(id);
    final event = ScheduleEvent(
      id: ref.id,
      landlordId: landlordId,
      title: title.trim(),
      notes: notes?.trim(),
      startAt: startAt,
      endAt: endAt,
      allDay: allDay,
      scopeAll: scopeAll,
      listingIds: listingIds,
      createdAt: DateTime.now(),
    );
    return ref.set(event.toFirestore());
  }

  Future<void> deleteEvent(String id) => _schedules.doc(id).delete();

  // MARK: - Notices

  Future<void> sendNotice({
    required String landlordId,
    required String title,
    required String body,
    required bool scopeAll,
    required List<String> listingIds,
  }) =>
      _notices.doc().set(NoticeEvent(
            id: '',
            landlordId: landlordId,
            title: title,
            body: body,
            scopeAll: scopeAll,
            listingIds: listingIds,
            createdAt: DateTime.now(),
          ).toFirestore());

  Stream<List<NoticeEvent>> tenantNotices(
          {required String listingId, required String? landlordId}) =>
      _mergeById(
        _notices.where('listingIds', arrayContains: listingId),
        _notices.where('scopeAll', isEqualTo: true),
        NoticeEvent.fromFirestore,
        keep: (n) => !n.scopeAll || n.landlordId == landlordId,
        idOf: (n) => n.id,
        sort: (a, b) => b.createdAt.compareTo(a.createdAt),
      );

  /// Combines two live queries into one de-duplicated, sorted list, the way
  /// the iOS view models merge their two listeners.
  Stream<List<T>> _mergeById<T>(
    Query<Map<String, dynamic>> a,
    Query<Map<String, dynamic>> b,
    T Function(DocumentSnapshot<Map<String, dynamic>>) parse, {
    required bool Function(T) keep,
    required String Function(T) idOf,
    required int Function(T, T) sort,
  }) {
    late StreamController<List<T>> controller;
    final latest = <int, List<T>>{};
    final subs = <StreamSubscription>[];

    void emit() {
      final byId = <String, T>{};
      for (final list in latest.values) {
        for (final item in list) {
          byId[idOf(item)] = item;
        }
      }
      controller.add(byId.values.where(keep).toList()..sort(sort));
    }

    controller = StreamController<List<T>>(
      onListen: () {
        for (final (i, q) in [a, b].indexed) {
          subs.add(q.snapshots().listen((s) {
            latest[i] = s.docs.map(parse).toList();
            emit();
          }, onError: controller.addError));
        }
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return controller.stream;
  }
}
