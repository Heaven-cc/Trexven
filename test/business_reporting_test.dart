import 'package:flutter_test/flutter_test.dart';
import 'package:odt/services/business_reporting.dart';

void main() {
  test('Calendar periods follow the business timezone across DST', () {
    final day = {'timezone': 'America/New_York', 'local_date': '2026-03-08'};
    final today = BusinessPeriod.fromDay(day, 'today');
    expect(today.start, DateTime.utc(2026, 3, 8, 5));
    expect(today.end, DateTime.utc(2026, 3, 9, 4));
    expect(today.end.difference(today.start).inHours, 23);
    final month = BusinessPeriod.fromDay(day, 'previous');
    expect(month.local(month.start).day, 1);
    expect(month.local(month.end).month, 3);
    expect(
      BusinessPeriod.fromDay(
        day,
        '7',
      ).local(BusinessPeriod.fromDay(day, '7').start).day,
      2,
    );
  });
  test('All buckets include zeros and exclude the exclusive end', () {
    final period = BusinessPeriod.fromDay({
      'timezone': 'Africa/Lagos',
      'local_date': '2026-10-13',
    }, 'today');
    final points = period.aggregate([
      MapEntry(DateTime.utc(2026, 10, 13, 1), 10.0),
      MapEntry(period.end, 100.0),
    ], hourly: true);
    expect(points.length, 24);
    expect(points.fold<double>(0, (sum, p) => sum + p.value), 10);
    expect(points[2].value, 10);
  });
  test('Custom range includes the complete final business day', () {
    final period = BusinessPeriod.fromDay(
      {'timezone': 'Asia/Kolkata', 'local_date': '2026-10-13'},
      'custom',
      customStart: DateTime(2026, 10, 1),
      customEnd: DateTime(2026, 10, 2),
    );
    expect(period.start, DateTime.utc(2026, 9, 30, 18, 30));
    expect(period.end, DateTime.utc(2026, 10, 2, 18, 30));
    final points = period.aggregate([
      MapEntry(period.start.add(const Duration(minutes: 45)), 3.0),
    ], hourly: true);
    expect(points.first.value, 3);
  });
}
