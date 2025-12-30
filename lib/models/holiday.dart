import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'holiday.g.dart';

/// Helper extension – strips time part, keeps only year/month/day
extension DateTimeExtension on DateTime {
  DateTime stripTime() => DateTime(year, month, day);
}

@HiveType(typeId: 0)
class Holiday extends HiveObject {
  @HiveField(0)
  String name;

  /// Start of the event (always required)
  @HiveField(1)
  DateTime startDate;

  /// End of the event – null = single-day event
  @HiveField(7) // Use a higher index to avoid conflicting with existing data
  DateTime? endDate;

  @HiveField(2)
  String type;

  @HiveField(3)
  String? description;

  @HiveField(4)
  int colorCode;

  @HiveField(5)
  int? hour;

  @HiveField(6)
  int? minute;

  Holiday({
    required this.name,
    required this.startDate,
    this.endDate,
    required this.type,
    this.description,
    this.colorCode = 0xFF2196F3,
    TimeOfDay? time,
  })  : hour = time?.hour,
        minute = time?.minute;

  /// Stripped start date (for mapping / comparison)
  DateTime get startDay => startDate.stripTime();

  /// Stripped end date – falls back to startDate if null
  DateTime get endDay => (endDate ?? startDate).stripTime();

  /// Does this event cover the given day?
  bool coversDay(DateTime day) {
    final d = day.stripTime();
    return !d.isBefore(startDay) && !d.isAfter(endDay);
  }

  /// Time of day (if set)
  TimeOfDay? get time =>
      (hour != null && minute != null)
          ? TimeOfDay(hour: hour!, minute: minute!)
          : null;

  /// Update an existing event (used in edit dialog)
  void updateEvent({
    required String name,
    String? description,
    TimeOfDay? time,
    required int colorCode,
    required DateTime startDate,
    DateTime? endDate,
  }) {
    this.name = name;
    this.description = description;
    this.hour = time?.hour;
    this.minute = time?.minute;
    this.colorCode = colorCode;
    this.startDate = startDate;
    this.endDate = endDate;
  }

  /// Parse from public holiday API JSON
  factory Holiday.fromJson(Map<String, dynamic> json) {
    final date = DateTime.parse(json['date']);
    return Holiday(
      name: json['name'],
      startDate: date,
      endDate: null, // Public holidays are always single-day
      type: json['type'] ?? 'Public',
      description: json['description'],
      colorCode: _getColorForType(json['type'] ?? 'Public'),
    );
  }

  static int _getColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'public':
      case 'national':
        return 0xFFEF5350;
      case 'religious':
        return 0xFFAB47BC;
      case 'observance':
        return 0xFF7E57C2;
      case 'season':
        return 0xFF66BB6A;
      default:
        return 0xFF42A5F5;
    }
  }
}