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

  Future<void> deleteAllSensors() async {
    // Some deployments may not have the /sensors/delete-all endpoint yet.
    // Try the expected endpoint first, then fall back to a legacy root path.
    const paths = ['/sensors/delete-all', '/delete-all'];

    Exception? lastError;

    for (final path in paths) {
      try {
        final url = Uri.parse('$baseUrl$path');
        print('Deleting all sensors at: $url');

        final res = await http
            .delete(url)
            .timeout(
              timeout,
              onTimeout: () {
                print('❌ Delete request timeout after ${timeout.inSeconds}s');
                throw Exception(
                  'Delete request timeout after ${timeout.inSeconds}s',
                );
              },
            );

        print('✅ Delete response status: ${res.statusCode}');

        if (res.statusCode == 200) {
          return;
        }

        lastError = Exception('Failed to delete sensors: ${res.statusCode}');

        // If not found, try next path.
        if (res.statusCode == 404) continue;

        throw lastError;
      } catch (e) {
        lastError = Exception('Error deleting sensors: $e');
        // Try next candidate URL unless this was a non-404 terminal failure.
        if (e is Exception && e.toString().contains('404')) {
          continue;
        }
        // Re-throw for other errors (timeout, network, etc.)
        throw lastError;
      }
    }

    throw lastError ?? Exception('Failed to delete sensors');
  }

  Future<void> deleteSensor({String? sensorId, String? name}) async {
    if (sensorId == null && name == null) {
      throw Exception('sensorId or name must be provided');
    }

    // Some deployments may only have /sensors/delete and others might have /delete.
    final candidates = ['/sensors/delete', '/delete'];

    Exception? lastError;

    for (final path in candidates) {
      try {
        final queryParams = <String, String>{};
        if (sensorId != null) queryParams['sensorId'] = sensorId;
        if (name != null) queryParams['name'] = name;

        final uri = Uri.parse(
          '$baseUrl$path',
        ).replace(queryParameters: queryParams);
        print('Deleting sensor at: $uri');

        final res = await http
            .delete(uri)
            .timeout(
              timeout,
              onTimeout: () {
                throw Exception('Delete request timeout');
              },
            );

        if (res.statusCode == 200) {
          return;
        }

        lastError = Exception('Failed to delete sensor: ${res.statusCode}');
        if (res.statusCode == 404) continue;

        throw lastError;
      } catch (e) {
        lastError = Exception('Error deleting sensor: $e');
        if (e is Exception && e.toString().contains('404')) {
          continue;
        }
        throw lastError;
      }
    }

    throw lastError ?? Exception('Failed to delete sensor');
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
    required double moisture,
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
