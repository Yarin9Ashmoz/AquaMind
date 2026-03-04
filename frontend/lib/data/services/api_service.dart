import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = "https://aquamind-0xli.onrender.com";

  Future<List<dynamic>> getSensors() async {
    final url = Uri.parse("$baseUrl/sensors");
    final res = await http.get(url);

    if (res.statusCode != 200) {
      throw Exception("Failed to load sensors");
    }

    return jsonDecode(res.body);
  }

  Future<void> renameSensor(String sensorId, String newName) async {
    final url = Uri.parse("$baseUrl/sensors/$sensorId/rename");

    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"name": newName}),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to rename sensor");
    }
  }

  Future<void> createSensor({
    required String sensorId,
    required String name,
    required String plantType,
    required int moisture,
  }) async {
    final url = Uri.parse("$baseUrl/sensors/create");

    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "sensorId": sensorId,
        "name": name,
        "plantType": plantType,
        "moisture": moisture,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to create sensor");
    }
  }
}
