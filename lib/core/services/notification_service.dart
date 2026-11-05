import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../utils/currency_formatter.dart';
import 'preferences_service.dart';


// ─────────────────────────────────────────────────────────
//  Bill Reminder model  (stored as JSON in SharedPreferences)
// ─────────────────────────────────────────────────────────
class BillReminder {
  final String id;
  final String name;
  final String icon;
  final double amount;
  final int    dueDay;     // 1–31, day of month
  final int    daysBefore; // notify this many days before (1, 3, or 7)
  final bool   isActive;

  const BillReminder({
    required this.id,
    required this.name,
    required this.icon,
    required this.amount,
    required this.dueDay,
    required this.daysBefore,
    this.isActive = true,
  });

  BillReminder copyWith({
    String? name,
    String? icon,
    double? amount,
    int?    dueDay,
    int?    daysBefore,
    bool?   isActive,
  }) => BillReminder(
    id:         id,
    name:       name       ?? this.name,
    icon:       icon       ?? this.icon,
    amount:     amount     ?? this.amount,
    dueDay:     dueDay     ?? this.dueDay,
    daysBefore: daysBefore ?? this.daysBefore,
    isActive:   isActive   ?? this.isActive,
  );

  Map<String, dynamic> toJson() => {
    'id':         id,
    'name':       name,
    'icon':       icon,
    'amount':     amount,
    'dueDay':     dueDay,
    'daysBefore': daysBefore,
    'isActive':   isActive,
  };

  factory BillReminder.fromJson(Map<String, dynamic> j) => BillReminder(
    id:         j['id']         as String,
    name:       j['name']       as String,
    icon:       j['icon']       as String,
    amount:     (j['amount']    as num).toDouble(),
    dueDay:     j['dueDay']     as int,
    daysBefore: j['daysBefore'] as int,
    isActive:   j['isActive']   as bool? ?? true,
  );
}

// ─────────────────────────────────────────────────────────
//  Bill reminder dates (pure, so it can be unit-tested)
// ─────────────────────────────────────────────────────────
typedef BillReminderDate = ({DateTime due, DateTime notify});

/// The next [count] reminders for a bill due on [dueDay] of every month,
/// notifying [daysBefore] days ahead at 09:00. A due day past the end of a
/// short month falls on its last day (31st → 30 Apr, 28/29 Feb).
List<BillReminderDate> upcomingBillReminders({
  required int dueDay,
  required int daysBefore,
  required DateTime now,
  required int count,
}) {
  final result = <BillReminderDate>[];
  for (int offset = 0; result.length < count && offset <= count + 1; offset++) {
    final first       = DateTime(now.year, now.month + offset);
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    final due = DateTime(first.year, first.month, dueDay.clamp(1, daysInMonth));
    // Calendar-day arithmetic (not Duration) so DST changes can't shift it
    final notify = DateTime(due.year, due.month, due.day - daysBefore, 9);
    if (notify.isAfter(now)) result.add((due: due, notify: notify));
  }
  return result;
}

