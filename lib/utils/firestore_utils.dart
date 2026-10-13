import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

/// Helpers for reading loosely-typed Firestore data the same way the
/// Swift app does (`data["x"] as? Double ?? 0`, etc.).

const _uuid = Uuid();

/// Swift's `UUID().uuidString` is uppercase, and the iOS app compares
/// listing ids as uppercase strings. Every id we create must match.
String newUuid() => _uuid.v4().toUpperCase();

/// Normalises a document id the way Swift's `UUID(uuidString:)?.uuidString`
/// does, so lowercase ids written by other clients still compare equal.
String normalizeUuid(String id) =>
    RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id) ? id.toUpperCase() : id;

String readString(Object? v, [String fallback = '']) =>
    v is String ? v : fallback;

String? readOptString(Object? v) => v is String ? v : null;

double readDouble(Object? v, [double fallback = 0]) =>
    v is num ? v.toDouble() : fallback;

int readInt(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

bool readBool(Object? v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  return fallback;
}

List<String> readStringList(Object? v) =>
    v is List ? v.whereType<String>().toList() : <String>[];

DateTime? readOptDate(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

DateTime readDate(Object? v, [DateTime? fallback]) =>
    readOptDate(v) ?? fallback ?? DateTime.now();
