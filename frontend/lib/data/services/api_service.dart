import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = "https://aquamind-0xli.onrender.com";
  final Duration timeout = const Duration(seconds: 30);

  // 1. בקשת דגימה ידנית
  Future<void> requestManualSample(String sensorId) async {
    try {
      final url = Uri.parse("$baseUrl/sensors/$sensorId/request-manual");
      final res = await http.post(url).timeout(timeout);

      if (res.statusCode != 200) {
        throw Exception("Failed to request manual sample: ${res.statusCode}");
      }
    } catch (e) {
      print("❌ ApiService Error (requestManualSample): $e");
      rethrow;
    }
  }

  // 2. קבלת כל החיישנים
  Future<List<dynamic>> getSensors() async {
    try {
      final url = Uri.parse("$baseUrl/sensors");
      final res = await http.get(url).timeout(timeout);

      if (res.statusCode != 200) {
        throw Exception("Failed to load sensors: ${res.statusCode}");
      }
      return jsonDecode(res.body);
    } catch (e) {
      print("❌ ApiService Error (getSensors): $e");
      rethrow;
    }
  }

  // 3. יצירת חיישן חדש
  Future<void> createSensor({
    required String sensorId,
    required String name,
    required String plantType,
    required String locationType,
    required double moisture,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/sensors/create");
      final res = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "sensor_id": sensorId,
              "name": name,
              "plant_type": plantType,
              "location_type": locationType,
              "moisture": moisture,
            }),
          )
          .timeout(timeout);

      if (res.statusCode != 200 && res.statusCode != 201) {
        throw Exception("Failed to create sensor: ${res.body}");
      }
    } catch (e) {
      print("❌ ApiService Error (createSensor): $e");
      rethrow;
    }
  }

  // 4. שינוי שם חיישן
  Future<void> renameSensor(String sensorId, String newName) async {
    try {
      final url = Uri.parse("$baseUrl/sensors/$sensorId/rename");
      final res = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"name": newName}),
          )
          .timeout(timeout);

      if (res.statusCode != 200) throw Exception("Failed to rename");
    } catch (e) {
      print("❌ ApiService Error (renameSensor): $e");
      rethrow;
    }
  }

  // 5. מחיקת חיישן בודד
  Future<void> deleteSensor({String? sensorId, String? name}) async {
    try {
      if (sensorId == null && name == null) {
        throw Exception('sensorId or name must be provided');
      }

      final queryParams = <String, String>{};
      if (sensorId != null) queryParams['sensorId'] = sensorId;
      if (name != null) queryParams['name'] = name;

      final url = Uri.parse(
        '$baseUrl/sensors/delete',
      ).replace(queryParameters: queryParams);
      final res = await http.delete(url).timeout(timeout);

      if (res.statusCode != 200) {
        throw Exception("Failed to delete sensor: ${res.statusCode}");
      }
    } catch (e) {
      print("❌ ApiService Error (deleteSensor): $e");
      rethrow;
    }
  }

  // 6. מחיקת כל החיישנים (תיקון URL לפורמט אחיד)
  Future<void> deleteAllSensors() async {
    try {
      final url = Uri.parse(
        '$baseUrl/sensors/delete-all',
      ); // וודא שזה תואם ל-Backend (או delete_all)
      final res = await http.delete(url).timeout(timeout);

      if (res.statusCode != 200) {
        throw Exception("Failed to delete all sensors: ${res.statusCode}");
      }
    } catch (e) {
      print("❌ ApiService Error (deleteAllSensors): $e");
      rethrow;
    }
  }
}
