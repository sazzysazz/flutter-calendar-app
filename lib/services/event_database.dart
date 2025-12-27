import 'package:hive_flutter/hive_flutter.dart';
import '../models/holiday.dart';

class EventDatabase {
  static const String _boxName = 'custom_events';

  // Call this in main.dart after Hive.initFlutter()
  static Future<void> init() async {
    await Hive.openBox<Holiday>(_boxName);
  }

  static Box<Holiday> get _box => Hive.box<Holiday>(_boxName);

  /// Save new event or update existing one
  static Future<void> saveEvent(Holiday event) async {
    if (event.isInBox) {
      await event.save(); // Update existing
    } else {
      await _box.add(event); // Add new – Hive assigns auto-increment key
    }
  }

  /// Delete event
  static Future<void> deleteEvent(Holiday event) async {
    if (event.isInBox) {
      await event.delete(); // Proper HiveObject deletion
    }
  }

  /// Get all custom events – always fresh
  static List<Holiday> getAllEvents() {
    return _box.values.toList();
  }

  /// Optional: clear all custom events
  static Future<void> clearAll() async {
    await _box.clear();
  }
}
