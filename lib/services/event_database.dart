import 'package:hive_flutter/hive_flutter.dart';
import '../models/holiday.dart';

class EventDatabase {
  static const String _boxName = 'custom_events';

  static Future<void> init() async {
    await Hive.openBox<Holiday>(_boxName);
  }

  static Box<Holiday> get _box => Hive.box<Holiday>(_boxName);

  static Future<void> saveEvent(Holiday event) async {
    if (event.isInBox) {
      await event.save();
    } else {
      await _box.add(event);
    }
  }

  static Future<void> deleteEvent(Holiday event) async {
    if (event.isInBox) {
      await event.delete();
    }
  }

  static List<Holiday> getAllEvents() {
    return _box.values.toList();
  }
}

