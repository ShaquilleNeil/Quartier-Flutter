import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quartier/models/listing.dart';
import 'package:quartier/utils/firestore_utils.dart';

void main() {
  group('uuid', () {
    test('newUuid is uppercase to match Swift UUID().uuidString', () {
      final id = newUuid();
      expect(id, id.toUpperCase());
      expect(id, hasLength(36));
    });

    test('normalizeUuid uppercases valid uuids only', () {
      expect(normalizeUuid('3f2b8c1e-0000-4abc-9def-123456789abc'),
          '3F2B8C1E-0000-4ABC-9DEF-123456789ABC');
      expect(normalizeUuid('someDocId'), 'someDocId');
    });
  });

  group('readers', () {
    test('readString / readOptString', () {
      expect(readString('a'), 'a');
      expect(readString(3), '');
      expect(readString(null, 'x'), 'x');
      expect(readOptString(3), isNull);
    });

    test('readDouble and readInt accept any num', () {
      expect(readDouble(2), 2.0);
      expect(readDouble('2'), 0);
      expect(readInt(2.9), 2);
      expect(readInt(null, 5), 5);
    });

    test('readBool accepts bools and numbers', () {
      expect(readBool(true), isTrue);
      expect(readBool(1), isTrue);
      expect(readBool(0), isFalse);
      expect(readBool('true'), isFalse);
    });

    test('readStringList drops non-strings', () {
      expect(readStringList(['a', 1, 'b', null]), ['a', 'b']);
      expect(readStringList('a'), isEmpty);
    });

    test('readOptDate handles Timestamp and DateTime', () {
      final d = DateTime(2026, 10, 13, 9, 30);
      expect(readOptDate(Timestamp.fromDate(d)), d);
      expect(readOptDate(d), d);
      expect(readOptDate('2026-10-13'), isNull);
      expect(readDate(null, d), d);
    });
  });

  test('ListingStatus.parse is case-insensitive and defaults to draft', () {
    expect(ListingStatus.parse('Published'), ListingStatus.published);
    expect(ListingStatus.parse('draft'), ListingStatus.draft);
    expect(ListingStatus.parse(null), ListingStatus.draft);
  });
}
