import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class BusinessPeriod {
  static bool _initialized = false;
  final tz.Location location;
  final DateTime start, end;
  BusinessPeriod(this.location, this.start, this.end);
  factory BusinessPeriod.fromDay(
    Map day,
    String period, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    if (!_initialized) {
      tzdata.initializeTimeZones();
      _initialized = true;
    }
    final location = tz.getLocation(day['timezone'] as String);
    final date = DateTime.parse(day['local_date'] as String);
    tz.TZDateTime at(int year, int month, int day) =>
        tz.TZDateTime(location, year, month, day);
    var start = at(date.year, date.month, date.day);
    var end = at(date.year, date.month, date.day + 1);
    switch (period) {
      case 'yesterday':
        start = at(date.year, date.month, date.day - 1);
        end = at(date.year, date.month, date.day);
      case '7':
        start = at(date.year, date.month, date.day - 6);
      case '30':
        start = at(date.year, date.month, date.day - 29);
      case 'month':
        start = at(date.year, date.month, 1);
      case 'previous':
        start = at(date.year, date.month - 1, 1);
        end = at(date.year, date.month, 1);
      case 'custom':
        if (customStart == null ||
            customEnd == null ||
            customEnd.isBefore(customStart)) {
          throw ArgumentError('Choose a valid custom date range.');
        }
        start = at(customStart.year, customStart.month, customStart.day);
        end = at(customEnd.year, customEnd.month, customEnd.day + 1);
    }
    return BusinessPeriod(location, start.toUtc(), end.toUtc());
  }
  DateTime local(DateTime instant) => tz.TZDateTime.from(instant, location);
  List<MapEntry<DateTime, double>> aggregate(
    Iterable<MapEntry<DateTime, double>> rows, {
    required bool hourly,
  }) {
    final buckets = <DateTime, double>{};
    for (var cursor = start; cursor.isBefore(end);) {
      buckets[cursor] = 0;
      final date = local(cursor);
      cursor = hourly
          ? cursor.add(const Duration(hours: 1))
          : tz.TZDateTime(
              location,
              date.year,
              date.month,
              date.day + 1,
            ).toUtc();
    }
    for (final row in rows) {
      if (row.key.isBefore(start) || !row.key.isBefore(end)) continue;
      final date = local(row.key);
      final key = hourly
          ? row.key.toUtc().subtract(
              Duration(
                minutes: date.minute,
                seconds: date.second,
                milliseconds: date.millisecond,
                microseconds: date.microsecond,
              ),
            )
          : tz.TZDateTime(location, date.year, date.month, date.day).toUtc();
      if (buckets.containsKey(key)) buckets[key] = buckets[key]! + row.value;
    }
    return buckets.entries.map((e) => MapEntry(local(e.key), e.value)).toList();
  }
}

double financialNumber(dynamic value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;

class FinanceReport {
  final BusinessPeriod period;
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> sales, expenses;
  final String currency;
  FinanceReport(this.period, this.summary, this.sales, this.expenses, {this.currency = 'NGN'});
  double get expenseTotal =>
      expenses.fold(0, (sum, e) => sum + financialNumber(e['amount']));
}
