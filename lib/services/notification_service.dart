import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

enum ReminderOption { none, tenMinutes, oneHour, oneDay }

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Phnom_Penh'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    _initialized = true;
  }

  // ✅ THIS is the method your CalendarPage calls
  Future<int?> scheduleEventReminder({
    required String title,
    String? body,
    required DateTime startDate,
    DateTime? endDate,
    required int? hour,
    required int? minute,
    required ReminderOption reminder,
    int allDayHour = 8,
    int allDayMinute = 0,
    int? existingNotificationId,
  }) async {
    if (reminder == ReminderOption.none) {
      if (existingNotificationId != null) {
        await cancel(existingNotificationId);
      }
      return null;
    }

    final bool isAllDay = (hour == null || minute == null);

    final DateTime eventStart = isAllDay
        ? DateTime(startDate.year, startDate.month, startDate.day, allDayHour,
            allDayMinute)
        : DateTime(startDate.year, startDate.month, startDate.day, hour, minute);

    final DateTime scheduled = eventStart.subtract(_offset(reminder));

    // if scheduled time already passed, skip
    if (scheduled.isBefore(DateTime.now())) {
      return existingNotificationId;
    }

    final int notificationId =
        existingNotificationId ?? (eventStart.millisecondsSinceEpoch % 2000000000);

    const androidDetails = AndroidNotificationDetails(
      'event_reminders',
      'Event Reminders',
      channelDescription: 'Reminders for calendar events',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _plugin.zonedSchedule(
      notificationId,
      title,
      body ?? 'Upcoming event',
      tz.TZDateTime.from(scheduled, tz.local),
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    return notificationId;
  }

  Future<void> cancel(int id) async => _plugin.cancel(id);

  Duration _offset(ReminderOption r) {
    switch (r) {
      case ReminderOption.tenMinutes:
        return const Duration(minutes: 10);
      case ReminderOption.oneHour:
        return const Duration(hours: 1);
      case ReminderOption.oneDay:
        return const Duration(days: 1);
      case ReminderOption.none:
        return Duration.zero;
    }
  }
}
