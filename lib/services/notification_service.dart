import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import '../models/holiday.dart';

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _notifications.initialize(settings);
  }

  /// Schedule notification for an event
  static Future<void> scheduleEventNotification(Holiday event) async {
    final dateTime = _getEventDateTime(event);
    if (dateTime == null || dateTime.isBefore(DateTime.now())) return;

    final id = event.key ?? dateTime.millisecondsSinceEpoch ~/ 1000;

    await _notifications.zonedSchedule(
      id,
      event.name,
      event.description ?? 'Event reminder',
      tz.TZDateTime.from(dateTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'events_channel',
          'Event Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  /// Cancel notification
  static Future<void> cancelEventNotification(Holiday event) async {
    if (event.key != null) {
      await _notifications.cancel(event.key as int);
    }
  }

  static DateTime? _getEventDateTime(Holiday event) {
    if (event.time != null) {
      return DateTime(
        event.startDate.year,
        event.startDate.month,
        event.startDate.day,
        event.time!.hour,
        event.time!.minute,
      );
    }
    // All-day → notify at 9 AM
    return DateTime(
      event.startDate.year,
      event.startDate.month,
      event.startDate.day,
      9,
    );
  }
}
