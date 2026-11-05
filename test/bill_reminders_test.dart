import 'package:flutter_test/flutter_test.dart';
import 'package:katonagari/core/services/notification_service.dart';

void main() {
  String d(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  test('due on the 1st, 1 day before: reminded on the last day of every '
      'month, including 30-day months and February', () {
    final r = upcomingBillReminders(
      dueDay: 1, daysBefore: 1, now: DateTime(2026, 11, 5), count: 4);
    expect(r.map((e) => d(e.notify)),
        ['2026-11-30', '2026-12-31', '2027-01-31', '2027-02-28']);
    expect(r.map((e) => d(e.due)),
        ['2026-12-01', '2027-01-01', '2027-02-01', '2027-03-01']);
    expect(r.every((e) => e.notify.hour == 9), isTrue);
  });

  test('due on the 31st falls on the last day of short months', () {
    final r = upcomingBillReminders(
      dueDay: 31, daysBefore: 3, now: DateTime(2027, 1, 1), count: 4);
    expect(r.map((e) => d(e.due)),
        ['2027-01-31', '2027-02-28', '2027-03-31', '2027-04-30']);
    expect(r.map((e) => d(e.notify)),
        ['2027-01-28', '2027-02-25', '2027-03-28', '2027-04-27']);
  });

  test('skips a reminder whose time has already passed', () {
    // Due 10th, 3 days before → 7th at 09:00; it's the 7th at 10:00
    final r = upcomingBillReminders(
      dueDay: 10, daysBefore: 3, now: DateTime(2026, 11, 7, 10), count: 2);
    expect(r.map((e) => d(e.notify)), ['2026-12-07', '2027-01-07']);

    // …but at 08:00 the same morning it is still upcoming
    final early = upcomingBillReminders(
      dueDay: 10, daysBefore: 3, now: DateTime(2026, 11, 7, 8), count: 1);
    expect(d(early.single.notify), '2026-11-07');
  });

  test('leap-year February', () {
    final r = upcomingBillReminders(
      dueDay: 30, daysBefore: 1, now: DateTime(2028, 2, 1), count: 1);
    expect(d(r.single.due), '2028-02-29');
    expect(d(r.single.notify), '2028-02-28');
  });
}
