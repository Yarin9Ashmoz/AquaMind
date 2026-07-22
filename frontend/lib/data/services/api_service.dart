import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';

class ApiService {
  //Use for local testing with a local backend server.
  //static const String baseUrl = 'http://10.0.0.18:8000';

  // Use for production with the Render backend server.
  final String baseUrl = "https://aquamind-0xli.onrender.com";

  // Increased to 90 seconds across the board to absorb Render's slow spin-up/cold start times safely.
  final Duration timeout = const Duration(seconds: 90);

  Future<void> requestManualSample(String sensorId) async {
    try {
      String sensorIdForUrl = sensorId.replaceAll(":", "_");
      final url = Uri.parse("$baseUrl/sensors/$sensorIdForUrl/request-manual");
      final res = await http.post(url).timeout(timeout);

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

  Future<void> createSensor({
    required String sensorId,
    required String name,
    required String plantType,
    required String locationType,
    required double moisture,
    required int dryToleranceDays,
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
      final url = Uri.parse("$baseUrl/sensors/$sensorIdForUrl/rename");
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

  Future<void> deleteSensor({String? sensorId, String? name}) async {
    try {
      if (sensorId == null && name == null) {
        throw Exception('sensorId or name must be provided');
      }

      final queryParams = <String, String>{};
      if (sensorId != null)
        queryParams['sensorId'] = sensorId.replaceAll(":", "_");
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

  Future<void> deleteAllSensors() async {
    try {
      final url = Uri.parse('$baseUrl/sensors/delete-all');
      final res = await http.delete(url).timeout(timeout);

      if (res.statusCode != 200) {
        throw Exception("Failed to delete all sensors: ${res.statusCode}");
      }
    } catch (e) {
      print("❌ ApiService Error (deleteAllSensors): $e");
      rethrow;
    }
  }

  // ==========================================
  // NEW: AI Plant Identification Function
  // ==========================================

  /// Triggers the device camera to take a picture, uploads it to the Render backend,
  /// and returns a Map containing Gemini-generated plant configurations in English.
  Future<Map<String, dynamic>?> identifyPlantWithAI() async {
    try {
      final ImagePicker picker = ImagePicker();

      // 1. Open the native device camera to capture an image
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80, // Compress slightly to optimize network upload speed
      );

      // If the user backs out without snapping a picture, exit safely
      if (image == null) return null;

      // 2. Prepare multipart request for file uploading
      final url = Uri.parse("$baseUrl/plants/identify");
      final request = http.MultipartRequest('POST', url);

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          image.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      // 3. Dispatch the request with the updated 90-second timeout guard
      final streamedResponse = await request.send().timeout(timeout);
      final res = await http.Response.fromStream(streamedResponse);

      if (res.statusCode == 200) {
        // Decode the clean, strict English JSON configuration received from the Gemini-powered backend
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
