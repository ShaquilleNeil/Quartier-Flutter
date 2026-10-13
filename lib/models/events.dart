import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_utils.dart';

/// Mirrors `ScheduleEvent` in `ScheduleViewModel.swift`.
/// Firestore document: `schedules/{eventId}`.
class ScheduleEvent {
  const ScheduleEvent({
    required this.id,
    required this.landlordId,
    required this.title,
    required this.notes,
    required this.startAt,
    required this.endAt,
    required this.allDay,
    required this.scopeAll,
    required this.listingIds,
    required this.createdAt,
  });

  final String id;
  final String landlordId;
  final String title;
  final String? notes;
  final DateTime startAt;
  final DateTime endAt;
  final bool allDay;
  final bool scopeAll;
  final List<String> listingIds;
  final DateTime? createdAt;

  factory ScheduleEvent.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return ScheduleEvent(
      id: doc.id,
      landlordId: readString(d['landlordId']),
      title: readString(d['title']),
      notes: readOptString(d['notes']),
      startAt: readDate(d['startAt']),
      endAt: readDate(d['endAt']),
      allDay: readBool(d['allDay']),
      scopeAll: readBool(d['scopeAll']),
      listingIds: readStringList(d['listingIds']),
      createdAt: readOptDate(d['createdAt']),
    );
  }

  /// Written with client dates (as Swift's `setData(from:)` does), so every
  /// Date field is a Timestamp the iOS `Codable` decoder accepts.
  Map<String, dynamic> toFirestore() => {
        'landlordId': landlordId,
        'title': title,
        'notes': notes,
        'startAt': Timestamp.fromDate(startAt),
        'endAt': Timestamp.fromDate(endAt),
        'allDay': allDay,
        'scopeAll': scopeAll,
        'listingIds': listingIds,
        'createdAt':
            createdAt == null ? null : Timestamp.fromDate(createdAt!),
      };
}

/// Mirrors `NoticeEvent` in `NoticeViewModel.swift`.
/// Firestore document: `notices/{noticeId}`.
class NoticeEvent {
  const NoticeEvent({
    required this.id,
    required this.landlordId,
    required this.title,
    required this.body,
    required this.scopeAll,
    required this.listingIds,
    required this.createdAt,
  });

  final String id;
  final String landlordId;
  final String title;
  final String body;
  final bool scopeAll;
  final List<String> listingIds;
  final DateTime createdAt;

  factory NoticeEvent.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return NoticeEvent(
      id: doc.id,
      landlordId: readString(d['landlordId']),
      title: readString(d['title']),
      body: readString(d['body']),
      scopeAll: readBool(d['scopeAll']),
      listingIds: readStringList(d['listingIds']),
      createdAt: readDate(d['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'landlordId': landlordId,
        'title': title,
        'body': body,
        'scopeAll': scopeAll,
        'listingIds': listingIds,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

enum MaintenanceStatus {
  pending,
  resolved;

  static MaintenanceStatus parse(Object? raw) =>
      raw == 'resolved' ? MaintenanceStatus.resolved : MaintenanceStatus.pending;
}

/// Mirrors `MaintenanceRequest.swift`.
/// Firestore document: `listings/{listingId}/maintenanceRequests/{requestId}`.
class MaintenanceRequest {
  const MaintenanceRequest({
    required this.id,
    required this.listingId,
    required this.tenantId,
    required this.description,
    required this.date,
    this.status = MaintenanceStatus.pending,
    this.photoUrls = const [],
  });

  final String id;
  final String listingId;
  final String tenantId;
  final String description;
  final DateTime date;
  final MaintenanceStatus status;
  final List<String> photoUrls;

  /// Returns null for documents missing required fields, as the iOS parser does.
  static MaintenanceRequest? fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc, String listingId) {
    final d = doc.data() ?? const {};
    final tenantId = readOptString(d['tenantId']);
    final description = readOptString(d['description']);
    final date = readOptDate(d['date']);
    if (tenantId == null || description == null || date == null) return null;
    return MaintenanceRequest(
      id: doc.id,
      listingId: listingId,
      tenantId: tenantId,
      description: description,
      date: date,
      status: MaintenanceStatus.parse(d['status']),
      photoUrls: readStringList(d['photoURLs']),
    );
  }
}
