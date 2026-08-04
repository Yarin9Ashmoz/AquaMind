import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../data/models/sensor.dart';
import '../../data/repositories/sensor_repository.dart';

class DashboardState extends ChangeNotifier {
  final SensorRepository repo;

  List<Sensor> sensors = [];
  Sensor? selectedSensor;

  bool isLoading = false; // Primary full-screen view state fetch manager
  bool isActionLoading = false; // Micro-interaction background loading toggle
  String? error;

  // 📍 Weather state properties
  double? currentTemp;
  double? windSpeed;
  int? weatherCode;
  String? locationName = "Local Climate";

  DashboardState(this.repo) {
    loadSensors();
  }

  /// Fetches the latest sensor configuration array from remote database
  Future<void> loadSensors() async {
    // Prevent overlapping synchronization pipelines
    if (isLoading) return;

    try {
      if (sensors.isEmpty) {
        isLoading = true;
        notifyListeners();
      }
      error = null;

      final fetchedSensors = await repo.getSensors();

      // DE-DUPARATION: Safely filter out any duplicate IDs returned by faulty network cycles
      final seenIds = <String>{};
      sensors = fetchedSensors.where((s) => seenIds.add(s.sensorId)).toList();

      // Synchronize currently active screen target with fresh network metrics
      if (selectedSensor != null) {
        final index = sensors.indexWhere(
          (s) => s.sensorId == selectedSensor!.sensorId,
        );
        selectedSensor = index != -1
            ? sensors[index]
            : (sensors.isNotEmpty ? sensors.first : null);
      } else if (sensors.isNotEmpty) {
        selectedSensor = sensors.first;
      }

      // 📍 Fetch current weather telemetry alongside sensor data
      await fetchWeatherData();

      error = null;
    } catch (e) {
      if (sensors.isEmpty) {
        error = "Sync Failure: Check your connection or cloud status.";
      }
      print("❌ Error loading sensors: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// 📍 Fetches real-time weather telemetry from Open-Meteo API
  Future<void> fetchWeatherData({
    double lat = 32.0853,
    double lon = 34.7818,
  }) async {
    try {
      // Extract coordinates from active sensors if present
      if (sensors.isNotEmpty) {
        final validSensor = sensors.firstWhere(
          (s) => s.latitude != null && s.longitude != null,
          orElse: () => sensors.first,
        );
        if (validSensor.latitude != null && validSensor.longitude != null) {
          lat = validSensor.latitude!;
          lon = validSensor.longitude!;
        }
      }

      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final currentWeather = data['current_weather'];

        currentTemp = (currentWeather['temperature'] as num).toDouble();
        windSpeed = (currentWeather['windspeed'] as num).toDouble();
        weatherCode = (currentWeather['weathercode'] as num).toInt();
      }
    } catch (e) {
      print("❌ Weather telemetry API fetch error: $e");
      // Fallback defaults if offline
      currentTemp ??= 24.5;
      windSpeed ??= 12.0;
      weatherCode ??= 0;
    }
  }

  /// Updates threshold and sync interval configurations for a target node
  Future<void> updateSensorConfig({
    required String sensorId,
    required double threshold,
    required int syncInterval,
  }) async {
    try {
      error = null;
      isActionLoading = true;
      notifyListeners();

      // Dispatch repository update command
      await repo.updateSensorConfig(
        sensorId: sensorId,
        threshold: threshold,
        syncInterval: syncInterval,
      );

      // Refresh local sensor payload to reflect new configurations
      await loadSensors();
    } catch (e) {
      error = "Failed to update sensor config: $e";
      print("❌ Error updating sensor config: $e");
      notifyListeners();
      rethrow;
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  /// Requests the remote ESP32 unit to execute an instantaneous analog moisture measurement
  Future<void> requestMeasurement(String sensorId) async {
    if (isActionLoading) return;
    try {
      error = null;
      isActionLoading = true;
      notifyListeners();

      await repo.requestManualSample(sensorId);
      print("📡 Measurement request transmitted: $sensorId");

      await Future.delayed(const Duration(seconds: 3));

      await loadSensors();
    } catch (e) {
      error = "Hardware polling request failed. Node may be offline.";
      print("❌ Error requesting measurement: $e");
      notifyListeners();
      rethrow;
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  /// Alias for pull-to-refresh architecture components
  Future<void> fetchSensors() => loadSensors();

  /// Completely purges all structural nodes linked with the user profile
  Future<void> deleteAllSensors() async {
    if (isActionLoading) return;

    try {
      isActionLoading = true;
      error = null;
      notifyListeners();

      await repo.deleteAllSensors();

      sensors = [];
      selectedSensor = null;
    } catch (e) {
      error = "Full ecosystem wipe rejected: $e";
      print("❌ Error dropping entire table: $e");
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  /// Removes an individual tracking node utilizing its unique identifier string
  Future<void> deleteSensorById(String sensorId) async {
    try {
      error = null;
      await repo.deleteSensor(sensorId: sensorId);

      sensors.removeWhere((s) => s.sensorId == sensorId);

      if (selectedSensor?.sensorId == sensorId) {
        selectedSensor = sensors.isNotEmpty ? sensors.first : null;
      }

      notifyListeners();
    } catch (e) {
      error = "Target node deletion failed: $e";
      notifyListeners();
    }
  }

  /// Removes an individual tracking node utilizing its user-defined name token
  Future<void> deleteSensorByName(String name) async {
    try {
      error = null;
      await repo.deleteSensor(name: name);

      sensors.removeWhere((s) => s.name == name);

      if (selectedSensor?.name == name) {
        selectedSensor = sensors.isNotEmpty ? sensors.first : null;
      }

      notifyListeners();
    } catch (e) {
      error = "Target node asset deletion failed: $e";
      notifyListeners();
    }
  }

  /// Updates a device identification label across infrastructure layers
  Future<void> renameSensor(String sensorId, String newName) async {
    try {
      error = null;
      await repo.renameSensor(sensorId, newName);
      await loadSensors();
    } catch (e) {
      error = "Label modification dropped by server: $e";
      notifyListeners();
    }
  }

  /// Provisions a fresh operational hardware metadata node onto the platform map
  Future<void> createSensor({
    required String sensorId,
    required String name,
    required String plantType,
    required String locationType,
    required double moisture,
    required int dryToleranceDays,
  }) async {
    // BLOCK DOUBLE TRIGGER: Prevent rapid twin taps or race conditions from executing twice
    if (isActionLoading) return;

    try {
      isActionLoading = true;
      error = null;
      notifyListeners();

      await repo.createSensor(
        sensorId: sensorId,
        name: name,
        plantType: plantType,
        locationType: locationType,
        moisture: moisture,
        dryToleranceDays: dryToleranceDays,
      );

      // Force high-priority clean sync immediately after successful pipeline creation
      await loadSensors();
    } catch (e) {
      error = "Infrastructure asset registration failure: $e";
      print("❌ Error creating sensor: $e");
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  /// Shifts active view targeting mechanics to a selected physical telemetry entity
  void selectSensor(Sensor sensor) {
    selectedSensor = sensor;
    notifyListeners();
  }

  /// Explicitly flushes the error banner buffer state to clear user interface real-estate
  void clearError() {
    if (error != null) {
      error = null;
      notifyListeners();
    }
  }

  /// Interprets raw soil metrics into dynamic, action-oriented natural descriptions
  String get statusText {
    if (selectedSensor == null) return "No active nodes monitored";
    final m = selectedSensor!.moisture;
    if (m < 30) return "Dry – critical watering needed";
    if (m < 60) return "Optimal hydration equilibrium";
    return "Saturation threshold exceeded";
  }

  String get lastUpdateText {
    if (selectedSensor == null) return "";
    return selectedSensor!.lastUpdate.toString();
  }
}