// ─────────────────────────────────────────────────────────
//  NotificationService
// ─────────────────────────────────────────────────────────
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  // SharedPreferences keys
  static const _kDailyEnabled  = 'reminder_daily_enabled';
  static const _kDailyHour     = 'reminder_daily_hour';
  static const _kDailyMin      = 'reminder_daily_min';
  static const _kWeeklyEnabled = 'reminder_weekly_enabled';
  static const _kWeeklyDay     = 'reminder_weekly_day';   // 1=Mon … 7=Sun
  static const _kWeeklyHour    = 'reminder_weekly_hour';
  static const _kWeeklyMin     = 'reminder_weekly_min';
  static const _kBills         = 'reminder_bills_json';

  // Notification IDs
  static const int _idDaily  = 1;
  static const int _idWeekly = 2;

  // Each bill gets its next [_billOccurrences] reminders scheduled as
  // one-shot notifications (re-filled on every app start). A monthly repeat
  // on a fixed day-of-month can't express "N days before the due date":
  // e.g. due on the 1st, 1 day before → the 31st, which doesn't exist in
  // 30-day months, so those reminders were silently skipped.
  static const int _billOccurrences = 4;
  static const int _maxBills        = 50;
  static int _billId(int index, int occurrence) =>
      2000 + index * _billOccurrences + occurrence;
  // Pre-fix scheme used one repeating notification per bill at 1000 + index
  static int _legacyBillId(int index) => 1000 + index;

  // ── Init ─────────────────────────────────────────────
  static const _tzChannel = MethodChannel('katonagari/timezone');

  Future<void> init() async {
    tz.initializeTimeZones();

    // Read the device's real timezone name (e.g. "Asia/Jakarta") via
    // a native MethodChannel — no extra package needed.
    try {
      final tzName =
          await _tzChannel.invokeMethod<String>('getLocalTimezone');
      if (tzName != null) {
        tz.setLocalLocation(tz.getLocation(tzName));
      }
    } catch (_) {
      // Fallback: match by UTC offset (covers most cases)
      _setLocationByOffset(DateTime.now().timeZoneOffset);
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission:  false,
      requestBadgePermission:  false,
      requestSoundPermission:  false,
    );

    await _plugin.initialize(
      const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
    );
  }

  // Fallback: find tz location by matching the device's UTC offset.
  // Used only if the MethodChannel call fails.
  void _setLocationByOffset(Duration offset) {
    final offsetMs = offset.inMilliseconds;
    tz.Location? match;
    // Prefer well-known cities when multiple zones share an offset
    const preferred = [
      'Asia/Jakarta', 'Asia/Singapore', 'Asia/Tokyo',
      'Europe/London', 'America/New_York', 'America/Los_Angeles',
      'Asia/Kolkata', 'Australia/Sydney',
    ];
    for (final name in preferred) {
      try {
        final loc = tz.getLocation(name);
        if (loc.currentTimeZone.offset == offsetMs) {
          match = loc;
          break;
        }
      } catch (_) {}
    }
    // If no preferred zone matched, scan the full database
    match ??= tz.timeZoneDatabase.locations.values
        .where((l) => l.currentTimeZone.offset == offsetMs)
        .firstOrNull;
    if (match != null) tz.setLocalLocation(match);
  }

  // ── Permissions ───────────────────────────────────────
  // FIX 1: Added <AndroidFlutterLocalNotificationsPlugin> and
  //         <IOSFlutterLocalNotificationsPlugin> generics (were missing).
  // FIX 2: Added exact alarm permission check for Android 12+.
  Future<bool> requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // Step 1: request POST_NOTIFICATIONS (Android 13+)
    final granted = await android?.requestNotificationsPermission() ?? true;
    if (!granted) return false;

    // Step 2: check & request SCHEDULE_EXACT_ALARM (Android 12+)
    if (Platform.isAndroid) {
      final canScheduleExact =
          await android?.canScheduleExactNotifications() ?? true;
      if (!canScheduleExact) {
        // Opens the system settings page so the user can grant it manually
        await android?.requestExactAlarmsPermission();
        // Re-check after the user returns from settings
        return await android?.canScheduleExactNotifications() ?? false;
      }
    }

    // iOS
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    return true;
  }

  // ─────────────────────────────────────────────────────
  //  Android notification channel details
  // ─────────────────────────────────────────────────────
  static const _channelId   = 'katonagari_reminders';
  static const _channelName = 'Katonagari Reminders';

  NotificationDetails get _details => const NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Daily, weekly and bill reminders',
      importance:  Importance.high,
      priority:    Priority.high,
      icon:        '@mipmap/ic_launcher',
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  // ─────────────────────────────────────────────────────
  //  DAILY REMINDER
  // ─────────────────────────────────────────────────────
  // FIX 3: Wrapped zonedSchedule in try/catch so a permission denial
  //        throws instead of silently swallowing the error — the toggle
  //        in the UI can then catch it and stay OFF.
  Future<void> scheduleDailyReminder(TimeOfDay time) async {
    await _plugin.cancel(_idDaily);

    final now     = tz.TZDateTime.now(tz.local);
    var   nextRun = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (nextRun.isBefore(now)) {
      nextRun = nextRun.add(const Duration(days: 1));
    }

    try {
      await _plugin.zonedSchedule(
        _idDaily,
        '📝 Don\'t forget to log today',
        'Keep your finances on track — tap to add a transaction.',
        nextRun,
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      // Rethrow so _toggleDaily in the UI knows scheduling failed
      rethrow;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDailyEnabled, true);
    await prefs.setInt(_kDailyHour,     time.hour);
    await prefs.setInt(_kDailyMin,      time.minute);
  }

  Future<void> cancelDailyReminder() async {
    await _plugin.cancel(_idDaily);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDailyEnabled, false);
  }

  // ─────────────────────────────────────────────────────
  //  WEEKLY SUMMARY
  // ─────────────────────────────────────────────────────
  // FIX 3 (same): Wrapped zonedSchedule in try/catch.
  Future<void> scheduleWeeklySummary(int weekday, TimeOfDay time) async {
    await _plugin.cancel(_idWeekly);

    final now     = tz.TZDateTime.now(tz.local);
    var   nextRun = _nextWeekday(now, weekday, time);

    try {
      await _plugin.zonedSchedule(
        _idWeekly,
        '📊 Your weekly summary is ready',
        'See how you spent this week — tap to open Katonagari.',
        nextRun,
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (e) {
      rethrow;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWeeklyEnabled, true);
    await prefs.setInt(_kWeeklyDay,      weekday);
    await prefs.setInt(_kWeeklyHour,     time.hour);
    await prefs.setInt(_kWeeklyMin,      time.minute);
  }

  Future<void> cancelWeeklySummary() async {
    await _plugin.cancel(_idWeekly);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWeeklyEnabled, false);
  }

  tz.TZDateTime _nextWeekday(
      tz.TZDateTime from, int weekday, TimeOfDay time) {
    var dt = tz.TZDateTime(
        tz.local, from.year, from.month, from.day, time.hour, time.minute);
    while (dt.weekday != weekday || dt.isBefore(from)) {
      dt = dt.add(const Duration(days: 1));
    }
    return dt;
  }

  // ─────────────────────────────────────────────────────
  //  BILL REMINDERS
  // ─────────────────────────────────────────────────────
  Future<List<BillReminder>> getBills() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_kBills);
    if (raw == null) return [];
    final list  = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => BillReminder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveBills(List<BillReminder> bills) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kBills, jsonEncode(bills.map((b) => b.toJson()).toList()));
  }

  Future<void> addBill(BillReminder bill) async {
    final bills = await getBills();
    bills.add(bill);
    await saveBills(bills);
    if (bill.isActive) await _scheduleBillNotifications(bill, bills.length - 1);
  }

  Future<void> updateBill(BillReminder bill) async {
    final bills = await getBills();
    final idx   = bills.indexWhere((b) => b.id == bill.id);
    if (idx == -1) return;
    await _cancelBill(idx);
    bills[idx] = bill;
    await saveBills(bills);
    if (bill.isActive) await _scheduleBillNotifications(bill, idx);
  }

  Future<void> deleteBill(String id) async {
    final bills = await getBills();
    final idx   = bills.indexWhere((b) => b.id == id);
    if (idx == -1) return;
    await _cancelBill(idx);
    bills.removeAt(idx);
    await saveBills(bills);
    await rescheduleAllBills();
  }

  /// Cancels every pending bill reminder and schedules the upcoming ones
  /// again. Called on app start so the rolling window of one-shot reminders
  /// keeps being topped up.
  Future<void> rescheduleAllBills() async {
    for (int i = 0; i < _maxBills; i++) {
      await _cancelBill(i);
    }
    final bills = await getBills();
    for (int i = 0; i < bills.length && i < _maxBills; i++) {
      if (bills[i].isActive) {
        await _scheduleBillNotifications(bills[i], i);
      }
    }
  }

  Future<void> _cancelBill(int index) async {
    await _plugin.cancel(_legacyBillId(index));
    for (int k = 0; k < _billOccurrences; k++) {
      await _plugin.cancel(_billId(index, k));
    }
  }

  Future<void> _scheduleBillNotifications(
      BillReminder bill, int index) async {
    if (index >= _maxBills) return;
    final cur = PreferencesService.currencyByCode(
        await PreferencesService.instance.getCurrencyCode());
    final fmtAmount = cur.format(bill.amount);
    final days      = bill.daysBefore;

    final upcoming = upcomingBillReminders(
      dueDay:     bill.dueDay,
      daysBefore: days,
      now:        tz.TZDateTime.now(tz.local),
      count:      _billOccurrences,
    );
    for (int k = 0; k < upcoming.length; k++) {
      final r = upcoming[k];
      await _plugin.zonedSchedule(
        _billId(index, k),
        '${bill.icon} ${bill.name} due in $days day${days == 1 ? '' : 's'}',
        '$fmtAmount · Due ${DateFormat('EEE, d MMM').format(r.due)}.',
        tz.TZDateTime(tz.local, r.notify.year, r.notify.month,
            r.notify.day, 9, 0),
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  // ─────────────────────────────────────────────────────
  //  Load saved settings
  // ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'dailyEnabled':  prefs.getBool(_kDailyEnabled)  ?? false,
      'dailyHour':     prefs.getInt(_kDailyHour)      ?? 21,
      'dailyMin':      prefs.getInt(_kDailyMin)        ?? 0,
      'weeklyEnabled': prefs.getBool(_kWeeklyEnabled)  ?? false,
      'weeklyDay':     prefs.getInt(_kWeeklyDay)       ?? 1,
      'weeklyHour':    prefs.getInt(_kWeeklyHour)      ?? 9,
      'weeklyMin':     prefs.getInt(_kWeeklyMin)       ?? 0,
    };
  }
}