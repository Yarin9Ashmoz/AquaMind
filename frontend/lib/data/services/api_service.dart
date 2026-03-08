import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // שנה את זה ל-"http://10.0.2.2:8000" אם אתה ב-Android Emulator עם Backend local
  // שנה את זה ל-"http://192.168.1.X:8000" אם אתה ב-Device עם Backend local (החלף X)
  final String baseUrl = "https://aquamind-0xli.onrender.com";
  final Duration timeout = const Duration(seconds: 30);

  Future<List<dynamic>> getSensors() async {
    try {
      final url = Uri.parse("$baseUrl/sensors");
      print("📡 Fetching sensors from: $url");

      final res = await http
          .get(url)
          .timeout(
            timeout,
            onTimeout: () {
              print("❌ Request timeout after ${timeout.inSeconds}s");
              throw Exception("Request timeout after ${timeout.inSeconds}s");
            },
          );

      print("✅ Response status: ${res.statusCode}");

      if (res.statusCode != 200) {
        throw Exception("Failed to load sensors: ${res.statusCode}");
      }

      final data = jsonDecode(res.body);
      print("✅ Loaded ${data.length} sensors");
      return data;
    } catch (e) {
      print("❌ Error loading sensors: $e");
      throw Exception("Error loading sensors: $e");
    }
  }

  Future<void> renameSensor(String sensorId, String newName) async {
    try {
      final url = Uri.parse("$baseUrl/sensors/$sensorId/rename");

      final res = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"name": newName}),
          )
          .timeout(
            timeout,
            onTimeout: () {
              throw Exception("Request timeout");
            },
          );

      if (res.statusCode != 200) {
        throw Exception("Failed to rename sensor: ${res.statusCode}");
      }
    } catch (e) {
      throw Exception("Error renaming sensor: $e");
    }
  }

  Future<void> createSensor({
    required String sensorId,
    required String name,
    required String plantType,
    required String locationType,
    required int moisture,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/sensors/create");

      final res = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "sensorId": sensorId,
              "name": name,
              "plantType": plantType,
              "locationType": locationType,
              "moisture": moisture,
            }),
          )
          .timeout(
            timeout,
            onTimeout: () {
              throw Exception("Request timeout");
            },
          );

      if (res.statusCode != 200) {
        throw Exception("Failed to create sensor: ${res.statusCode}");
      }
    } catch (e) {
      throw Exception("Error creating sensor: $e");
    }
  }
}
