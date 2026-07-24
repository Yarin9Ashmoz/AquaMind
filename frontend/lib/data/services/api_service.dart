import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';

class ApiService {
  // Use for local testing with a local backend server.
  // static const String baseUrl = 'http://10.0.0.18:8000';

  // Use for production with the Render backend server.
  final String baseUrl = "https://aquamind-0xli.onrender.com";

  // Must match the API_KEY value in backend/.env exactly.
  static const String apiKey = "my7Super9Secret2Key_dont_share";

  // Standard headers for protected (mutating) endpoints.
  Map<String, String> get _authHeaders => {
    "Content-Type": "application/json",
    "X-API-Key": apiKey,
  };

  final Duration timeout = const Duration(seconds: 90);

  Future<void> requestManualSample(String sensorId) async {
    try {
      String sensorIdForUrl = sensorId.replaceAll(":", "_");
      final url = Uri.parse(
        "$baseUrl/api/v1/sensors/$sensorIdForUrl/request-manual",
      );
      final res = await http.post(url, headers: _authHeaders).timeout(timeout);

      if (res.statusCode != 200) {
        throw Exception("Failed to request manual sample: ${res.statusCode}");
      }
    } catch (e) {
      print("❌ ApiService Error (requestManualSample): $e");
      rethrow;
    }
  }

  Future<List<dynamic>> getSensors() async {
    try {
      final url = Uri.parse("$baseUrl/api/v1/sensors/");
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

  /// Sends a PATCH request to update moisture threshold and sync interval
  Future<void> updateSensorConfig({
    required String sensorId,
    required double threshold,
    required int syncInterval,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/api/v1/sensors/config");
      final res = await http
          .patch(
            url,
            headers: _authHeaders,
            body: jsonEncode({
              "sensor_id": sensorId,
              "moisture_threshold": threshold,
              "sync_interval_minutes": syncInterval,
            }),
          )
          .timeout(timeout);

      if (res.statusCode != 200) {
        throw Exception(
          "Failed to update sensor config: ${res.statusCode} - ${res.body}",
        );
      }
    } catch (e) {
      print("❌ ApiService Error (updateSensorConfig): $e");
      rethrow;
    }
  }

  Future<void> createSensor({
    required String sensorId,
    required String name,
    required String plantType,
    required String locationType,
    required double moisture,
    required int dryToleranceDays,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/api/v1/sensors/");
      final res = await http
          .post(
            url,
            headers: _authHeaders,
            body: jsonEncode({
              "sensor_id": sensorId,
              "name": name,
              "plant_type": plantType,
              "location_type": locationType,
              "dry_tolerance_days": dryToleranceDays,
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

  Future<void> renameSensor(String sensorId, String newName) async {
    try {
      String sensorIdForUrl = sensorId.replaceAll(":", "_");
      final url = Uri.parse("$baseUrl/api/v1/sensors/$sensorIdForUrl/rename");
      final res = await http
          .post(url, headers: _authHeaders, body: jsonEncode({"name": newName}))
          .timeout(timeout);

      if (res.statusCode != 200) throw Exception("Failed to rename");
    } catch (e) {
      print("❌ ApiService Error (renameSensor): $e");
      rethrow;
    }
  }

  Future<void> deleteSensor({String? sensorId, String? name}) async {
    try {
      if (sensorId == null && name == null) {
        throw Exception('sensorId or name must be provided');
      }

      final queryParams = <String, String>{};
      if (sensorId != null) {
        queryParams['sensorId'] = sensorId.replaceAll(":", "_");
      }
      if (name != null) queryParams['name'] = name;

      final url = Uri.parse(
        '$baseUrl/api/v1/sensors/',
      ).replace(queryParameters: queryParams);
      final res = await http
          .delete(url, headers: {"X-API-Key": apiKey})
          .timeout(timeout);

      if (res.statusCode != 200) {
        throw Exception("Failed to delete sensor: ${res.statusCode}");
      }
    } catch (e) {
      print("❌ ApiService Error (deleteSensor): $e");
      rethrow;
    }
  }

  Future<void> deleteAllSensors() async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/sensors/all');
      final res = await http
          .delete(url, headers: {"X-API-Key": apiKey})
          .timeout(timeout);

      if (res.statusCode != 200) {
        throw Exception("Failed to delete all sensors: ${res.statusCode}");
      }
    } catch (e) {
      print("❌ ApiService Error (deleteAllSensors): $e");
      rethrow;
    }
  }

  // ==========================================
  // AI Plant Identification Function
  // ==========================================

  Future<Map<String, dynamic>?> identifyPlantWithAI() async {
    try {
      final ImagePicker picker = ImagePicker();

      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image == null) return null;

      final url = Uri.parse("$baseUrl/plants/identify");
      final request = http.MultipartRequest('POST', url);
      request.headers["X-API-Key"] = apiKey;

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          image.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final streamedResponse = await request.send().timeout(timeout);
      final res = await http.Response.fromStream(streamedResponse);

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          "Server responded with code: ${res.statusCode} - ${res.body}",
        );
      }
    } catch (e) {
      print("❌ ApiService Error (identifyPlantWithAI): $e");
      rethrow;
    }
  }
}
