import 'package:flutter_test/flutter_test.dart';
import 'package:quartier/utils/format.dart';

void main() {
  test('dollars2 always shows two decimals and grouping', () {
    expect(dollars2(1850), r'$1,850.00');
    expect(dollars2(0.5), r'$0.50');
  });

  test('cad rounds to whole dollars by default', () {
    expect(cad(1850.4), contains('1,850'));
    expect(cad(1850.4), isNot(contains('.')));
  });

  test('relativeTime says Yesterday for the previous day', () {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    expect(relativeTime(yesterday), 'Yesterday');
  });

  test('monthYear', () {
    expect(monthYear(DateTime(2026, 10, 13)), 'October 2026');
  });

  test('isSameDay ignores the time of day', () {
    expect(isSameDay(DateTime(2026, 10, 13, 1), DateTime(2026, 10, 13, 23)),
        isTrue);
    expect(isSameDay(DateTime(2026, 10, 13), DateTime(2026, 10, 14)), isFalse);
  });
}
