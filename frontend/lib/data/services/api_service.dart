import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = "https://aquamind-0xli.onrender.com";
  final Duration timeout = const Duration(seconds: 10);

  Future<List<dynamic>> getSensors() async {
    try {
      final url = Uri.parse("$baseUrl/sensors");
      final res = await http
          .get(url)
          .timeout(
            timeout,
            onTimeout: () {
              throw Exception("Request timeout");
            },
          );

      if (res.statusCode != 200) {
        throw Exception("Failed to load sensors: ${res.statusCode}");
      }

      return jsonDecode(res.body);
    } catch (e) {
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
