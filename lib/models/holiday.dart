import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'holiday.g.dart';

@HiveType(typeId: 0)
class Holiday extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  DateTime date;

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
    required this.date,
    required this.type,
    this.description,
    this.colorCode = 0xFF2196F3,
    TimeOfDay? time,
  })  : hour = time?.hour,
        minute = time?.minute;

  TimeOfDay? get time =>
      (hour != null && minute != null)
          ? TimeOfDay(hour: hour!, minute: minute!)
          : null;

  /// Used for editing – updates this object
  void updateEvent({
    required String name,
    String? description,
    TimeOfDay? time,
    required int colorCode,
  }) {
    this.name = name;
    this.description = description;
    this.hour = time?.hour;
    this.minute = time?.minute;
    this.colorCode = colorCode;
  }

  factory Holiday.fromJson(Map<String, dynamic> json) {
    return Holiday(
      name: json['name'],
      date: DateTime.parse(json['date']),
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