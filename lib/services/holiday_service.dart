import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/holiday.dart';

class HolidayService {
  static Future<List<Holiday>> fetchHolidays() async {
    final response = await http.get(
      Uri.parse('https://date.nager.at/api/v3/PublicHolidays/2026/US'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => Holiday.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load holidays');
    }
  }
}
